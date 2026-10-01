pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "CloudStorageStaticProtocol.js" as StaticProtocol

// Dormant, static-only phase. Never execute a vendor client before Connect.
Singleton {
    id: root
    property int consumerCount: 0
    property int generation: 0
    property int requestSerial: 0
    property bool readBusy: false
    property bool refreshPending: false
    property string backendState: "not_checked"
    property string safeError: ""
    property var dependencySnapshot: null
    property string _pendingInput: ""
    property string _pendingId: ""
    property int _pendingGeneration: -1
    readonly property bool connected: false
    readonly property bool liveAuthQualified: false
    readonly property bool installed: root.dependencySnapshot?.installed ?? false

    function registerConsumer() {
        root.consumerCount++
        if (root.consumerCount === 1) root.refreshStatic()
    }

    function unregisterConsumer() {
        if (root.consumerCount === 0) return
        root.consumerCount--
        if (root.consumerCount === 0) {
            root.generation++
            root.refreshPending = false
            if (root.dependencySnapshot !== null)
                root.backendState = "stale"
        }
    }

    function refreshStatic() {
        if (root.consumerCount === 0) return
        if (readProc.running || root.readBusy) {
            root.refreshPending = true
            return
        }
        root.readBusy = true
        root.safeError = ""
        root.backendState = "checking"
        root.dependencySnapshot = null
        root._pendingGeneration = root.generation
        root._pendingId = "cloud-detect-" + (++root.requestSerial)
        root._pendingInput = JSON.stringify({
            protocol: 1, request_id: root._pendingId, operation: "detect", params: {}
        }) + "\n"
        readProc.stdinEnabled = true
        // Start the deadline BEFORE spawning; missing executables must not hang the UI.
        readDeadline.restart()
        readProc.running = true
    }

    function finishRead(exitCode, payload) {
        root.readBusy = false
        if (root.consumerCount > 0 && root._pendingGeneration === root.generation) {
            if (exitCode !== 0) {
                root.dependencySnapshot = null
                root.backendState = "unavailable"
                root.safeError = "Rust helper failed before static detection completed."
            } else {
                try {
                    const normalized = StaticProtocol.parseDetectResponse(payload, root._pendingId)
                    root.dependencySnapshot = Object.assign({observedAt: Date.now()}, normalized)
                    root.backendState = normalized.installed
                        ? "installed_disconnected" : "dependency_missing"
                    root.safeError = ""
                } catch (ignored) {
                    root.dependencySnapshot = null
                    root.backendState = "unavailable"
                    root.safeError = "Incompatible or oversized Cloud Storage response."
                }
            }
        }
        if (root.consumerCount > 0 && root.refreshPending) {
            root.refreshPending = false
            Qt.callLater(root.refreshStatic)
        }
    }

    Process {
        id: readProc
        command: [Quickshell.shellPath("scripts/native-dispatch"), "mega", "request"]
        stdout: StdioCollector { id: replyCollector }
        stderr: StdioCollector {} // Never expose raw stderr.
        onStarted: {
            readProc.write(root._pendingInput)
            root._pendingInput = ""
            readProc.stdinEnabled = false
        }
        onExited: (exitCode, exitStatus) => {
            readDeadline.stop()
            root.finishRead(exitCode, replyCollector.text)
        }
    }

    Timer {
        id: readDeadline
        interval: 6000
        repeat: false
        onTriggered: {
            root.generation++
            root.readBusy = false
            root.backendState = "unavailable"
            root.dependencySnapshot = null
            root.safeError = "Static dependency check timed out."
            // This request is static-only: stopping it cannot cancel a vendor mutation.
            readProc.running = false
        }
    }
}
