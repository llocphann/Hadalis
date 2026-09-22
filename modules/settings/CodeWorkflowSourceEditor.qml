import QtQuick
import qs.modules.common

Item {
    id: root

    property string draft: ""
    property string definitionName: "plaintext"
    property string mode: "normal"
    property string yankBuffer: ""
    property int visualAnchor: -1
    property int visualCursor: -1
    property bool syncingFromHost: false
    property string documentText: root.draft

    signal draftEdited(string text)
    signal saveRequested()
    signal statusMessage(string message)

    readonly property int lineCount:
        Math.max(1, root.documentText.split("\n").length)
    readonly property int gutterWidth:
        20 + Math.max(2, String(root.lineCount).length) * 8
    readonly property string lineNumberText: {
        const result = []
        for (let line = 1; line <= root.lineCount; line++)
            result.push(String(line))
        return result.join("\n")
    }

    function clampPosition(position: int): int {
        return Math.max(0, Math.min(root.documentText.length, position))
    }

    function lineStart(position: int): int {
        const pos = root.clampPosition(position)
        if (pos <= 0)
            return 0
        const newline = root.documentText.lastIndexOf("\n", pos - 1)
        return newline < 0 ? 0 : newline + 1
    }

    function lineEnd(position: int): int {
        const pos = root.clampPosition(position)
        const newline = root.documentText.indexOf("\n", pos)
        return newline < 0 ? root.documentText.length : newline
    }

    function targetLinePosition(position: int, direction: int): int {
        const pos = root.clampPosition(position)
        const start = root.lineStart(pos)
        const column = pos - start
        if (direction < 0) {
            if (start === 0)
                return pos
            const previousEnd = start - 1
            const previousStart = root.lineStart(Math.max(0, previousEnd - 1))
            return Math.min(previousStart + column, previousEnd)
        }

        const end = root.lineEnd(pos)
        if (end >= root.documentText.length)
            return pos
        const nextStart = end + 1
        const nextEnd = root.lineEnd(nextStart)
        return Math.min(nextStart + column, nextEnd)
    }

    function setCursor(position: int): void {
        const pos = root.clampPosition(position)
        if (root.mode === "visual") {
            root.visualCursor = pos
            root.applyVisualSelection()
            return
        }
        editor.cursorPosition = pos
        editor.deselect()
    }

    function moveHorizontal(delta: int): void {
        const current = root.mode === "visual"
            ? root.visualCursor : editor.cursorPosition
        const start = root.lineStart(current)
        const end = root.lineEnd(current)
        root.setCursor(Math.max(start, Math.min(end, current + delta)))
    }

    function moveVertical(delta: int): void {
        const current = root.mode === "visual"
            ? root.visualCursor : editor.cursorPosition
        root.setCursor(root.targetLinePosition(current, delta))
    }

    function applyVisualSelection(): void {
        if (root.visualAnchor < 0 || root.visualCursor < 0)
            return
        const anchor = root.clampPosition(root.visualAnchor)
        const cursor = root.clampPosition(root.visualCursor)
        if (cursor >= anchor)
            editor.select(anchor, Math.min(root.documentText.length, cursor + 1))
        else
            editor.select(cursor, Math.min(root.documentText.length, anchor + 1))
    }

    function setMode(nextMode: string): void {
        const requested = ["normal", "insert", "visual"].includes(nextMode)
            ? nextMode : "normal"
        if (requested === "visual") {
            const cursor = root.clampPosition(editor.cursorPosition)
            root.mode = "visual"
            root.visualAnchor = cursor
            root.visualCursor = cursor
            root.applyVisualSelection()
        } else {
            const restoreCursor = root.mode === "visual"
                && root.visualCursor >= 0
                ? root.clampPosition(root.visualCursor)
                : root.clampPosition(editor.cursorPosition)
            root.mode = requested
            root.visualAnchor = -1
            root.visualCursor = -1
            editor.deselect()
            editor.cursorPosition = restoreCursor
        }
        editor.forceActiveFocus()
    }

    function replaceRange(start: int, end: int, replacement: string): void {
        const safeStart = root.clampPosition(Math.min(start, end))
        const safeEnd = root.clampPosition(Math.max(start, end))
        root.documentText = root.documentText.slice(0, safeStart)
            + replacement + root.documentText.slice(safeEnd)
        const nextCursor = safeStart + replacement.length
        Qt.callLater(() => {
            editor.cursorPosition = root.clampPosition(nextCursor)
            if (root.mode === "visual") {
                root.visualCursor = editor.cursorPosition
                root.applyVisualSelection()
            }
        })
    }

    function enterInsertAt(position: int): void {
        root.setMode("normal")
        editor.cursorPosition = root.clampPosition(position)
        root.setMode("insert")
    }

    function yankSelection(): bool {
        if (editor.selectionStart === editor.selectionEnd)
            return false
        root.yankBuffer = editor.selectedText
        editor.copy()
        const cursor = Math.min(editor.selectionStart, editor.selectionEnd)
        root.setMode("normal")
        editor.cursorPosition = root.clampPosition(cursor)
        return true
    }

    function deleteSelection(enterInsert: bool): bool {
        if (editor.selectionStart === editor.selectionEnd)
            return false
        const start = Math.min(editor.selectionStart, editor.selectionEnd)
        const end = Math.max(editor.selectionStart, editor.selectionEnd)
        root.yankBuffer = editor.selectedText
        editor.copy()
        root.setMode("normal")
        root.replaceRange(start, end, "")
        Qt.callLater(() => {
            editor.cursorPosition = root.clampPosition(start)
            if (enterInsert)
                root.setMode("insert")
        })
        return true
    }

    function yankCurrentLine(): void {
        const start = root.lineStart(editor.cursorPosition)
        const end = root.lineEnd(editor.cursorPosition)
        root.yankBuffer = root.documentText.slice(
            start, Math.min(root.documentText.length, end + 1))
        editor.select(start, Math.min(root.documentText.length, end + 1))
        editor.copy()
        editor.deselect()
        editor.cursorPosition = start
    }

    function pasteYank(afterCursor: bool): void {
        if (root.yankBuffer.length === 0)
            return
        const cursor = root.clampPosition(editor.cursorPosition)
        const insertAt = afterCursor
            ? Math.min(root.documentText.length, cursor + 1)
            : cursor
        root.replaceRange(insertAt, insertAt, root.yankBuffer)
        Qt.callLater(() => {
            editor.cursorPosition = root.clampPosition(
                insertAt + Math.max(0, root.yankBuffer.length - 1))
        })
    }

    function revealSelection(start: int, end: int): void {
        const safeStart = root.clampPosition(start)
        const safeEnd = root.clampPosition(end)
        root.setMode("normal")
        editor.select(safeStart, safeEnd)
        Qt.callLater(() => {
            const rect = editor.positionToRectangle(safeStart)
            const margin = 18
            editorFlick.contentX = Math.max(
                0, Math.min(
                    Math.max(0, editorFlick.contentWidth - editorFlick.width),
                    rect.x + root.gutterWidth - margin))
            editorFlick.contentY = Math.max(
                0, Math.min(
                    Math.max(0, editorFlick.contentHeight - editorFlick.height),
                    rect.y - editorFlick.height / 3))
        })
    }

    function clearSelection(): void {
        editor.deselect()
    }

    function focusEditor(): void {
        editor.forceActiveFocus()
    }

    onDraftChanged: {
        if (root.documentText === root.draft)
            return
        root.syncingFromHost = true
        root.documentText = root.draft
        root.syncingFromHost = false
    }

    onDocumentTextChanged: {
        if (!root.syncingFromHost && root.documentText !== root.draft)
            root.draftEdited(root.documentText)
    }

    Flickable {
        id: editorFlick
        anchors.fill: parent
        contentWidth: Math.max(width, editorRow.width)
        contentHeight: Math.max(height, editorRow.height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: editorRow
            spacing: 8
            width: Math.max(
                editorFlick.width,
                root.gutterWidth + spacing + editor.implicitWidth)
            height: Math.max(editorFlick.height, editor.implicitHeight)

            Rectangle {
                width: root.gutterWidth
                height: parent.height
                color: Appearance.colors.colLayer1

                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 6
                    text: root.lineNumberText
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignRight
                    renderType: Text.QtRendering
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            TextEdit {
                id: editor
                width: Math.max(
                    editorFlick.width - root.gutterWidth - editorRow.spacing,
                    implicitWidth)
                height: Math.max(editorFlick.height, implicitHeight)
                text: root.documentText
                readOnly: root.mode !== "insert"
                selectByMouse: true
                activeFocusOnTab: true
                Accessible.name: "Source editor"
                Accessible.description:
                    "Hot-fix source editor. Escape returns to normal mode; i enters insert; v enters visual; hjkl moves."
                onTextChanged: {
                    if (root.documentText !== text)
                        root.documentText = text
                }
                Keys.onPressed: event => {
                    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                    const shift = (event.modifiers & Qt.ShiftModifier) !== 0

                    if (event.key === Qt.Key_S && ctrl) {
                        root.saveRequested()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        root.setMode("normal")
                        event.accepted = true
                        return
                    }

                    if (root.mode === "insert") {
                        // Preserve native TextEdit editing, clipboard and IME.
                        event.accepted = false
                        return
                    }

                    if (ctrl && event.key === Qt.Key_V) {
                        const returnMode = root.mode
                        root.setMode("insert")
                        Qt.callLater(() => {
                            editor.paste()
                            root.setMode(returnMode === "visual"
                                ? "normal" : returnMode)
                        })
                        event.accepted = true
                        return
                    }

                    if (root.mode === "visual") {
                        if (event.key === Qt.Key_H) root.moveHorizontal(-1)
                        else if (event.key === Qt.Key_L) root.moveHorizontal(1)
                        else if (event.key === Qt.Key_J) root.moveVertical(1)
                        else if (event.key === Qt.Key_K) root.moveVertical(-1)
                        else if (event.key === Qt.Key_Y
                                || (ctrl && event.key === Qt.Key_C))
                            root.yankSelection()
                        else if (event.key === Qt.Key_D
                                || event.key === Qt.Key_X)
                            root.deleteSelection(false)
                        else if (event.key === Qt.Key_C)
                            root.deleteSelection(true)
                        else if (event.key === Qt.Key_P) {
                            const start = Math.min(
                                editor.selectionStart, editor.selectionEnd)
                            const end = Math.max(
                                editor.selectionStart, editor.selectionEnd)
                            const replacement = root.yankBuffer
                            root.setMode("normal")
                            root.replaceRange(start, end, replacement)
                        } else {
                            event.accepted = false
                            return
                        }
                        event.accepted = true
                        return
                    }

                    const cursor = editor.cursorPosition
                    if (event.key === Qt.Key_H)
                        root.moveHorizontal(-1)
                    else if (event.key === Qt.Key_L)
                        root.moveHorizontal(1)
                    else if (event.key === Qt.Key_J)
                        root.moveVertical(1)
                    else if (event.key === Qt.Key_K)
                        root.moveVertical(-1)
                    else if (event.key === Qt.Key_0)
                        root.setCursor(root.lineStart(cursor))
                    else if (event.key === Qt.Key_Dollar)
                        root.setCursor(root.lineEnd(cursor))
                    else if (event.key === Qt.Key_I) {
                        const at = shift
                            ? root.lineStart(cursor) : cursor
                        root.enterInsertAt(at)
                    } else if (event.key === Qt.Key_A) {
                        const at = shift
                            ? root.lineEnd(cursor)
                            : Math.min(root.documentText.length, cursor + 1)
                        root.enterInsertAt(at)
                    } else if (event.key === Qt.Key_O) {
                        const start = root.lineStart(cursor)
                        const end = root.lineEnd(cursor)
                        const at = shift ? start : end
                        root.replaceRange(at, at, "\n")
                        root.enterInsertAt(shift ? at : at + 1)
                    } else if (event.key === Qt.Key_V) {
                        root.setMode("visual")
                    } else if (event.key === Qt.Key_X) {
                        if (cursor < root.documentText.length) {
                            root.yankBuffer =
                                root.documentText.slice(cursor, cursor + 1)
                            root.replaceRange(cursor, cursor + 1, "")
                        }
                    } else if (event.key === Qt.Key_Y) {
                        root.yankCurrentLine()
                    } else if (event.key === Qt.Key_P) {
                        root.pasteYank(!shift)
                    } else {
                        event.accepted = false
                        return
                    }
                    event.accepted = true
                }
                wrapMode: TextEdit.NoWrap
                renderType: Text.QtRendering
                color: Appearance.colors.colOnLayer1
                selectionColor: Appearance.colors.colPrimaryContainer
                selectedTextColor: Appearance.colors.colOnPrimaryContainer
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        Loader {
            id: syntaxLoader
            active: true
            source: "CodeWorkflowSyntaxHighlighter.qml"
            asynchronous: true
            visible: false

            onLoaded: {
                item.targetTextEdit = editor
                item.definitionName = root.definitionName
            }
            onStatusChanged: {
                if (status === Loader.Error)
                    root.statusMessage(
                        "Syntax highlighting unavailable · plain editor active")
            }
        }
    }

    onDefinitionNameChanged: {
        if (syntaxLoader.item)
            syntaxLoader.item.definitionName = root.definitionName
    }
}
