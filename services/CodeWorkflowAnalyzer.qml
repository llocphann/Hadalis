pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "idle"
    property string sourcePath: ""
    property var result: ({})
    property var diagnostics: []
    property string error: ""
    property string _pendingPath: ""
    property bool _pendingForce: false

    readonly property int entryCount: root.result?.entries?.length ?? 0

    function request(path: string, force: bool): void {
        const nextPath = String(path ?? "")
        if (nextPath.length === 0)
            return

        if (analyzerProcess.running) {
            root._pendingPath = nextPath
            root._pendingForce = root._pendingForce || force
            return
        }

        if (!force && root.sourcePath === nextPath
                && (root.status === "ready"
                    || root.status === "unavailable"))
            return

        root.sourcePath = nextPath
        root.status = "analyzing"
        root.error = ""
        root.result = ({})
        root.diagnostics = []
        analyzerProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/analyze.py"),
            "--path", nextPath
        ]
        analyzerProcess.running = true
    }

    function _finish(exitCode: int): void {
        const raw = String(analyzerStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        if (payload?.protocol === 1 && payload?.status === "ok") {
            root.result = payload
            root.diagnostics = payload.diagnostics ?? []
            root.error = ""
            root.status = "ready"
        } else if (payload?.protocol === 1
                && payload?.status === "unavailable") {
            root.result = payload
            root.diagnostics = []
            root.error = String(payload.reason ?? "parser unavailable")
            root.status = "unavailable"
        } else {
            root.result = payload ?? ({})
            root.diagnostics = payload?.diagnostics ?? []
            const stderrText = String(analyzerStderr.text ?? "").trim()
            root.error = String(payload?.detail
                ?? payload?.reason
                ?? stderrText
                ?? ("analyzer exited " + exitCode))
            root.status = "error"
        }

        if (root._pendingPath.length > 0) {
            const pending = root._pendingPath
            const force = root._pendingForce
            root._pendingPath = ""
            root._pendingForce = false
            Qt.callLater(() => root.request(pending, force))
        }
    }

    Process {
        id: analyzerProcess
        running: false
        stdout: StdioCollector { id: analyzerStdout }
        stderr: StdioCollector { id: analyzerStderr }
        onExited: (exitCode, _exitStatus) => root._finish(exitCode)
    }
}
