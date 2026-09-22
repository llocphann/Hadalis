import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

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
    property bool findVisible: false
    property bool replaceVisible: false
    property string findText: ""
    property string replaceText: ""
    property bool findCaseSensitive: false
    property int activeFindStart: -1
    property int activeFindEnd: -1
    // Visual selection moves TextEdit's native caret to the selection end.
    // Track the actual modal cursor even when selection direction reverses.
    readonly property int modalCursorPosition: root.mode === "visual"
        && root.visualCursor >= 0
        ? root.clampPosition(root.visualCursor) : editor.cursorPosition
    readonly property rect modalCursorRect: {
        void(root.documentText)
        void(editor.width)
        void(editor.font.pixelSize)
        return editor.positionToRectangle(root.modalCursorPosition)
    }

    signal draftEdited(string text)
    signal saveRequested()
    signal statusMessage(string message)

    // Escape belongs to the entire editor surface, including Find toolbar
    // buttons. Do not let the Settings overlay's window-wide Shortcut close
    // Settings while a child of the editor still has keyboard focus.
    Keys.onShortcutOverride: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Escape
                || (ctrl && (event.key === Qt.Key_F
                    || event.key === Qt.Key_H)))
            event.accepted = true
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.findVisible)
                root.closeFind()
            else {
                root.setMode("normal")
                editor.forceActiveFocus()
            }
            event.accepted = true
        }
    }

    readonly property int lineCount:
        Math.max(1, root.documentText.split("\n").length)
    readonly property int currentLineNumber:
        root.lineNumberAt(editor.cursorPosition)
    readonly property int gutterWidth:
        20 + Math.max(2, String(root.lineCount).length) * 8
    readonly property string lineNumberText: {
        const result = []
        for (let line = 1; line <= root.lineCount; line++) {
            result.push(line === root.currentLineNumber
                ? String(line)
                : String(Math.abs(line - root.currentLineNumber)))
        }
        return result.join("\n")
    }
    readonly property var findMatches: root.computeFindMatches()
    readonly property int activeFindIndex: {
        for (let i = 0; i < root.findMatches.length; i++) {
            if (root.findMatches[i].start === root.activeFindStart)
                return i
        }
        return -1
    }

    function clampPosition(position: int): int {
        return Math.max(0, Math.min(root.documentText.length, position))
    }

    function lineNumberAt(position: int): int {
        const pos = root.clampPosition(position)
        if (pos <= 0)
            return 1
        return root.documentText.slice(0, pos).split("\n").length
    }

    function computeFindMatches() {
        const rawNeedle = root.findText
        if (rawNeedle.length === 0)
            return []

        // Search the original UTF-16 document: Unicode case conversion can
        // alter string length, making offsets from a folded copy incorrect.
        const escaped = rawNeedle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        const expression = new RegExp(escaped,
            root.findCaseSensitive ? "gu" : "giu")
        const matches = []
        let match
        while ((match = expression.exec(root.documentText)) !== null) {
            matches.push({
                start: match.index,
                end: match.index + match[0].length
            })
        }
        return matches
    }

    function clearFindSelection(): void {
        root.activeFindStart = -1
        root.activeFindEnd = -1
        if (root.mode !== "visual")
            editor.deselect()
    }

    function revealFindMatch(start: int, end: int): void {
        root.activeFindStart = root.clampPosition(start)
        root.activeFindEnd = root.clampPosition(end)
        editor.select(root.activeFindStart, root.activeFindEnd)
        Qt.callLater(() => {
            const rect = editor.positionToRectangle(root.activeFindStart)
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

    function findNext(backward: bool, fromStart: bool): bool {
        const matches = root.findMatches
        if (matches.length === 0) {
            root.clearFindSelection()
            return false
        }

        let index = -1
        if (fromStart) {
            index = backward ? matches.length - 1 : 0
        } else if (root.activeFindIndex >= 0) {
            index = (root.activeFindIndex
                + (backward ? -1 : 1) + matches.length) % matches.length
        } else {
            const cursor = editor.cursorPosition
            if (backward) {
                for (let i = matches.length - 1; i >= 0; i--) {
                    if (matches[i].start < cursor) {
                        index = i
                        break
                    }
                }
                if (index < 0)
                    index = matches.length - 1
            } else {
                for (let i = 0; i < matches.length; i++) {
                    if (matches[i].start >= cursor) {
                        index = i
                        break
                    }
                }
                if (index < 0)
                    index = 0
            }
        }

        root.revealFindMatch(matches[index].start, matches[index].end)
        return true
    }

    function openFind(withReplace: bool): void {
        if (root.mode === "visual")
            root.setMode("normal")
        root.findVisible = true
        root.replaceVisible = withReplace
        Qt.callLater(() => {
            if (!root.findVisible)
                return
            findField.forceActiveFocus()
            findField.selectAll()
            if (root.findText.length > 0)
                root.findNext(false, true)
        })
    }

    function closeFind(): void {
        root.findVisible = false
        root.replaceVisible = false
        root.clearFindSelection()
        editor.forceActiveFocus()
    }

    function replaceCurrentFind(): bool {
        if (root.mode !== "insert") {
            root.statusMessage("Enter INSERT mode before replacing source text")
            return false
        }
        if (root.activeFindIndex < 0 && !root.findNext(false, false))
            return false

        const start = root.activeFindStart
        const end = root.activeFindEnd
        root.replaceRange(start, end, root.replaceText)
        root.activeFindStart = -1
        root.activeFindEnd = -1
        Qt.callLater(() => {
            if (root.findVisible)
                root.findNext(false, false)
        })
        return true
    }

    function replaceAllFind(): int {
        if (root.mode !== "insert") {
            root.statusMessage("Enter INSERT mode before replacing source text")
            return 0
        }
        const matches = root.findMatches
        if (matches.length === 0)
            return 0

        let nextText = root.documentText
        for (let i = matches.length - 1; i >= 0; i--) {
            nextText = nextText.slice(0, matches[i].start)
                + root.replaceText + nextText.slice(matches[i].end)
        }
        root.documentText = nextText
        root.activeFindStart = -1
        root.activeFindEnd = -1
        root.statusMessage(String(matches.length) + " replacements applied")
        Qt.callLater(() => {
            if (root.findVisible)
                root.findNext(false, true)
        })
        return matches.length
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
        // Do not reuse a stale selection after an edit or a source refresh.
        if (root.activeFindStart >= 0
                && !root.findMatches.some(match =>
                    match.start === root.activeFindStart
                        && match.end === root.activeFindEnd)) {
            root.activeFindStart = -1
            root.activeFindEnd = -1
        }
        if (!root.syncingFromHost && root.documentText !== root.draft)
            root.draftEdited(root.documentText)
    }

    Rectangle {
        id: findPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.replaceVisible ? 70 : 36
        visible: root.findVisible
        z: 4
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        radius: Appearance.rounding.small

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 4

                ToolbarTextField {
                    id: findField
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 28
                    implicitHeight: 28
                    placeholderText: "Find"
                    text: root.findText
                    colBackground: Appearance.colors.colLayer0
                    Accessible.name: "Find in source"
                    onTextChanged: {
                        if (root.findText === text)
                            return
                        root.findText = text
                        root.activeFindStart = -1
                        root.activeFindEnd = -1
                        Qt.callLater(() => {
                            if (root.findVisible)
                                root.findNext(false, true)
                        })
                    }
                    Keys.onShortcutOverride: event => {
                        if (event.key === Qt.Key_Escape)
                            event.accepted = true
                    }
                    Keys.onPressed: event => {
                        const shift =
                            (event.modifiers & Qt.ShiftModifier) !== 0
                        if (event.key === Qt.Key_Escape) {
                            root.closeFind()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            root.findNext(shift, false)
                            event.accepted = true
                        }
                    }
                }

                StyledText {
                    text: root.findMatches.length === 0
                        ? "0/0"
                        : String(root.activeFindIndex + 1)
                            + "/" + String(root.findMatches.length)
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                RippleButtonWithIcon {
                    implicitWidth: 28
                    implicitHeight: 28
                    horizontalPadding: 4
                    materialIcon: "keyboard_arrow_up"
                    mainText: ""
                    buttonText: "Previous match"
                    enabled: root.findMatches.length > 0
                    onClicked: root.findNext(true, false)
                    StyledToolTip { text: "Previous match · Shift+Enter" }
                }
                RippleButtonWithIcon {
                    implicitWidth: 28
                    implicitHeight: 28
                    horizontalPadding: 4
                    materialIcon: "keyboard_arrow_down"
                    mainText: ""
                    buttonText: "Next match"
                    enabled: root.findMatches.length > 0
                    onClicked: root.findNext(false, false)
                    StyledToolTip { text: "Next match · Enter / n" }
                }
                RippleButtonWithIcon {
                    implicitWidth: 28
                    implicitHeight: 28
                    horizontalPadding: 4
                    materialIcon: "match_case"
                    mainText: ""
                    buttonText: "Match case"
                    toggled: root.findCaseSensitive
                    onClicked: {
                        root.findCaseSensitive = !root.findCaseSensitive
                        root.activeFindStart = -1
                        root.activeFindEnd = -1
                        root.findNext(false, true)
                    }
                    StyledToolTip {
                        text: root.findCaseSensitive
                            ? "Case sensitive" : "Case insensitive"
                    }
                }
                RippleButtonWithIcon {
                    id: replaceVisibilityButton
                    implicitWidth: 28
                    implicitHeight: 28
                    horizontalPadding: 4
                    materialIcon: root.replaceVisible
                        ? "find_replace" : "find_in_page"
                    mainText: ""
                    buttonText: root.replaceVisible
                        ? "Hide replace" : "Show replace"
                    onClicked: root.replaceVisible = !root.replaceVisible
                    StyledToolTip {
                        text: replaceVisibilityButton.buttonText
                    }
                }
                RippleButtonWithIcon {
                    implicitWidth: 28
                    implicitHeight: 28
                    horizontalPadding: 4
                    materialIcon: "close"
                    mainText: ""
                    buttonText: "Close find"
                    onClicked: root.closeFind()
                    StyledToolTip { text: "Close find · Esc" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: root.replaceVisible
                spacing: 4

                ToolbarTextField {
                    id: replaceField
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 28
                    implicitHeight: 28
                    placeholderText: root.mode === "insert"
                        ? "Replace with" : "Replace with · enter INSERT first"
                    text: root.replaceText
                    colBackground: Appearance.colors.colLayer0
                    Accessible.name: "Replace in source"
                    onTextChanged: root.replaceText = text
                    Keys.onShortcutOverride: event => {
                        if (event.key === Qt.Key_Escape)
                            event.accepted = true
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeFind()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return
                                || event.key === Qt.Key_Enter) {
                            root.replaceCurrentFind()
                            event.accepted = true
                        }
                    }
                }

                RippleButtonWithIcon {
                    implicitHeight: 28
                    horizontalPadding: 7
                    materialIcon: "find_replace"
                    mainText: "Replace"
                    buttonText: "Replace current match"
                    enabled: root.mode === "insert"
                        && root.findMatches.length > 0
                    onClicked: root.replaceCurrentFind()
                }
                RippleButtonWithIcon {
                    implicitHeight: 28
                    horizontalPadding: 7
                    materialIcon: "done_all"
                    mainText: "All"
                    buttonText: "Replace all matches"
                    enabled: root.mode === "insert"
                        && root.findMatches.length > 0
                    onClicked: root.replaceAllFind()
                }
            }
        }
    }

    Flickable {
        id: editorFlick
        anchors.top: root.findVisible ? findPanel.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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
                cursorVisible: activeFocus && root.mode === "insert"
                persistentSelection: true
                Accessible.name: "Source editor"
                Accessible.description:
                    "Hot-fix source editor. Click places the cursor in Normal view mode; i enters Insert; v enters Visual; slash or Ctrl+F finds text."

                HoverHandler {
                    cursorShape: root.mode === "insert"
                        ? Qt.IBeamCursor : Qt.ArrowCursor
                }

                TextMetrics {
                    id: modalCaretMetrics
                    font: editor.font
                    text: "M"
                }

                // Block cursor is independent of the TextEdit selection
                // and native INSERT caret; reversed Visual selection is valid.
                Rectangle {
                    id: modalCaret
                    visible: editor.activeFocus && root.mode !== "insert"
                        && !root.findVisible
                    x: root.modalCursorRect.x
                    y: root.modalCursorRect.y
                    width: Math.max(7, modalCaretMetrics.width)
                    height: Math.max(1, root.modalCursorRect.height)
                    color: Appearance.colors.colPrimary
                    opacity: root.mode === "visual" ? 0.48 : 0.66
                    border.width: 1
                    border.color: Appearance.colors.colOnLayer1
                    z: 5
                }

                TapHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton
                    onTapped: eventPoint => {
                        const position = editor.positionAt(
                            eventPoint.position.x, eventPoint.position.y)
                        root.setMode("normal")
                        editor.cursorPosition = root.clampPosition(position)
                        editor.deselect()
                        editor.forceActiveFocus()
                    }
                }

                Keys.onShortcutOverride: event => {
                    const ctrl =
                        (event.modifiers & Qt.ControlModifier) !== 0
                    if (event.key === Qt.Key_Escape
                            || (ctrl && (event.key === Qt.Key_F
                                || event.key === Qt.Key_H)))
                        event.accepted = true
                }

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
                    if (ctrl && event.key === Qt.Key_F) {
                        root.openFind(false)
                        event.accepted = true
                        return
                    }
                    if (ctrl && event.key === Qt.Key_H) {
                        root.openFind(true)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Escape) {
                        if (root.findVisible)
                            root.closeFind()
                        else
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
                    if (event.key === Qt.Key_Slash) {
                        root.openFind(false)
                    } else if (event.key === Qt.Key_N) {
                        root.findNext(shift, false)
                    } else if (event.key === Qt.Key_H)
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
                            : Math.min(root.lineEnd(cursor), cursor + 1)
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
