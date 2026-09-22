pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import "WindowPreviewPolicy.js" as PreviewPolicy

/**
 * WindowPreviewService - Window preview caching for TaskView
 * 
 * Strategy:
 * - Capture previews ONLY when TaskView opens
 * - Cache in ~/.cache/inir/window-previews/
 * - Keep snapshots until window close/session reset; no arbitrary hover TTL
 * - Clean up on window close
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    readonly property string previewDir: FileUtils.trimFileProtocol(Directories.genericCache) + "/inir/window-previews"
    readonly property string sessionMarkerPath: previewDir + "/.niri-session"
    readonly property string sessionKey: NiriService.socketPath ?? ""
    
    // Map of windowId -> { path, timestamp }; timestamp revises URLs on capture.
    property var previewCache: ({})
    
    property bool initialized: false
    property bool sessionReady: false
    property bool captureRequestedWhileInitializing: false
    property bool capturing: false
    property bool captureAllRequested: false
    property var requestedWindowIds: []
    
    // Debounce: coalesce rapid capture requests (e.g. hovering across multiple dock icons)
    Timer {
        id: captureDebounceTimer
        interval: 100  // 100ms debounce — fast enough to feel instant, slow enough to coalesce
        repeat: false
        onTriggered: root._doCapture()
    }

    
    signal captureComplete()
    signal previewUpdated(int windowId)

    Component.onCompleted: {
        // Lazy init: only when TaskView actually requests previews.
    }
    
    function initialize(): void {
        if (initialized) return
        initialized = true
        ensureDirProcess.running = true
    }

    function _resumeRequestedCapture(): void {
        if (!captureRequestedWhileInitializing)
            return
        captureRequestedWhileInitializing = false
        captureDebounceTimer.restart()
    }

    function _queueWindowIds(windowIds): void {
        if (windowIds === null || windowIds === undefined) {
            captureAllRequested = true
            requestedWindowIds = []
            return
        }
        if (captureAllRequested || !Array.isArray(windowIds))
            return
        const merged = new Set(requestedWindowIds)
        for (const rawId of windowIds) {
            const id = Number(rawId)
            if (Number.isFinite(id) && id > 0)
                merged.add(id)
        }
        requestedWindowIds = Array.from(merged)
    }

    function _hasPendingCaptureRequest(): bool {
        return captureAllRequested || requestedWindowIds.length > 0
    }

    function _clearCaptureRequest(): void {
        captureAllRequested = false
        requestedWindowIds = []
    }

    function _pendingRequestNeedsCapture(): bool {
        const currentIds = captureAllRequested
            ? (NiriService.windows ?? []).map(window => window.id)
            : requestedWindowIds
        for (const id of currentIds) {
            if (PreviewPolicy.needsCapture(previewCache[id]))
                return true
        }
        return false
    }

    function _resetForCurrentSession(): void {
        sessionResetProcess.running = true
    }
    
    Process {
        id: ensureDirProcess
        property bool startObserved: false
        command: ["/usr/bin/mkdir", "-p", root.previewDir]
        onRunningChanged: {
            if (ensureDirProcess.running) {
                ensureDirProcess.startObserved = false
                return
            }
            if (ensureDirProcess.startObserved)
                return

            console.warn("[WindowPreviewService] preview directory helper failed to start")
            sessionReadProcess.running = true
        }
        onStarted: ensureDirProcess.startObserved = true
        onExited: sessionReadProcess.running = true
    }

    Process {
        id: sessionReadProcess
        property bool startObserved: false
        command: ["/usr/bin/cat", root.sessionMarkerPath]
        stdout: StdioCollector { id: sessionReadOutput }
        onRunningChanged: {
            if (sessionReadProcess.running) {
                sessionReadProcess.startObserved = false
                return
            }
            if (sessionReadProcess.startObserved)
                return

            console.warn("[WindowPreviewService] session marker reader failed to start")
            if (root.initialized && !root.sessionReady)
                root._resetForCurrentSession()
        }
        onStarted: sessionReadProcess.startObserved = true
        onExited: exitCode => {
            if (!root.initialized || root.sessionReady) return
            const previousKey = exitCode === 0 ? sessionReadOutput.text.trim() : ""
            if (root.sessionKey.length > 0 && previousKey === root.sessionKey)
                scanProcess.running = true
            else
                root._resetForCurrentSession()
        }
    }

    FileView {
        id: sessionFileView
        path: root.sessionMarkerPath
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: sessionResetProcess
        property bool startObserved: false
        command: [
            "/usr/bin/find", root.previewDir,
            "-maxdepth", "1", "-type", "f",
            "-name", "window-*.png", "-delete"
        ]
        onRunningChanged: {
            if (sessionResetProcess.running) {
                sessionResetProcess.startObserved = false
                return
            }
            if (sessionResetProcess.startObserved)
                return

            console.warn("[WindowPreviewService] session reset helper failed to start")
            root.previewCache = ({})
            root.sessionReady = true
            if (root.sessionKey.length > 0)
                sessionFileView.setText(root.sessionKey + "\n")
            root.captureComplete()
            root._resumeRequestedCapture()
        }
        onStarted: sessionResetProcess.startObserved = true
        onExited: {
            root.previewCache = ({})
            root.sessionReady = true
            if (root.sessionKey.length > 0)
                sessionFileView.setText(root.sessionKey + "\n")
            root.captureComplete()
            root._resumeRequestedCapture()
        }
    }
    
    Process {
        id: scanProcess
        property bool startObserved: false
        command: ["/usr/bin/ls", "-1", root.previewDir]
        stdout: SplitParser {
            onRead: data => {
                const filename = data.trim()
                const match = filename.match(/^window-(\d+)\.png$/)
                if (match) {
                    const id = parseInt(match[1])
                    root.previewCache[id] = {
                        path: root.previewDir + "/" + filename,
                        timestamp: Date.now()
                    }
                }
            }
        }
        onRunningChanged: {
            if (scanProcess.running) {
                scanProcess.startObserved = false
                return
            }
            if (scanProcess.startObserved)
                return

            console.warn("[WindowPreviewService] preview cache scan failed to start")
            root.cleanupOrphans()
            root.previewCache = Object.assign({}, root.previewCache)
            root.sessionReady = true
            root.captureComplete()
            root._resumeRequestedCapture()
        }
        onStarted: scanProcess.startObserved = true
        onExited: {
            _log("[WindowPreviewService] Loaded", Object.keys(root.previewCache).length, "cached previews")
            root.cleanupOrphans()
            root.previewCache = Object.assign({}, root.previewCache)
            root.sessionReady = true
            root.captureComplete()
            root._resumeRequestedCapture()
        }
    }
    
    // Remove previews for windows that no longer exist
    function cleanupOrphans(): void {
        const windows = NiriService.windows ?? []
        const windowIds = new Set(windows.map(w => w.id))
        
        const toDelete = []
        for (const id in previewCache) {
            if (!windowIds.has(parseInt(id))) {
                toDelete.push(id)
            }
        }
        
        if (toDelete.length > 0) {
            for (const id of toDelete) {
                delete previewCache[id]
            }
            previewCache = Object.assign({}, previewCache)
            
            // Delete files
            const cmd = ["/usr/bin/rm", "-f"]
            for (const id of toDelete) {
                cmd.push(root.previewDir + "/window-" + id + ".png")
            }
            Quickshell.execDetached(cmd)
        }
    }


    
    // Called when TaskView/dock preview opens - debounced to coalesce rapid hover events
    function captureForTaskView(windowIds = null): void {
        root._queueWindowIds(windowIds)
        if (!initialized) initialize()

        // Always emit captureComplete immediately so cached previews show instantly
        root.captureComplete()

        if (!sessionReady) {
            captureRequestedWhileInitializing = true
            return
        }

        if (capturing) return

        // A prior capture is a cache hit even after hours of idle.
        if (!root._pendingRequestNeedsCapture()) {
            root._clearCaptureRequest()
            return
        }

        captureDebounceTimer.restart()
    }

    // Internal: actual capture logic, called after debounce
    function _doCapture(): void {
        if (capturing) return
        
        const allWindows = NiriService.windows ?? []
        const requestedIds = new Set(root.requestedWindowIds)
        const captureEverything = root.captureAllRequested
        root._clearCaptureRequest()
        const windows = captureEverything
            ? allWindows
            : allWindows.filter(window => requestedIds.has(window.id))
        if (windows.length === 0) return
        
        const idsToCapture = []
        
        for (const win of windows) {
            const cached = previewCache[win.id]
            // Normal requests only fill missing previews.
            if (PreviewPolicy.needsCapture(cached)) {
                idsToCapture.push(win.id)
            }
        }
        
        if (idsToCapture.length === 0) {
            root.captureComplete()
            return
        }
        
        _log("[WindowPreviewService] Capturing", idsToCapture.length, "windows")
        capturing = true
        Cliphist.suppressRefresh = true
        
        // Build command with IDs
        const cmd = ShellExec.supportsFish()
            ? ["/usr/bin/fish", Quickshell.shellPath("scripts/capture-windows.fish")]
            : ["/usr/bin/bash", Quickshell.shellPath("scripts/capture-windows.sh")]
        for (const id of idsToCapture) {
            cmd.push(id.toString())
        }
        
        captureProcess.idsToCapture = idsToCapture
        captureProcess.command = cmd
        captureProcess.running = true
    }
    
    // Capture ALL windows (force refresh)
    function captureAllWindows(): void {
        if (capturing) return

        if (!initialized) initialize()
        
        const windows = NiriService.windows ?? []
        if (windows.length === 0) return
        
        _log("[WindowPreviewService] Force capturing all", windows.length, "windows")
        capturing = true
        Cliphist.suppressRefresh = true
        
        const ids = windows.map(w => w.id)
        captureProcess.idsToCapture = ids
        captureProcess.command = ShellExec.supportsFish()
            ? ["/usr/bin/fish", Quickshell.shellPath("scripts/capture-windows.fish"), "--all"]
            : ["/usr/bin/bash", Quickshell.shellPath("scripts/capture-windows.sh"), "--all"]
        captureProcess.running = true
    }
    
    Process {
        id: captureProcess
        property var idsToCapture: []
        property bool startObserved: false

        stdout: SplitParser {
            onRead: (line) => _log("[WindowPreviewService:capture]", line)
        }
        stderr: SplitParser {
            onRead: (line) => _log("[WindowPreviewService:capture][err]", line)
        }

        onRunningChanged: {
            if (captureProcess.running) {
                captureProcess.startObserved = false
                return
            }
            if (captureProcess.startObserved)
                return

            console.warn("[WindowPreviewService] capture process failed to start")
            root.capturing = false
            idsToCapture = []
            Cliphist.suppressRefresh = false
            Cliphist.refresh()
            root.captureComplete()
            if (root._hasPendingCaptureRequest())
                captureDebounceTimer.restart()
        }
        onStarted: captureProcess.startObserved = true
        
        onExited: (exitCode, exitStatus) => {
            root.capturing = false

            if (exitCode !== 0) {
                console.log("[WindowPreviewService] capture process failed", exitCode, exitStatus)
            } else {
                const timestamp = Date.now()
                for (const id of idsToCapture) {
                    const path = root.previewDir + "/window-" + id + ".png"
                    root.previewCache[id] = {
                        path: path,
                        timestamp: timestamp
                    }
                    root.previewUpdated(id)
                }
                root.previewCache = Object.assign({}, root.previewCache)
            }
            
            idsToCapture = []
            // The capture script has already removed only its own entries and
            // conditionally restored the clipboard before returning.
            Cliphist.suppressRefresh = false
            Cliphist.refresh()
            root.captureComplete()
            if (root._hasPendingCaptureRequest())
                captureDebounceTimer.restart()
        }
    }
    
    // Clean up when window closes
    Connections {
        target: NiriService
        enabled: root.initialized  // Skip event processing until initialized
        
        function onWindowsChanged(): void {
            cleanupTimer.restart()
        }
    }
    
    Timer {
        id: cleanupTimer
        interval: 1000
        onTriggered: root.cleanupOrphans()
    }
    
    // Public API
    function getPreviewUrl(windowId: int): string {
        const cached = previewCache[windowId]
        if (PreviewPolicy.needsCapture(cached)) return ""
        return "file://" + cached.path + "?" + cached.timestamp
    }
    
    function hasPreview(windowId: int): bool {
        return !PreviewPolicy.needsCapture(previewCache[windowId])
    }
    
    function clearPreviews(): void {
        Quickshell.execDetached(["/usr/bin/rm", "-rf", previewDir])
        previewCache = {}
    }
}
