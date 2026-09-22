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
    "event.key === Qt.Key_H",
    "event.key === Qt.Key_J",
    "event.key === Qt.Key_K",
    "event.key === Qt.Key_L",
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
    "cursorShape: Qt.IBeamCursor",
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
if "root.enterInsertAt(position)" in tap_block:
    fail("pointer click must not enter Insert mode")

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
