pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "idle"
    property var result: ({})
    property string error: ""
    property bool _pendingRefresh: false
    property bool _pendingForce: false
    property bool _cancelled: false

    // Keep the last qualified snapshot visible while a cache-aware refresh
    // is in flight; status still says "indexing", so consumers can distinguish
    // stale presentation evidence from the newly reconciled result.
    readonly property var boundaries:
        root.status === "ready" || root.status === "indexing"
            ? (root.result?.boundaries ?? [])
            : []
    readonly property int boundaryCount: root.boundaries.length
    readonly property int filesScanned:
        Number(root.result?.filesScanned ?? 0)
    readonly property int filesParsed:
        Number(root.result?.filesParsed ?? 0)
    readonly property int cacheHits:
        Number(root.result?.cacheHits ?? 0)
    readonly property string cachePath:
        (Quickshell.env("XDG_CACHE_HOME")
            || (Quickshell.env("HOME") + "/.cache"))
        + "/inir/code-workflow-runtime-boundaries-v1.json"

    function refresh(force: bool): void {
        root._cancelled = false
        if (indexProcess.running) {
            root._pendingRefresh = true
            root._pendingForce = root._pendingForce || force
            return
        }

        root.status = "indexing"
        root.error = ""
        const command = [
            "python3",
            Quickshell.shellPath("scripts/code-workflow/index.py"),
            "--cache", root.cachePath
        ]
        if (force)
            command.push("--force")
        indexProcess.command = command
        indexProcess.running = true
    }

    function cancel(): void {
        root._pendingRefresh = false
        root._pendingForce = false
        if (!indexProcess.running) {
            if (root.status === "indexing")
                root.status = "idle"
            return
        }
        root._cancelled = true
        indexProcess.running = false
    }

    function _finish(exitCode: int): void {
        if (root._cancelled) {
            root._cancelled = false
            root.status = "idle"
            root.error = ""
            return
        }

        const raw = String(indexStdout.text ?? "").trim()
        let payload = null
        try {
            payload = raw.length > 0 ? JSON.parse(raw) : null
        } catch (e) {
            payload = null
        }

        if (payload?.protocol === 1 && payload?.status === "ok") {
            root.result = payload
            root.error = ""
            root.status = "ready"
        } else if (payload?.protocol === 1
                && payload?.status === "unavailable") {
            root.result = payload
            root.error = String(payload.reason ?? "index unavailable")
            root.status = "unavailable"
        } else {
            root.result = payload ?? ({})
            const stderrText = String(indexStderr.text ?? "").trim()
            root.error = String(payload?.detail
                ?? payload?.reason
                ?? stderrText
                ?? ("indexer exited " + exitCode))
            root.status = "error"
        }

        if (root._pendingRefresh) {
            const force = root._pendingForce
            root._pendingRefresh = false
            root._pendingForce = false
            Qt.callLater(() => root.refresh(force))
        }
    }

    Process {
        id: indexProcess
        running: false
        stdout: StdioCollector { id: indexStdout }
        stderr: StdioCollector { id: indexStderr }
        onExited: (exitCode, _exitStatus) => root._finish(exitCode)
    }
}
