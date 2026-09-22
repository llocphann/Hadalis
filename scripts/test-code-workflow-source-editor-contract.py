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

for path in (
    ROOT / "services" / "CodeWorkflowNvim.qml",
    ROOT / "modules" / "settings" / "CodeWorkflowNvimView.qml",
    ROOT / "scripts" / "code-workflow-nvim-bridge.py",
):
    if path.exists():
        fail("retired embedded editor artifact still exists: " + str(path.relative_to(ROOT)))

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
):
    require(editor, token, "modal editing contract missing")

for token in (
    "readonly property int lineCount:",
    "readonly property string lineNumberText:",
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
):
    require(editor, token, "cursor/navigation helper missing")

for token in (
    "CodeWorkflowSourceEditor {",
    "draft: root.sourceDraft",
    "definitionName: root.sourceHighlightDefinition",
    "onDraftEdited: text =>",
    "onSaveRequested: root.saveSourceEditor()",
    '"Source Editor · " + root.sourcePath',
):
    require(page, token, "Code Workflow page missing modal Source Editor integration")

require(
    settings_qmldir,
    "CodeWorkflowSourceEditor 1.0 CodeWorkflowSourceEditor.qml",
    "settings qmldir must export modal Source Editor",
)

for retired in ("CodeWorkflowNvim.qml", "CodeWorkflowNvimView.qml"):
    if retired in services_qmldir or retired in settings_qmldir:
        fail("retired embedded editor export remains: " + retired)

print("ok - Code Workflow modal hot-fix Source Editor contract")
