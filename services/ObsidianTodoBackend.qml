pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Read-only Obsidian Markdown backend for Todo.
 *
 * The backend is deliberately useful without Obsidian running: the canonical
 * read path is the configured Markdown file plus the safe Python scanner.
 * Mutation/capability logic is added separately after this read boundary is
 * proven stable.
 */
Scope {
    id: root

    property bool active: false
    property string vaultPath: ""
    property string notePath: ""

    property var list: []
    property bool ready: false
    property bool busy: false
    property string errorCode: ""
    property string errorMessage: ""
    property string noteFullPath: ""
    property var documentMeta: ({})
    property var managedMeta: ({})

    property bool _refreshQueued: false

    readonly property bool configured:
        root.active
        && root.vaultPath.trim().length > 0
        && root.notePath.trim().length > 0

    readonly property string helperPath:
        Quickshell.shellPath("scripts/todo/obsidian_todo.py")

    readonly property string watchPath: {
        if (!root.configured)
            return ""
        const base = root.vaultPath.endsWith("/")
            ? root.vaultPath.slice(0, -1)
            : root.vaultPath
        const note = root.notePath.startsWith("/")
            ? root.notePath.slice(1)
            : root.notePath
        return base + "/" + note
    }

    function _clearUnavailable(code: string, message: string): void {
        root.list = []
        root.ready = false
        root.busy = false
        root.errorCode = code
        root.errorMessage = message
        root.noteFullPath = ""
        root.documentMeta = ({})
        root.managedMeta = ({})
    }

    function _scheduleRefresh(): void {
        if (!root.configured) {
            configDebounce.stop()
            scanDebounce.stop()
            root._clearUnavailable("", "")
            return
        }
        configDebounce.restart()
    }

    function refresh(): void {
        if (!root.configured) {
            root._clearUnavailable("not_configured", "Obsidian Todo source is not configured")
            return
        }
        if (scanProc.running) {
            root._refreshQueued = true
            return
        }

        root.busy = true
        root.errorCode = ""
        root.errorMessage = ""
        scanProc.command = [
            "/usr/bin/python3",
            root.helperPath,
            "scan",
            "--vault", root.vaultPath,
            "--note", root.notePath
        ]
        scanProc.running = true
    }

    function _finishScan(): void {
        root.busy = false
        if (root._refreshQueued && root.configured) {
            root._refreshQueued = false
            Qt.callLater(() => root.refresh())
        }
    }

    function _applyScanPayload(payload): void {
        if (!payload || payload.ok !== true) {
            const error = payload?.error ?? ({})
            root._clearUnavailable(
                String(error.code ?? "scan_failed"),
                String(error.message ?? "Failed to scan Obsidian Todo note")
            )
            return
        }

        root.list = Array.isArray(payload.tasks) ? payload.tasks : []
        root.noteFullPath = String(payload.noteFullPath ?? "")
        root.documentMeta = payload.document ?? ({})
        root.managedMeta = payload.managed ?? ({})
        root.errorCode = ""
        root.errorMessage = ""
        root.ready = true
    }

    onActiveChanged: root._scheduleRefresh()
    onVaultPathChanged: root._scheduleRefresh()
    onNotePathChanged: root._scheduleRefresh()

    Component.onCompleted: root._scheduleRefresh()

    FileView {
        id: noteWatcher
        path: root.watchPath
        preload: false
        printErrors: false
        watchChanges: root.configured

        onFileChanged: {
            if (root.configured)
                scanDebounce.restart()
        }
    }

    Timer {
        id: configDebounce
        interval: 80
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: scanDebounce
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: scanTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (!scanProc.running)
                return
            scanProc.timedOut = true
            scanProc.running = false
        }
    }

    Process {
        id: scanProc
        running: false
        property bool startObserved: false
        property bool timedOut: false

        stdout: StdioCollector {
            id: scanCollector
        }

        onRunningChanged: {
            if (scanProc.running) {
                scanProc.startObserved = false
                return
            }
            if (scanProc.startObserved)
                return

            scanTimeout.stop()
            root._clearUnavailable(
                "scanner_start_failed",
                "Failed to start Obsidian Todo scanner"
            )
            root._finishScan()
        }

        onStarted: {
            scanProc.startObserved = true
            scanProc.timedOut = false
            scanTimeout.restart()
        }

        onExited: (exitCode, exitStatus) => {
            scanTimeout.stop()

            if (scanProc.timedOut) {
                root._clearUnavailable(
                    "scanner_timeout",
                    "Obsidian Todo scanner timed out"
                )
                root._finishScan()
                return
            }

            const output = String(scanCollector.text ?? "").trim()
            if (output.length === 0) {
                root._clearUnavailable(
                    "scanner_failed",
                    "Obsidian Todo scanner exited without a result"
                )
                root._finishScan()
                return
            }

            try {
                root._applyScanPayload(JSON.parse(output))
            } catch (error) {
                root._clearUnavailable(
                    "scanner_invalid_output",
                    "Obsidian Todo scanner returned invalid JSON"
                )
            }
            root._finishScan()
        }
    }
}
