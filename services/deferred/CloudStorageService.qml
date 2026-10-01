pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

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
        root._pendingGeneration = root.generation
        root._pendingId = "cloud-detect-" + (++root.requestSerial)
        root._pendingInput = JSON.stringify({
            protocol: 1, request_id: root._pendingId, operation: "detect", params: {}
        }) + "\n"
        readProc.stdinEnabled = true
        readProc.running = true
    }

    function finishRead(exitCode, payload) {
        root.readBusy = false
        if (root.consumerCount > 0 && root._pendingGeneration === root.generation) {
            // An invalid or oversized reply never becomes a plausible success.
            if (exitCode !== 0 || payload.length > 65536) {
                root.backendState = "unavailable"
                root.safeError = "Rust helper unavailable or response too large."
            } else {
                try {
                    const reply = JSON.parse(payload)
                    const result = reply.result
                    if (reply.protocol !== 1 || reply.request_id !== root._pendingId
                            || reply.ok !== true || !result
                            || result.probe_kind !== "static_no_vendor_execution"
                            || result.vendor_execution !== "auth_blocked_pending_disposable_qualification"
                            || !Array.isArray(result.binaries))
                        throw new Error("protocol")
                    const names = ["mega-cmd", "mega-login", "mega-cmd-server",
                        "mega-whoami", "mega-version"]
                    if (result.binaries.length !== names.length
                            || result.binaries.some((entry, i) =>
                                entry.name !== names[i] || typeof entry.executable !== "boolean"))
                        throw new Error("inventory")
                    // Never surface vendor paths, raw stderr or arbitrary vendor text.
                    const shell = result.binaries[0].executable
                    const server = result.binaries[2].executable
                    root.dependencySnapshot = {
                        installed: shell && server, shell: shell, server: server,
                        observedAt: Date.now()
                    }
                    root.backendState = shell && server
                        ? "installed_disconnected" : "dependency_missing"
                    root.safeError = ""
                } catch (ignored) {
                    root.backendState = "unavailable"
                    root.safeError = "Incompatible Cloud Storage backend response."
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
            readDeadline.restart()
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
            root.safeError = "Static dependency check timed out."
            // This request is static-only: stopping it cannot cancel a vendor mutation.
            readProc.running = false
        }
    }
}
