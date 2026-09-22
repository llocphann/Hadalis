pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string sourcePath: ""
    property bool active: false
    readonly property string nvimPath: CodeWorkflowNvim.path
    readonly property bool bufferModified: CodeWorkflowNvim.bufferModified
    readonly property string nvimMode: CodeWorkflowNvim.mode
    readonly property bool nvimReady: CodeWorkflowNvim.ready
    property bool cursorBlinkVisible: true
    property string cursorBlinkPhase: "steady"
    property int lastPaintCursorRow: 0
    readonly property real cellWidth: Math.max(1, Math.ceil(cellMetrics.width))
    readonly property real cellHeight: Math.max(1, Math.ceil(fontMetrics.height))
    readonly property int requestedCols:
        Math.max(2, Math.floor(width / Math.max(1, root.cellWidth)))
    readonly property int requestedRows:
        Math.max(2, Math.floor(height / Math.max(1, root.cellHeight)))

    function rgbColor(value, fallback): var {
        const numeric = Number(value ?? -1)
        if (!Number.isFinite(numeric) || numeric < 0)
            return fallback
        return "#" + Math.max(0, Math.min(0xFFFFFF, numeric))
            .toString(16).padStart(6, "0")
    }

    function highlight(hlId): var {
        const attrs = CodeWorkflowNvim.highlights[String(hlId ?? 0)] ?? ({})
        let foreground = root.rgbColor(
            attrs.foreground,
            root.rgbColor(
                CodeWorkflowNvim.defaultColors.foreground,
                Appearance.colors.colOnLayer1))
        let background = root.rgbColor(
            attrs.background,
            root.rgbColor(
                CodeWorkflowNvim.defaultColors.background,
                Appearance.colors.colLayer0))
        if (attrs.reverse === true) {
            const swap = foreground
            foreground = background
            background = swap
        }
        return {
            foreground: foreground,
            background: background,
            special: root.rgbColor(
                attrs.special,
                root.rgbColor(
                    CodeWorkflowNvim.defaultColors.special,
                    foreground)),
            bold: attrs.bold === true,
            italic: attrs.italic === true,
            underline: attrs.underline === true
                || attrs.undercurl === true
                || attrs.underdouble === true
                || attrs.underdotted === true
                || attrs.underdashed === true,
            strikethrough: attrs.strikethrough === true
        }
    }

    function escapeInputText(text: string): string {
        return String(text ?? "").replace(/</g, "<lt>")
    }

    function eventKeyName(key: int): string {
        switch (key) {
        case Qt.Key_Escape: return "Esc"
        case Qt.Key_Return:
        case Qt.Key_Enter: return "CR"
        case Qt.Key_Backspace: return "BS"
        case Qt.Key_Tab: return "Tab"
        case Qt.Key_Backtab: return "Tab"
        case Qt.Key_Delete: return "Del"
        case Qt.Key_Insert: return "Insert"
        case Qt.Key_Left: return "Left"
        case Qt.Key_Right: return "Right"
        case Qt.Key_Up: return "Up"
        case Qt.Key_Down: return "Down"
        case Qt.Key_Home: return "Home"
        case Qt.Key_End: return "End"
        case Qt.Key_PageUp: return "PageUp"
        case Qt.Key_PageDown: return "PageDown"
        case Qt.Key_Space: return "Space"
        case Qt.Key_F1: return "F1"
        case Qt.Key_F2: return "F2"
        case Qt.Key_F3: return "F3"
        case Qt.Key_F4: return "F4"
        case Qt.Key_F5: return "F5"
        case Qt.Key_F6: return "F6"
        case Qt.Key_F7: return "F7"
        case Qt.Key_F8: return "F8"
        case Qt.Key_F9: return "F9"
        case Qt.Key_F10: return "F10"
        case Qt.Key_F11: return "F11"
        case Qt.Key_F12: return "F12"
        default: return ""
        }
    }

    function eventKeyToken(event): string {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const meta = (event.modifiers & Qt.MetaModifier) !== 0
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0
            || event.key === Qt.Key_Backtab
        const special = root.eventKeyName(event.key)

        if (special.length > 0) {
            const mods = []
            if (ctrl) mods.push("C")
            if (alt) mods.push("M")
            if (meta) mods.push("D")
            if (shift && special !== "CR" && special !== "BS")
                mods.push("S")
            return mods.length > 0
                ? "<" + mods.join("-") + "-" + special + ">"
                : "<" + special + ">"
        }

        const text = String(event.text ?? "")
        if (!ctrl && !alt && !meta && text.length > 0)
            return root.escapeInputText(text)

        let base = ""
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            base = String.fromCharCode(
                "a".charCodeAt(0) + event.key - Qt.Key_A)
        else if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            base = String.fromCharCode(
                "0".charCodeAt(0) + event.key - Qt.Key_0)
        else if (text.length > 0)
            base = text.toLowerCase()

        if (base.length === 0)
            return ""

        const mods = []
        if (ctrl) mods.push("C")
        if (alt) mods.push("M")
        if (meta) mods.push("D")
        if (shift) mods.push("S")
        return mods.length > 0
            ? "<" + mods.join("-") + "-" + base + ">"
            : root.escapeInputText(base)
    }

    function mouseButtonName(button: int): string {
        if (button === Qt.RightButton)
            return "right"
        if (button === Qt.MiddleButton)
            return "middle"
        return "left"
    }

    function mouseModifier(modifiers: int): string {
        const parts = []
        if ((modifiers & Qt.ControlModifier) !== 0)
            parts.push("C")
        if ((modifiers & Qt.AltModifier) !== 0)
            parts.push("A")
        if ((modifiers & Qt.ShiftModifier) !== 0)
            parts.push("S")
        if ((modifiers & Qt.MetaModifier) !== 0)
            parts.push("D")
        return parts.length > 0 ? parts.join("-") + "-" : ""
    }

    function mouseCell(x: real, y: real): var {
        return {
            row: Math.max(0, Math.min(
                CodeWorkflowNvim.rows - 1,
                Math.floor(y / Math.max(1, root.cellHeight)))),
            col: Math.max(0, Math.min(
                CodeWorkflowNvim.cols - 1,
                Math.floor(x / Math.max(1, root.cellWidth))))
        }
    }

    function handleKeyEvent(event): bool {
        if (!root.active || !CodeWorkflowNvim.ready)
            return false

        // While the platform IME owns a composition, do not steal its
        // Backspace/arrows/etc. Qt will commit the final text through
        // TextInput.textEdited below.
        if (nvimImeProxy.inputMethodComposing)
            return false

        const ctrl =
            (event.modifiers & Qt.ControlModifier) !== 0
        const shift =
            (event.modifiers & Qt.ShiftModifier) !== 0
        const alt =
            (event.modifiers & Qt.AltModifier) !== 0
        const meta =
            (event.modifiers & Qt.MetaModifier) !== 0
        const clipboardPaste =
            (ctrl && shift && event.key === Qt.Key_V)
            || (shift && event.key === Qt.Key_Insert)
        if (clipboardPaste) {
            root.requestClipboardPaste()
            return true
        }

        // Printable text without Ctrl/Alt/Meta must flow through TextInput so
        // dead keys and composed input reach Qt's input-method pipeline.
        if (!ctrl && !alt && !meta
                && String(event.text ?? "").length > 0
                && event.key !== Qt.Key_Return
                && event.key !== Qt.Key_Enter
                && event.key !== Qt.Key_Tab
                && event.key !== Qt.Key_Backtab)
            return false

        const token = root.eventKeyToken(event)
        if (token.length === 0)
            return false
        return CodeWorkflowNvim.input(token)
    }

    function requestClipboardPaste(): void {
        if (!root.active || !CodeWorkflowNvim.ready
                || clipboardPasteProcess.running)
            return
        clipboardPasteProcess.running = true
    }

    function markRowDirty(row: int): void {
        if (!editorCanvas.available || editorCanvas.width <= 0
                || editorCanvas.height <= 0)
            return
        const safeRow = Math.max(
            0, Math.min(CodeWorkflowNvim.rows - 1, Number(row ?? 0)))
        editorCanvas.markDirty(Qt.rect(
            0,
            safeRow * root.cellHeight,
            editorCanvas.width,
            root.cellHeight))
    }

    function markCursorRowsDirty(): void {
        root.markRowDirty(root.lastPaintCursorRow)
        root.markRowDirty(CodeWorkflowNvim.cursorRow)
        root.lastPaintCursorRow = CodeWorkflowNvim.cursorRow
    }

    function markFrameDirty(): void {
        if (!editorCanvas.available)
            return
        if (CodeWorkflowNvim.fullRepaintRequested) {
            editorCanvas.requestPaint()
            return
        }
        for (const row of (CodeWorkflowNvim.lastDirtyRows ?? []))
            root.markRowDirty(Number(row))
    }

    function resetCursorBlink(): void {
        cursorBlinkTimer.stop()
        root.cursorBlinkVisible = true
        root.cursorBlinkPhase = "steady"

        if (!root.active || !CodeWorkflowNvim.ready
                || !CodeWorkflowNvim.cursorVisible) {
            root.markCursorRowsDirty()
            return
        }

        const style = CodeWorkflowNvim.cursorStyle ?? ({})
        const blinkWait = Math.max(
            0, Number(style.blinkwait ?? 0))
        const blinkOn = Math.max(
            0, Number(style.blinkon ?? 0))
        const blinkOff = Math.max(
            0, Number(style.blinkoff ?? 0))

        if (blinkOn <= 0 || blinkOff <= 0) {
            root.markCursorRowsDirty()
            return
        }

        root.cursorBlinkPhase = blinkWait > 0 ? "wait" : "on"
        cursorBlinkTimer.interval = Math.max(
            1, blinkWait > 0 ? blinkWait : blinkOn)
        cursorBlinkTimer.restart()
        root.markCursorRowsDirty()
    }

    function updateNvimSize(): void {
        if (!root.active || root.width <= 0 || root.height <= 0)
            return
        if (!CodeWorkflowNvim.running) {
            CodeWorkflowNvim.start(
                root.sourcePath, root.requestedCols, root.requestedRows)
            return
        }
        CodeWorkflowNvim.resize(root.requestedCols, root.requestedRows)
    }

    function ensureSession(): void {
        if (!root.active || root.sourcePath.length === 0)
            return
        CodeWorkflowNvim.start(
            root.sourcePath, root.requestedCols, root.requestedRows)
        Qt.callLater(() => nvimImeProxy.forceActiveFocus())
    }

    function forceEditorFocus(): void {
        nvimImeProxy.forceActiveFocus()
    }

    function saveBuffer(): bool {
        return CodeWorkflowNvim.save()
    }

    onActiveChanged: {
        if (active)
            Qt.callLater(root.ensureSession)
    }
    onSourcePathChanged: {
        if (active && sourcePath.length > 0)
            Qt.callLater(root.ensureSession)
    }
    onWidthChanged: resizeDebounce.restart()
    onHeightChanged: resizeDebounce.restart()
    Component.onCompleted: {
        if (active)
            Qt.callLater(root.ensureSession)
    }

    TextMetrics {
        id: cellMetrics
        text: "M"
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
    }

    FontMetrics {
        id: fontMetrics
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
    }

    Timer {
        id: resizeDebounce
        interval: 80
        repeat: false
        onTriggered: root.updateNvimSize()
    }

    Timer {
        id: cursorBlinkTimer
        repeat: false
        onTriggered: {
            const style = CodeWorkflowNvim.cursorStyle ?? ({})
            const blinkOn = Math.max(
                1, Number(style.blinkon ?? 500))
            const blinkOff = Math.max(
                1, Number(style.blinkoff ?? 500))

            if (root.cursorBlinkPhase === "wait") {
                root.cursorBlinkVisible = false
                root.cursorBlinkPhase = "off"
                interval = blinkOff
            } else if (root.cursorBlinkPhase === "off") {
                root.cursorBlinkVisible = true
                root.cursorBlinkPhase = "on"
                interval = blinkOn
            } else {
                root.cursorBlinkVisible = false
                root.cursorBlinkPhase = "off"
                interval = blinkOff
            }
            root.markCursorRowsDirty()
            restart()
        }
    }

    Process {
        id: clipboardPasteProcess
        command: ["wl-paste", "-n"]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                const text = String(data ?? "")
                if (text.length > 0)
                    CodeWorkflowNvim.paste(text)
            }
        }
    }

    Connections {
        target: CodeWorkflowNvim

        function onRevisionChanged(): void {
            root.markFrameDirty()
        }

        function onStateChanged(): void {
            root.resetCursorBlink()
            editorCanvas.requestPaint()
            if (root.active && CodeWorkflowNvim.ready)
                Qt.callLater(() => nvimImeProxy.forceActiveFocus())
        }

        function onCursorRowChanged(): void {
            root.resetCursorBlink()
        }

        function onCursorColChanged(): void {
            root.resetCursorBlink()
        }

        function onModeChanged(): void {
            root.resetCursorBlink()
        }

        function onCursorStyleChanged(): void {
            root.resetCursorBlink()
        }

        function onCursorVisibleChanged(): void {
            root.resetCursorBlink()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.rgbColor(
            CodeWorkflowNvim.defaultColors.background,
            Appearance.colors.colLayer0)
        clip: true

        Item {
            id: editorSurface
            anchors.fill: parent
            activeFocusOnTab: true
            focus: root.active
            Accessible.name: "Embedded Neovim source editor"
            Accessible.description:
                "Neovim UI embedded in the Code Workflow source pane"

            TextInput {
                id: nvimImeProxy
                x: Math.max(
                    0, Math.min(
                        editorSurface.width - width,
                        CodeWorkflowNvim.cursorCol * root.cellWidth))
                y: Math.max(
                    0, Math.min(
                        editorSurface.height - height,
                        CodeWorkflowNvim.cursorRow * root.cellHeight))
                width: Math.max(1, root.cellWidth)
                height: Math.max(1, root.cellHeight)
                opacity: 0
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                activeFocusOnTab: true
                inputMethodHints: Qt.ImhNone
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small

                onTextEdited: {
                    const committed = String(text ?? "")
                    if (committed.length === 0)
                        return
                    CodeWorkflowNvim.input(
                        root.escapeInputText(committed))
                    clear()
                }

                Keys.onPressed: event => {
                    if (root.handleKeyEvent(event))
                        event.accepted = true
                }
            }

            Rectangle {
                id: imePreeditBubble
                x: nvimImeProxy.x
                y: nvimImeProxy.y
                visible: nvimImeProxy.inputMethodComposing
                    && nvimImeProxy.preeditText.length > 0
                z: 4
                height: Math.max(root.cellHeight, preeditLabel.implicitHeight + 4)
                width: Math.max(root.cellWidth, preeditLabel.implicitWidth + 8)
                radius: Math.min(4, height / 3)
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colPrimary

                StyledText {
                    id: preeditLabel
                    anchors.centerIn: parent
                    text: nvimImeProxy.preeditText
                    color: Appearance.colors.colOnLayer2
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: CodeWorkflowNvim.mouseEnabled
                acceptedButtons:
                    Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onPressed: mouse => {
                    nvimImeProxy.forceActiveFocus()
                    if (!CodeWorkflowNvim.mouseEnabled)
                        return
                    const cell = root.mouseCell(mouse.x, mouse.y)
                    CodeWorkflowNvim.mouse(
                        root.mouseButtonName(mouse.button),
                        "press",
                        root.mouseModifier(mouse.modifiers),
                        cell.row, cell.col)
                    mouse.accepted = true
                }

                onReleased: mouse => {
                    if (!CodeWorkflowNvim.mouseEnabled)
                        return
                    const cell = root.mouseCell(mouse.x, mouse.y)
                    CodeWorkflowNvim.mouse(
                        root.mouseButtonName(mouse.button),
                        "release",
                        root.mouseModifier(mouse.modifiers),
                        cell.row, cell.col)
                    mouse.accepted = true
                }

                onPositionChanged: mouse => {
                    if (!CodeWorkflowNvim.mouseEnabled
                            || mouse.buttons === Qt.NoButton)
                        return
                    const cell = root.mouseCell(mouse.x, mouse.y)
                    const button = (mouse.buttons & Qt.LeftButton)
                        ? Qt.LeftButton
                        : (mouse.buttons & Qt.RightButton)
                            ? Qt.RightButton : Qt.MiddleButton
                    CodeWorkflowNvim.mouse(
                        root.mouseButtonName(button),
                        "drag",
                        root.mouseModifier(mouse.modifiers),
                        cell.row, cell.col)
                }

                onWheel: wheel => {
                    nvimImeProxy.forceActiveFocus()
                    if (!CodeWorkflowNvim.mouseEnabled)
                        return
                    const cell = root.mouseCell(wheel.x, wheel.y)
                    const action = wheel.angleDelta.y >= 0 ? "up" : "down"
                    CodeWorkflowNvim.mouse(
                        "wheel", action,
                        root.mouseModifier(wheel.modifiers),
                        cell.row, cell.col)
                    wheel.accepted = true
                }
            }

            Canvas {
                id: editorCanvas
                anchors.fill: parent
                antialiasing: false

                onPaint: region => {
                    const ctx = getContext("2d")
                    const widthPx = editorCanvas.width
                    const heightPx = editorCanvas.height
                    const dirty = region ?? Qt.rect(
                        0, 0, widthPx, heightPx)
                    const dirtyX = Math.max(0, dirty.x)
                    const dirtyY = Math.max(0, dirty.y)
                    const dirtyWidth = Math.max(
                        0, Math.min(widthPx - dirtyX, dirty.width))
                    const dirtyHeight = Math.max(
                        0, Math.min(heightPx - dirtyY, dirty.height))
                    const defaultBackground = root.rgbColor(
                        CodeWorkflowNvim.defaultColors.background,
                        Appearance.colors.colLayer0)
                    const defaultForeground = root.rgbColor(
                        CodeWorkflowNvim.defaultColors.foreground,
                        Appearance.colors.colOnLayer1)

                    ctx.clearRect(
                        dirtyX, dirtyY, dirtyWidth, dirtyHeight)
                    ctx.fillStyle = defaultBackground
                    ctx.fillRect(
                        dirtyX, dirtyY, dirtyWidth, dirtyHeight)
                    ctx.textBaseline = "alphabetic"

                    const rows = CodeWorkflowNvim.gridRows
                    const maxRows = Math.min(
                        rows.length,
                        Math.ceil(heightPx / root.cellHeight))
                    const firstRow = Math.max(
                        0, Math.floor(dirtyY / root.cellHeight))
                    const lastRow = Math.min(
                        maxRows,
                        Math.ceil(
                            (dirtyY + dirtyHeight)
                                / root.cellHeight))

                    for (let row = firstRow; row < lastRow; ++row) {
                        const cells = rows[row] ?? []
                        const maxCols = Math.min(
                            cells.length,
                            Math.ceil(widthPx / root.cellWidth))
                        for (let col = 0; col < maxCols; ++col) {
                            const cell = cells[col] ?? [" ", 0]
                            const text = String(cell[0] ?? " ")
                            const style = root.highlight(cell[1] ?? 0)
                            const x = col * root.cellWidth
                            const y = row * root.cellHeight

                            if (String(style.background)
                                    !== String(defaultBackground)) {
                                ctx.fillStyle = style.background
                                ctx.fillRect(
                                    x, y, root.cellWidth, root.cellHeight)
                            }

                            if (text.length > 0 && text !== " ") {
                                const fontBits = []
                                if (style.italic)
                                    fontBits.push("italic")
                                if (style.bold)
                                    fontBits.push("bold")
                                fontBits.push(
                                    String(Appearance.font.pixelSize.small)
                                        + "px")
                                fontBits.push(
                                    "\"" + Appearance.font.family.monospace
                                        + "\"")
                                ctx.font = fontBits.join(" ")
                                ctx.fillStyle = style.foreground
                                ctx.fillText(
                                    text, x,
                                    y + Math.min(
                                        root.cellHeight - 1,
                                        fontMetrics.ascent))

                                if (style.underline) {
                                    ctx.fillStyle = style.special
                                    ctx.fillRect(
                                        x,
                                        y + root.cellHeight - 1,
                                        root.cellWidth, 1)
                                }
                                if (style.strikethrough) {
                                    ctx.fillStyle = style.foreground
                                    ctx.fillRect(
                                        x,
                                        y + Math.floor(root.cellHeight / 2),
                                        root.cellWidth, 1)
                                }
                            }
                        }
                    }

                    if (CodeWorkflowNvim.ready
                            && CodeWorkflowNvim.cursorVisible
                            && root.cursorBlinkVisible
                            && CodeWorkflowNvim.cursorRow >= firstRow
                            && CodeWorkflowNvim.cursorRow < lastRow
                            && CodeWorkflowNvim.cursorCol >= 0) {
                        const cursorX =
                            CodeWorkflowNvim.cursorCol * root.cellWidth
                        const cursorY =
                            CodeWorkflowNvim.cursorRow * root.cellHeight
                        const cursorStyle =
                            CodeWorkflowNvim.cursorStyle ?? ({})
                        const cursorShape = String(
                            cursorStyle.cursor_shape
                                ?? (CodeWorkflowNvim.mode.startsWith("insert")
                                    ? "vertical" : "block"))
                        const percentage = Math.max(
                            1, Math.min(
                                100,
                                Number(cursorStyle.cell_percentage ?? 100)))
                        ctx.fillStyle = Appearance.colors.colPrimary

                        if (cursorShape === "vertical") {
                            ctx.fillRect(
                                cursorX, cursorY,
                                Math.max(
                                    2,
                                    root.cellWidth * percentage / 100),
                                root.cellHeight)
                        } else if (cursorShape === "horizontal") {
                            const cursorHeight = Math.max(
                                2,
                                root.cellHeight * percentage / 100)
                            ctx.fillRect(
                                cursorX,
                                cursorY + root.cellHeight - cursorHeight,
                                root.cellWidth, cursorHeight)
                        } else {
                            ctx.globalAlpha = 0.72
                            ctx.fillRect(
                                cursorX, cursorY,
                                root.cellWidth, root.cellHeight)
                            ctx.globalAlpha = 1.0
                        }
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                visible: CodeWorkflowNvim.ready
                    && CodeWorkflowNvim.error.length > 0
                z: 6
                width: Math.min(
                    Math.max(220, readyErrorText.implicitWidth + 24),
                    Math.max(220, parent.width - 16))
                height: readyErrorText.implicitHeight + 14
                radius: Appearance.rounding.small
                color: Appearance.colors.colErrorContainer
                border.width: 1
                border.color: Appearance.colors.colError

                StyledText {
                    id: readyErrorText
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: CodeWorkflowNvim.error
                    color: Appearance.colors.colOnErrorContainer
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !CodeWorkflowNvim.ready
                width: Math.min(parent.width - 24, statusColumn.implicitWidth + 28)
                height: statusColumn.implicitHeight + 22
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                Column {
                    id: statusColumn
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: CodeWorkflowNvim.state === "starting"
                            ? "Starting Neovim…"
                            : CodeWorkflowNvim.state === "unavailable"
                                ? "Neovim unavailable"
                                : CodeWorkflowNvim.state.toUpperCase()
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: CodeWorkflowNvim.error.length > 0
                        width: Math.min(
                            360, Math.max(180, implicitWidth))
                        text: CodeWorkflowNvim.error
                        color: Appearance.colors.colError
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
