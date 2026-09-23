pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string clientId:
        "settings:" + String(Quickshell.processId)
    readonly property int heartbeatIntervalMs: 2000
    readonly property string remoteRuntimeConsumerId:
        root.clientId + ":diagnostics-runtime"
    readonly property bool localShell:
        CodeWorkflowRuntime.hasLocalDeclarations

    // Multiple Settings hosts can exist briefly while chrome/style ownership
    // changes. Lease state is therefore owner-based rather than one mutable bool.
    property var activeOwners: ({})
    readonly property bool pageCurrent:
        Object.keys(root.activeOwners).length > 0
    property bool releaseAfterPulse: false
    property string leaseTransport: ""
    property string remoteError: ""
    readonly property string evidenceError:
        root.localShell ? "" : CodeWorkflowRuntime.remoteError
    readonly property var evidence: root.localShell
        ? RuntimeDiagnostics.snapshot()
        : (CodeWorkflowRuntime.remoteSnapshot?.diagnostics ?? null)

    function _syncRemoteRuntimeDemand(): void {
        CodeWorkflowRuntime.setRemoteConsumerActive(
            root.remoteRuntimeConsumerId,
            root.pageCurrent && !root.localShell)
    }

    function _ownerId(raw): string {
        const value = String(raw ?? "").trim()
        return value.length > 0 ? value : "settings"
    }

    function _remoteCommand(action: string): var {
        return [
            Quickshell.shellPath("scripts/inir"),
            "ipc", "runtimeDiagnostics",
            action, root.clientId
        ]
    }

    function _pulseRemote(action: string): void {
        if (!root.pageCurrent || remotePulse.running || remoteRelease.running)
            return
        // Keep the last failure visible until a command actually succeeds.
        remotePulse.action = action
        remotePulse.command = root._remoteCommand(action)
        remotePulse.running = true
    }

    function _releaseRemote(): void {
        // A pulse may still be queued at the shell. Sending release before it
        // completes could leave a newly acquired lease alive until the TTL.
        if (remotePulse.running) {
            root.releaseAfterPulse = true
            return
        }
        root.releaseAfterPulse = false
        if (remoteRelease.running)
            return
        remoteRelease.command = root._remoteCommand("release")
        remoteRelease.running = true
    }

    function _acquireLease(): void {
        if (root.localShell) {
            // Preserve a deferred remote release while switching ownership
            // from a remote shell to this process.
            RuntimeDiagnostics.acquire(root.clientId)
            root.leaseTransport = "local"
            return
        }
        root.releaseAfterPulse = false
        root.leaseTransport = "remote"
        root._pulseRemote("acquire")
    }

    function _renewLease(): void {
        if (!root.pageCurrent)
            return
        if (root.localShell) {
            if (!RuntimeDiagnostics.heartbeat(root.clientId))
                RuntimeDiagnostics.acquire(root.clientId)
            return
        }
        root._pulseRemote("heartbeat")
    }

    function _releaseLease(): void {
        const transport = root.leaseTransport
        root.leaseTransport = ""
        if (transport === "local") {
            RuntimeDiagnostics.release(root.clientId)
            return
        }
        if (transport === "remote")
            root._releaseRemote()
    }

    function _remotePulseExited(exitCode: int): void {
        if (exitCode !== 0) {
            const detail = String(remotePulseError.text ?? "").trim()
            root.remoteError = detail.length > 0
                ? detail
                : "Diagnostics lease command exited with " + exitCode
        } else {
            const payload = String(remotePulseOutput.text ?? "").trim()
            try {
                const reply = payload.length > 0 ? JSON.parse(payload) : null
                if (reply?.ok === true) {
                    root.remoteError = ""
                } else if (remotePulse.action === "heartbeat"
                        && root.pageCurrent) {
                    // TTL expiry is recoverable while the page still owns the
                    // session; heartbeat itself never resurrects a dead lease.
                    Qt.callLater(() => root._pulseRemote("acquire"))
                } else if (remotePulse.action === "acquire") {
                    root.remoteError = "Diagnostics lease was rejected"
                }
            } catch (error) {
                root.remoteError =
                    "Diagnostics lease decode failed: " + String(error)
            }
        }
        remotePulse.action = ""
        Qt.callLater(() => {
            if (root.releaseAfterPulse || !root.pageCurrent)
                root._releaseRemote()
        })
    }

    function _remoteReleaseExited(): void {
        // A page can become current again while release is in flight. Reacquire
        // only after that release has completed, so it cannot cancel the lease.
        Qt.callLater(() => {
            if (root.pageCurrent && !root.localShell)
                root._pulseRemote("acquire")
        })
    }

    function setOwnerCurrent(ownerId: string, current: bool): void {
        const id = root._ownerId(ownerId)
        const next = Object.assign({}, root.activeOwners)
        if (current === true)
            next[id] = true
        else
            delete next[id]
        root.activeOwners = next
    }

    // Compatibility helper for simple callers; SettingsPageHost uses the
    // owner-aware API so one host cannot release another host's active lease.
    function setPageCurrent(current: bool): void {
        root.setOwnerCurrent("settings", current)
    }

    onPageCurrentChanged: {
        root._syncRemoteRuntimeDemand()
        if (root.pageCurrent)
            root._acquireLease()
        else
            root._releaseLease()
    }

    Timer {
        id: heartbeatTimer
        interval: root.heartbeatIntervalMs
        repeat: true
        running: root.pageCurrent
        onTriggered: root._renewLease()
    }

    Process {
        id: remotePulse
        property string action: ""
        running: false
        command: []

        stdout: StdioCollector { id: remotePulseOutput }
        stderr: StdioCollector { id: remotePulseError }

        onExited: (exitCode, exitStatus) => root._remotePulseExited(exitCode)
    }

    Process {
        id: remoteRelease
        running: false
        command: []

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => root._remoteReleaseExited()
    }

    onLocalShellChanged: {
        root._syncRemoteRuntimeDemand()
        if (!root.pageCurrent)
            return

        const desiredTransport = root.localShell ? "local" : "remote"
        if (root.leaseTransport === desiredTransport) {
            root._renewLease()
            return
        }

        // Release through the transport that actually acquired the lease.
        // Choosing from the new localShell value can strand the old lease
        // until TTL expiry when runtime ownership moves between processes.
        root._releaseLease()
        Qt.callLater(() => {
            if (root.pageCurrent
                    && root.leaseTransport.length === 0)
                root._acquireLease()
        })
    }

    Component.onDestruction: {
        CodeWorkflowRuntime.setRemoteConsumerActive(
            root.remoteRuntimeConsumerId, false)
        // Crash/disconnect safety is owned by the server TTL; this is only a
        // best-effort clean release for normal Settings process shutdown.
        if (root.pageCurrent)
            root._releaseLease()
    }
}
