pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string clientId:
        "settings:" + String(Quickshell.processId)
    readonly property int heartbeatIntervalMs: 2000
    readonly property bool localShell:
        CodeWorkflowRuntime.hasLocalDeclarations

    // Multiple Settings hosts can exist briefly while chrome/style ownership
    // changes. Lease state is therefore owner-based rather than one mutable bool.
    property var activeOwners: ({})
    readonly property bool pageCurrent:
        Object.keys(root.activeOwners).length > 0
    property string remoteError: ""
    readonly property var evidence: root.localShell
        ? RuntimeDiagnostics.snapshot()
        : (CodeWorkflowRuntime.remoteSnapshot?.diagnostics ?? null)

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
        if (remotePulse.running)
            return
        root.remoteError = ""
        remotePulse.command = root._remoteCommand(action)
        remotePulse.running = true
    }

    function _releaseRemote(): void {
        if (remoteRelease.running)
            return
        remoteRelease.command = root._remoteCommand("release")
        remoteRelease.running = true
    }

    function _acquireLease(): void {
        if (root.localShell) {
            RuntimeDiagnostics.acquire(root.clientId)
            return
        }
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
        if (root.localShell)
            RuntimeDiagnostics.release(root.clientId)
        else
            root._releaseRemote()
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
        running: false
        command: []

        stdout: StdioCollector {}
        stderr: StdioCollector { id: remotePulseError }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.remoteError =
                    String(remotePulseError.text ?? "").trim()
        }
    }

    Process {
        id: remoteRelease
        running: false
        command: []

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    onLocalShellChanged: {
        if (root.pageCurrent)
            root._renewLease()
    }

    Component.onDestruction: {
        // Crash/disconnect safety is owned by the server TTL; this is only a
        // best-effort clean release for normal Settings process shutdown.
        if (root.pageCurrent)
            root._releaseLease()
    }
}
