pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "clean"
    property string sourcePath: ""
    property string baseSha256: ""
    property string semanticAnchor: ""
    property string replacement: ""
    property var result: ({})
    property var patch: ({})
    property string previewText: ""
    property string error: ""

    readonly property bool dirty: root.status !== "clean"
    readonly property bool applyEnabled: false

    function clear(): void {
        if (previewProcess.running)
            return
        root.status = "clean"
        root.sourcePath = ""
        root.baseSha256 = ""
        root.semanticAnchor = ""
        root.replacement = ""
        root.result = ({})
        root.patch = ({})
        root.previewText = ""
        root.error = ""
    }

    function markSourceChanged(path: string): void {
        if (String(path ?? "") !== root.sourcePath)
            return
        if (root.status === "preview") {
            root.status = "conflict"
            root.error = "Source changed after patch preview; regenerate before any future Apply."
        }
    }

    function previewLiteral(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string
    ): bool {
        if (previewProcess.running)
            return false

        const nextPath = String(path ?? "")
        const nextSha = String(baseSha ?? "")
        const nextAnchor = String(anchor ?? "")
        const nextReplacement = String(nextValue ?? "")
        if (nextPath.length === 0
                || nextSha.length === 0
                || nextAnchor.length === 0
                || nextReplacement.length === 0)
            return false

        root.status = "previewing"
        root.sourcePath = nextPath
        root.baseSha256 = nextSha
        root.semanticAnchor = nextAnchor
        root.replacement = nextReplacement
        root.result = ({})
        root.patch = ({})
        root.previewText = ""
        root.error = ""

        previewProcess.command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/transaction.py"),
            "--path", nextPath,
            "--base-sha256", nextSha,
            "--semantic-anchor", nextAnchor,
            "--replacement", nextReplacement
        ]
        previewProcess.running = true
        return true
    }

    function finish(exitCode: int): void {
        const raw = String(previewStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        root.result = payload ?? ({})
        root.patch = payload?.patch ?? ({})
        root.previewText = String(payload?.preview ?? "")

        const nextStatus = String(payload?.status ?? "error")
        if (payload?.protocol === 1 && nextStatus === "preview") {
            root.status = "preview"
            root.error = ""
            return
        }

        if (payload?.protocol === 1
                && ["conflict", "unsupported", "unavailable", "invalid-patch"]
                    .includes(nextStatus)) {
            root.status = nextStatus
            root.error = String(
                payload?.detail
                ?? payload?.reason
                ?? nextStatus)
            return
        }

        root.status = "error"
        const stderrText = String(previewStderr.text ?? "").trim()
        root.error = String(
            payload?.detail
            ?? payload?.reason
            ?? stderrText
            ?? ("transaction preview exited " + exitCode))
    }

    Process {
        id: previewProcess
        running: false
        stdout: StdioCollector { id: previewStdout }
        stderr: StdioCollector { id: previewStderr }
        onExited: (exitCode, _exitStatus) => root.finish(exitCode)
    }
}
