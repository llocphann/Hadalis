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

    // Semantic preview commands. Patch byte ranges are evidence attached to a
    // command, never the command identity.
    property var history: []
    property int historyIndex: -1
    property int _pendingReplaceIndex: -1

    readonly property bool dirty: root.status !== "clean"
    readonly property bool applyEnabled: false
    readonly property bool canUndo:
        !previewProcess.running && root.historyIndex >= 0
    readonly property bool canRedo:
        !previewProcess.running
        && root.historyIndex + 1 < root.history.length
    readonly property var activeCommand:
        root.historyIndex >= 0 && root.historyIndex < root.history.length
            ? root.history[root.historyIndex]
            : null
    readonly property string historyLabel:
        root.history.length > 0
            ? (root.historyIndex + 1) + "/" + root.history.length
            : "0/0"

    function _clearPresentation(): void {
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

    function _showCommand(command): void {
        if (!command) {
            root._clearPresentation()
            return
        }

        root.sourcePath = String(command.sourcePath ?? "")
        root.baseSha256 = String(command.baseSha256 ?? "")
        root.semanticAnchor = String(command.semanticAnchor ?? "")
        root.replacement = String(command.replacement ?? "")
        root.result = command.result ?? ({})
        root.patch = command.patch ?? ({})
        root.previewText = String(command.previewText ?? "")
        if (command.stale === true) {
            root.status = "conflict"
            root.error = String(
                command.staleReason
                ?? "Source changed after this preview; regenerate it.")
        } else {
            root.status = "preview"
            root.error = ""
        }
    }

    function clear(): void {
        if (previewProcess.running)
            return
        root.history = []
        root.historyIndex = -1
        root._pendingReplaceIndex = -1
        root._clearPresentation()
    }

    function undoPreview(): bool {
        if (!root.canUndo)
            return false
        root.historyIndex--
        root._showCommand(root.activeCommand)
        return true
    }

    function redoPreview(): bool {
        if (!root.canRedo)
            return false
        root.historyIndex++
        root._showCommand(root.activeCommand)
        return true
    }

    function _markHistoryStale(path: string): void {
        let changed = false
        const next = root.history.map(command => {
            if (String(command.sourcePath ?? "") !== path
                    || command.stale === true)
                return command
            changed = true
            return Object.assign({}, command, {
                stale: true,
                staleReason:
                    "Source changed after this preview; regenerate it."
            })
        })
        if (changed)
            root.history = next
    }

    function markSourceChanged(path: string): void {
        const changedPath = String(path ?? "")
        if (changedPath.length === 0)
            return

        root._markHistoryStale(changedPath)
        if (changedPath === root.sourcePath
                && root.status === "preview") {
            root.status = "conflict"
            root.error =
                "Source changed after patch preview; regenerate before any future Apply."
        }
    }

    function _startPreview(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string,
        replaceIndex: int
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

        root._pendingReplaceIndex = replaceIndex
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

    function previewLiteral(
        path: string,
        baseSha: string,
        anchor: string,
        nextValue: string
    ): bool {
        return root._startPreview(
            path, baseSha, anchor, nextValue, -1)
    }

    function regenerate(baseSha: string): bool {
        const command = root.activeCommand
        if (!command)
            return false
        return root._startPreview(
            String(command.sourcePath ?? ""),
            String(baseSha ?? ""),
            String(command.semanticAnchor ?? ""),
            String(command.replacement ?? ""),
            root.historyIndex)
    }

    function _commitPreviewCommand(payload): void {
        const command = {
            kind: "literal-property",
            sourcePath: root.sourcePath,
            baseSha256: root.baseSha256,
            candidateSha256: String(payload?.candidateSha256 ?? ""),
            semanticAnchor: root.semanticAnchor,
            replacement: root.replacement,
            result: payload,
            patch: payload?.patch ?? ({}),
            previewText: String(payload?.preview ?? ""),
            sourceWritable: payload?.sourceWritable === true,
            stale: false,
            staleReason: ""
        }

        if (root._pendingReplaceIndex >= 0
                && root._pendingReplaceIndex < root.history.length) {
            const next = root.history.slice()
            next[root._pendingReplaceIndex] = command
            root.history = next
            root.historyIndex = root._pendingReplaceIndex
        } else {
            const next = root.history.slice(
                0, root.historyIndex + 1)
            next.push(command)
            root.history = next
            root.historyIndex = next.length - 1
        }
        root._pendingReplaceIndex = -1
        root._showCommand(root.activeCommand)
    }

    function finish(exitCode: int): void {
        const raw = String(previewStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        const nextStatus = String(payload?.status ?? "error")
        if (payload?.protocol === 1 && nextStatus === "preview") {
            root._commitPreviewCommand(payload)
            return
        }

        root._pendingReplaceIndex = -1
        root.result = payload ?? ({})
        root.patch = payload?.patch ?? ({})
        root.previewText = String(payload?.preview ?? "")

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
