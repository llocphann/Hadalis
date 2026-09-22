#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDITOR = ROOT / "modules" / "settings" / "CodeWorkflowSourceEditor.qml"
PAGE = ROOT / "modules" / "settings" / "CodeWorkflow.qml"
SETTINGS_QMLDIR = ROOT / "modules" / "settings" / "qmldir"
SERVICES_QMLDIR = ROOT / "services" / "qmldir"

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        fail(message + " (" + token + ")")

editor = EDITOR.read_text(encoding="utf-8")
page = PAGE.read_text(encoding="utf-8")
settings_qmldir = SETTINGS_QMLDIR.read_text(encoding="utf-8")
services_qmldir = SERVICES_QMLDIR.read_text(encoding="utf-8")


for token in (
    'property string mode: "normal"',
    '["normal", "insert", "visual"].includes(nextMode)',
    'readOnly: root.mode !== "insert"',
    "event.key === Qt.Key_Escape",
    'root.setMode("visual")',
    'root.setMode("insert")',
    "root.yankSelection()",
    "root.deleteSelection(false)",
    "root.deleteSelection(true)",
    "root.yankCurrentLine()",
    "root.pasteYank(!shift)",
    "editor.copy()",
    "editor.paste()",
    "root.saveRequested()",
    "cursorVisible: activeFocus",
    "cursorShape: root.mode === \"insert\"",
    "id: modalCaret",
    'visible: editor.activeFocus && root.mode !== "insert"',
    "x: root.modalCursorRect.x",
    "y: root.modalCursorRect.y",
    "width: Math.max(7, modalCaretMetrics.width)",
    "editor.positionAt(",
    "Keys.onShortcutOverride: event =>",
):
    require(editor, token, "modal editing contract missing")

for token in (
    "readonly property int lineCount:",
    "readonly property int currentLineNumber:",
    "readonly property string lineNumberText:",
    "Math.abs(line - root.currentLineNumber)",
    "text: root.lineNumberText",
    "font.family: Appearance.font.family.monospace",
):
    require(editor, token, "line-number gutter contract missing")

for token in (
    "function lineStart(position: int): int",
    "function lineEnd(position: int): int",
    "function targetLinePosition(position: int, direction: int): int",
    "function moveHorizontal(delta: int): void",
    "function moveVertical(delta: int): void",
    "function revealSelection(start: int, end: int): void",
    "function computeFindMatches()",
    "function findNext(backward: bool, fromStart: bool): bool",
    "function replaceCurrentFind(): bool",
    "function replaceAllFind(): int",
    "root.openFind(false)",
    "root.openFind(true)",
    "event.key === Qt.Key_Slash",
    "event.key === Qt.Key_N",
):
    require(editor, token, "cursor/navigation helper missing")

for token in (
    "function focusSourceEditorWhenActive(): void",
    "root.enabled && root.visible && sourcePane.visible",
    "sourceEditor.focusEditor()",
    "sourceEditor.keyboardFocusWithin",
    "root.forceActiveFocus()",
    "CodeWorkflowSourceEditor {",
    "draft: root.sourceDraft",
    "definitionName: root.sourceHighlightDefinition",
    "onDraftEdited: text =>",
    "onSaveRequested: root.saveSourceEditor()",
    '"Source Editor · " + root.sourcePath',
    'SplitView.maximumHeight: 720',
):
    require(page, token, "Code Workflow page missing modal Source Editor integration")

tap_start = editor.index("TapHandler {")
tap_end = editor.index("Keys.onShortcutOverride: event =>", tap_start)
tap_block = editor[tap_start:tap_end]
require(tap_block, 'root.setMode("normal")',
        "pointer click must enter Normal/view mode")
require(tap_block, "editor.cursorPosition = root.clampPosition(position)",
        "pointer click must place the Normal-mode cursor")
require(tap_block, "editor.forceActiveFocus()",
        "pointer click must visibly focus the modal caret even in read-only mode")
if "root.enterInsertAt(position)" in tap_block:
    fail("pointer click must not enter Insert mode")

# Modal navigation must have a focus-gated shortcut route in addition to
# TextEdit's Keys handler: read-only TextEdit can lose bare-letter events.
motion_start = editor.index("function handleMotionKey(")
motion_end = editor.index("function applyVisualSelection(", motion_start)
motion = editor[motion_start:motion_end]
for key, call in (
    ("H", "root.moveHorizontal(-1)"),
    ("J", "root.moveVertical(1)"),
    ("K", "root.moveVertical(-1)"),
    ("L", "root.moveHorizontal(1)"),
):
    require(motion, "case Qt.Key_" + key + ": " + call,
            "modal " + key.lower() + " must navigate through shared dispatcher")
    require(editor, 'sequence: "' + key + '"',
            "modal motion needs a shortcut fallback")
    require(editor, "onActivated: root.handleMotionKey(Qt.Key_" + key + ", 0)",
            "shortcut must share the TextEdit motion dispatcher")
require(motion, 'root.mode === "insert"',
        "modal motion must not intercept Insert typing")
require(motion, "root.findVisible",
        "modal motion must not intercept Find/Replace typing")
require(motion, "!root.visible || !root.enabled",
        "hidden or inactive Source Editor must not dispatch modal motions")
require(motion, "Qt.ControlModifier | Qt.AltModifier",
        "modal motion must not swallow modified shortcuts")
require(editor, "Keys.priority: Keys.BeforeItem",
        "modal key handling must precede native read-only TextEdit handling")
require(editor, "root.handleMotionKey(event.key, event.modifiers)",
        "focused TextEdit must dispatch modal motions")
require(editor, 'enabled: editor.activeFocus && root.mode !== "insert"',
        "fallback must require editor focus and non-Insert mode")
require(editor, "&& root.visible && root.enabled && !root.findVisible",
        "fallback must be disabled for hidden or inactive editor")
require(editor, "readonly property bool keyboardFocusWithin:",
        "Source Editor must expose child focus for pane lifecycle")
require(editor, "&& !root.findVisible",
        "fallback must never steal text from Find/Replace")
for key, call in (
    ("W", "root.moveWord(1, false)"),
    ("B", "root.moveWord(-1, false)"),
    ("E", "root.moveWord(1, true)"),
):
    require(motion, "case Qt.Key_" + key + ": " + call,
            "lightweight Vim-style word motion missing")
    require(editor, "onActivated: root.handleMotionKey(Qt.Key_" + key + ", 0)",
            "word motion must use the same focus-gated shortcut path")
require(editor, r"if (/\s/.test(char))",
        "word navigation must classify actual whitespace")
require(editor, "onModalCursorPositionChanged: root.ensureCursorVisible()",
        "Normal/Visual motions must keep the modal caret in the viewport")
require(editor, "property int preferredColumn: -1",
        "vertical motions must retain the desired column across short lines")
require(editor, "const previousStart = root.lineStart(previousEnd)",
        "k must land on the immediately previous line, including empty lines")
if "root.lineStart(Math.max(0, previousEnd - 1))" in editor:
    fail("k still skips blank lines")
require(editor, "root.lineNumberAt(root.modalCursorPosition)",
        "Visual line numbers must follow the modal selection cursor")

# o/O must insert above/below with distinct caret destinations. Qt.callLater
# must never move the caret after a newer native keystroke or source refresh.
for token in (
    "function replaceRangeWithCursor(",
    "const revision = ++root.editRevision",
    "revision !== root.editRevision || root.documentText !== nextText",
    "root.editRevision += 1",
    'const insertAt = shift ? at : at + 1',
    'root.replaceRangeWithCursor(at, at, "\\n", insertAt)',
    "root.enterInsertAt(insertAt)",
):
    require(editor, token, "o/O must preserve the inserted line's caret")
if 'root.replaceRange(at, at, "\\n")' in editor:
    fail("o/O must not use the default queued end-of-insert cursor")


root_key_handlers = editor[:editor.index("readonly property int lineCount:")]
require(root_key_handlers, "Keys.onShortcutOverride: event =>",
        "editor root must intercept Escape before the Settings window shortcut")
require(root_key_handlers, "Keys.onPressed: event =>",
        "editor root must consume Escape from focused toolbar children")
require(root_key_handlers, "root.closeFind()",
        "Escape from a Find toolbar child must close Find, not Settings")
require(editor, "if (!root.findVisible)",
        "deferred Find focus must not resurrect a closed Find surface")
require(editor, "event.key === Qt.Key_Escape",
        "Source Editor must consume Escape while it owns focus")
require(editor, "event.key === Qt.Key_F",
        "Source Editor must intercept Find before Settings shortcuts")
require(editor, "event.key === Qt.Key_H",
        "Source Editor must intercept Replace before Settings shortcuts")
if "id: targetsToolbarToggle" in page or "id: inspectorToolbarToggle" in page:
    fail("global toolbar must not duplicate Targets/Inspector pane toggles")

require(
    settings_qmldir,
    "CodeWorkflowSourceEditor 1.0 CodeWorkflowSourceEditor.qml",
    "settings qmldir must export modal Source Editor",
)


print("ok - Code Workflow modal hot-fix Source Editor contract")
