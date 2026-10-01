pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "CloudStorageStaticProtocol.js" as StaticProtocol
import "CloudStoragePreflightProtocol.js" as PreflightProtocol

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
    // Opt-in, vendor-free F1 preflight is independent of automatic detection.
    property bool preflightBusy: false
    property string preflightState: "not_requested"
    property string preflightError: ""
    property int preflightSerial: 0
    property int _preflightGeneration: -1
    property string _preflightId: ""
    property string _preflightInput: ""

    function invalidatePreflightOnStaticTimeout() {
        // A static detection timeout invalidates the generation shared with
        // in-flight offline preflight. Revoke it explicitly so an old child
        // cannot leave the UI stuck in "checking" or claim dependencies ready.
        if (root.preflightState === "not_requested" && !root.preflightBusy
                && !preflightProc.running) return
        root._preflightGeneration = -1
        root._preflightInput = ""
        preflightDeadline.stop()
        if (root.preflightBusy || preflightProc.running) {
            if (preflightProc.startObserved) {
                preflightProc.signal(9)
            } else {
                preflightProc.running = false
                root.preflightBusy = false
            }
        }
        if (root.consumerCount > 0) {
            root.preflightState = "unavailable"
            root.preflightError =
                "Offline readiness invalidated by static dependency timeout."
        }
    }

    function registerConsumer() {
        root.consumerCount++
        if (root.consumerCount === 1) {
            root.preflightState = "not_requested"
            root.preflightError = ""
            root.refreshStatic()
        }
    }

    function unregisterConsumer() {
        if (root.consumerCount === 0) return
        root.consumerCount--
        if (root.consumerCount === 0) {
            root.generation++
            root.refreshPending = false
            // Cancel an in-flight opt-in probe when its final UI lease goes.
            // A new consumer cannot dispatch another probe until the old
            // process exits; never leave a timer able to revive stale state.
            root._preflightGeneration = -1
            root._preflightInput = ""
            preflightDeadline.stop()
            if (root.preflightBusy || preflightProc.running) {
                if (preflightProc.startObserved) {
                    preflightProc.signal(9)
                } else {
                    preflightProc.running = false
                    root.preflightBusy = false
                }
            }
            root.preflightState = "not_requested"
            root.preflightError = ""
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
        readProc.startObserved = false
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

    function requestConnectPreflight() {
        // Requires a visible consumer's explicit action; never starts a vendor.
        if (root.consumerCount === 0 || root.preflightBusy || preflightProc.running) return
        root.preflightBusy = true
        root.preflightState = "checking"
        root.preflightError = ""
        root._preflightGeneration = root.generation
        root._preflightId = "cloud-preflight-" + (++root.preflightSerial)
        root._preflightInput = JSON.stringify({
            protocol: 1, request_id: root._preflightId,
            operation: "connect_preflight", params: {}
        }) + "\n"
        preflightProc.startObserved = false
        preflightProc.stdinEnabled = true
        preflightDeadline.restart()
        preflightProc.running = true
    }

    function finishPreflight(exitCode, payload) {
        root.preflightBusy = false
        if (root.consumerCount === 0 || root._preflightGeneration !== root.generation)
            return
        if (exitCode !== 0) {
            root.preflightState = "unavailable"
            root.preflightError = "Offline connection readiness check failed."
            return
        }
        try {
            const result = PreflightProtocol.parseConnectPreflightResponse(
                payload, root._preflightId)
            root.preflightState = result.dependenciesReady
                ? "dependencies_ready" : "dependency_missing"
            root.preflightError = ""
        } catch (ignored) {
            root.preflightState = "unavailable"
            root.preflightError = "Incompatible offline connection readiness response."
        }
    }

    Process {
        id: preflightProc
        property bool startObserved: false
        command: [Quickshell.shellPath("scripts/native-dispatch"), "mega", "request"]
        stdout: StdioCollector { id: preflightReply }
        stderr: StdioCollector {} // No raw child output in UI.
        onStarted: {
            preflightProc.startObserved = true
            if (!root.preflightBusy || root.consumerCount === 0
                    || root._preflightGeneration !== root.generation
                    || root._preflightInput.length === 0) {
                preflightProc.signal(9)
                return
            }
            preflightProc.write(root._preflightInput)
            root._preflightInput = ""
            preflightProc.stdinEnabled = false
        }
        onExited: (exitCode, exitStatus) => {
            preflightDeadline.stop()
            preflightProc.startObserved = false
            root.finishPreflight(exitCode, preflightReply.text)
        }
    }

    Timer {
        id: preflightDeadline
        interval: 6000
        repeat: false
        onTriggered: {
            // Discard late replies. A now-hidden page must not surface a
            // timeout error or clear the current static dependency snapshot.
            const stillDemanded = root.consumerCount > 0
                && root._preflightGeneration === root.generation
            root._preflightGeneration = -1
            root._preflightInput = ""
            if (stillDemanded) {
                root.preflightState = "unavailable"
                root.preflightError = "Offline connection readiness check timed out."
            }
            if (preflightProc.startObserved) {
                preflightProc.signal(9)
            } else {
                preflightProc.running = false
                root.preflightBusy = false
            }
        }
    }

    Process {
        id: readProc
        property bool startObserved: false
        command: [Quickshell.shellPath("scripts/native-dispatch"), "mega", "request"]
        stdout: StdioCollector { id: replyCollector }
        stderr: StdioCollector {} // Never expose raw stderr.
        onStarted: {
            readProc.startObserved = true
            // A helper that starts after its deadline must never receive a new request.
            if (!root.readBusy || root._pendingInput.length === 0) {
                readProc.signal(9)
                return
            }
            readProc.write(root._pendingInput)
            root._pendingInput = ""
            readProc.stdinEnabled = false
        }
        onExited: (exitCode, exitStatus) => {
            readDeadline.stop()
            readProc.startObserved = false
            root.finishRead(exitCode, replyCollector.text)
        }
    }

    Timer {
        id: readDeadline
        interval: 6000
        repeat: false
        onTriggered: {
            root.invalidatePreflightOnStaticTimeout()
            root.generation++
            root.backendState = "unavailable"
            root.dependencySnapshot = null
            root.safeError = "Static dependency check timed out."
            root._pendingInput = ""
            if (readProc.startObserved) {
                // Never admit another request before the timed-out child is reaped.
                // Only the static, no-vendor Rust helper may be terminated here.
                readProc.signal(9)
            } else {
                // The executable never reported startup: no exited() is guaranteed.
                readProc.running = false
                root.readBusy = false
                root.refreshPending = false
            }
        }
    }
}
