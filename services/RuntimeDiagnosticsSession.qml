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
    property bool pageCurrent: false
    property string remoteError: ""

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

    function setPageCurrent(current: bool): void {
        const next = current === true
        if (root.pageCurrent === next) {
            if (next)
                root._renewLease()
            return
        }

        root.pageCurrent = next
        if (next) {
            if (root.localShell)
                RuntimeDiagnostics.acquire(root.clientId)
            else
                root._pulseRemote("acquire")
            return
        }

        if (root.localShell)
            RuntimeDiagnostics.release(root.clientId)
        else
            root._releaseRemote()
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
        if (root.pageCurrent) {
            if (root.localShell)
                RuntimeDiagnostics.release(root.clientId)
            else
                root._releaseRemote()
        }
    }
}
