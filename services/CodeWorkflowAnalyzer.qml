pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "idle"
    property string sourcePath: ""
    property string sourceNeedle: ""
    property string semanticAnchor: ""
    property var result: ({})
    property var reviewedAnchor: ({ status: "not-requested" })
    property var semanticRebind: ({ status: "not-requested" })
    property var diagnostics: []
    property string error: ""
    property string _pendingPath: ""
    property string _pendingNeedle: ""
    property string _pendingSemanticAnchor: ""
    property bool _pendingForce: false

    readonly property int entryCount: root.result?.entries?.length ?? 0

    function request(path: string, needle: string, semanticAnchor: string, force: bool): void {
        const nextPath = String(path ?? "")
        const nextNeedle = String(needle ?? "")
        const nextSemanticAnchor = String(semanticAnchor ?? "")
        if (nextPath.length === 0)
            return

        if (analyzerProcess.running) {
            root._pendingPath = nextPath
            root._pendingNeedle = nextNeedle
            root._pendingSemanticAnchor = nextSemanticAnchor
            root._pendingForce = root._pendingForce || force
            return
        }

        if (!force
                && root.sourcePath === nextPath
                && root.sourceNeedle === nextNeedle
                && root.semanticAnchor === nextSemanticAnchor
                && (root.status === "ready"
                    || root.status === "unavailable"))
            return

        root.sourcePath = nextPath
        root.sourceNeedle = nextNeedle
        root.semanticAnchor = nextSemanticAnchor
        root.status = "analyzing"
        root.error = ""
        root.result = ({})
        root.reviewedAnchor = ({ status: "analyzing" })
        root.semanticRebind = nextSemanticAnchor.length > 0
            ? ({ status: "analyzing", anchor: nextSemanticAnchor })
            : ({ status: "not-requested" })
        root.diagnostics = []

        const command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/analyze.py"),
            "--path", nextPath
        ]
        if (nextNeedle.length > 0)
            command.push("--needle", nextNeedle)
        if (nextSemanticAnchor.length > 0)
            command.push("--semantic-anchor", nextSemanticAnchor)
        analyzerProcess.command = command
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
            root.reviewedAnchor = payload.reviewedAnchor
                ?? ({ status: "not-requested" })
            root.semanticRebind = payload.semanticRebind
                ?? ({ status: "not-requested" })
            root.diagnostics = payload.diagnostics ?? []
            root.error = ""
            root.status = "ready"
        } else if (payload?.protocol === 1
                && payload?.status === "unavailable") {
            root.result = payload
            root.reviewedAnchor = ({ status: "unavailable" })
            root.semanticRebind = ({ status: "unavailable" })
            root.diagnostics = []
            root.error = String(payload.reason ?? "parser unavailable")
            root.status = "unavailable"
        } else {
            root.result = payload ?? ({})
            root.reviewedAnchor = ({ status: "error" })
            root.semanticRebind = ({ status: "error" })
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
            const pendingNeedle = root._pendingNeedle
            const pendingSemanticAnchor = root._pendingSemanticAnchor
            const force = root._pendingForce
            root._pendingPath = ""
            root._pendingNeedle = ""
            root._pendingSemanticAnchor = ""
            root._pendingForce = false
            Qt.callLater(() => root.request(
                pending,
                pendingNeedle,
                pendingSemanticAnchor,
                force))
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
