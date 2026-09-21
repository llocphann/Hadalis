pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string shellRoot:
        FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    property string state: "idle"
    property string error: ""
    property string path: ""
    property int cols: 80
    property int rows: 24
    property int cursorRow: 0
    property int cursorCol: 0
    property string mode: "normal"
    property bool mouseEnabled: false
    property int revision: 0
    property var gridRows: []
    property var highlights: ({})
    property var defaultColors: ({
        foreground: -1,
        background: -1,
        special: -1
    })
    readonly property bool running: nvimBridgeProcess.running
    readonly property bool ready: root.state === "ready"
    readonly property bool available:
        root.state !== "unavailable"

    function _blankGrid(rowCount: int): var {
        const out = []
        for (let row = 0; row < Math.max(2, rowCount); ++row)
            out.push([])
        return out
    }

    function _send(payload): bool {
        if (!nvimBridgeProcess.running)
            return false
        nvimBridgeProcess.write(JSON.stringify(payload) + "\n")
        return true
    }

    function _applyFrame(frame): void {
        const nextRows = root.gridRows.slice()
        const rowCount = Math.max(2, Number(frame?.rows ?? root.rows))
        while (nextRows.length < rowCount)
            nextRows.push([])
        if (nextRows.length > rowCount)
            nextRows.length = rowCount

        for (const patch of (frame?.dirtyRows ?? [])) {
            const row = Number(patch?.row ?? -1)
            if (row < 0 || row >= rowCount)
                continue
            nextRows[row] = Array.from(patch?.cells ?? [])
        }

        const highlightPatch = frame?.highlights ?? null
        if (highlightPatch) {
            const merged = Object.assign({}, root.highlights)
            for (const key of Object.keys(highlightPatch))
                merged[key] = highlightPatch[key]
            root.highlights = merged
        }

        if (frame?.defaults)
            root.defaultColors = Object.assign({}, frame.defaults)

        root.cols = Math.max(2, Number(frame?.cols ?? root.cols))
        root.rows = rowCount
        root.cursorRow = Math.max(
            0, Math.min(root.rows - 1, Number(frame?.cursorRow ?? 0)))
        root.cursorCol = Math.max(
            0, Math.min(root.cols - 1, Number(frame?.cursorCol ?? 0)))
        root.mode = String(frame?.mode ?? root.mode)
        root.mouseEnabled = frame?.mouseEnabled === true
        root.gridRows = nextRows
        root.revision += 1
    }

    function _handleMessage(line: string): void {
        const text = String(line ?? "").trim()
        if (text.length === 0)
            return
        let message = null
        try {
            message = JSON.parse(text)
        } catch (error) {
            root.error = "Invalid Neovim bridge message"
            return
        }

        const type = String(message?.type ?? "")
        if (type === "frame") {
            root._applyFrame(message)
            return
        }
        if (type === "state") {
            root.state = String(message?.state ?? "error")
            if (message?.path)
                root.path = String(message.path)
            if (message?.error)
                root.error = String(message.error)
            else if (root.state === "ready")
                root.error = ""
            return
        }
        if (type === "rpc-error" || type === "command-error") {
            root.error = String(message?.error ?? type)
            return
        }
        if (type === "stderr") {
            const stderrText = String(message?.text ?? "").trim()
            if (stderrText.length > 0)
                root.error = stderrText
        }
    }

    function start(targetPath: string, nextCols: int, nextRows: int): bool {
        const requestedPath = String(targetPath ?? "")
        if (requestedPath.length === 0)
            return false

        const safeCols = Math.max(2, Math.floor(Number(nextCols ?? 80)))
        const safeRows = Math.max(2, Math.floor(Number(nextRows ?? 24)))

        if (nvimBridgeProcess.running) {
            if (root.path !== requestedPath)
                root.open(requestedPath)
            root.resize(safeCols, safeRows)
            return true
        }

        root.path = requestedPath
        root.cols = safeCols
        root.rows = safeRows
        root.cursorRow = 0
        root.cursorCol = 0
        root.mode = "normal"
        root.mouseEnabled = false
        root.gridRows = root._blankGrid(safeRows)
        root.highlights = ({})
        root.defaultColors = ({
            foreground: -1,
            background: -1,
            special: -1
        })
        root.error = ""
        root.state = "starting"

        nvimBridgeProcess.command = [
            "/usr/bin/python3",
            Quickshell.shellPath("scripts/code-workflow-nvim-bridge.py"),
            "--root", root.shellRoot,
            "--file", requestedPath,
            "--cols", String(safeCols),
            "--rows", String(safeRows)
        ]
        nvimBridgeProcess.running = true
        return true
    }

    function open(targetPath: string): bool {
        const requestedPath = String(targetPath ?? "")
        if (requestedPath.length === 0)
            return false
        root.path = requestedPath
        return root._send({
            op: "open",
            path: requestedPath
        })
    }

    function resize(nextCols: int, nextRows: int): bool {
        const safeCols = Math.max(2, Math.floor(Number(nextCols ?? root.cols)))
        const safeRows = Math.max(2, Math.floor(Number(nextRows ?? root.rows)))
        if (safeCols === root.cols && safeRows === root.rows)
            return true
        root.cols = safeCols
        root.rows = safeRows
        return root._send({
            op: "resize",
            cols: safeCols,
            rows: safeRows
        })
    }

    function input(keys: string): bool {
        const payload = String(keys ?? "")
        return payload.length > 0 && root._send({
            op: "input",
            keys: payload
        })
    }

    function save(): bool {
        return root._send({ op: "save" })
    }

    function mouse(
        button: string, action: string, modifier: string,
        row: int, col: int
    ): bool {
        return root._send({
            op: "mouse",
            button: String(button ?? "left"),
            action: String(action ?? "press"),
            modifier: String(modifier ?? ""),
            row: Math.max(0, Number(row ?? 0)),
            col: Math.max(0, Number(col ?? 0))
        })
    }

    function stop(): void {
        if (!nvimBridgeProcess.running) {
            root.state = "idle"
            return
        }
        root._send({ op: "stop" })
        bridgeStopFallback.restart()
    }

    Process {
        id: nvimBridgeProcess
        running: false
        stdinEnabled: true
        workingDirectory: root.shellRoot

        stdout: SplitParser {
            onRead: data => root._handleMessage(data)
        }

        stderr: SplitParser {
            onRead: data => {
                const text = String(data ?? "").trim()
                if (text.length > 0)
                    root.error = text
            }
        }

        onStarted: {
            root.state = "starting"
            root.error = ""
        }

        onExited: (exitCode, exitStatus) => {
            bridgeStopFallback.stop()
            if (root.state !== "unavailable")
                root.state = exitCode === 0 ? "stopped" : "error"
            if (exitCode !== 0 && root.error.length === 0)
                root.error = "Neovim bridge exited · " + String(exitCode)
        }
    }

    Timer {
        id: bridgeStopFallback
        interval: 500
        repeat: false
        onTriggered: {
            if (nvimBridgeProcess.running)
                nvimBridgeProcess.running = false
        }
    }
}
