#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEW = ROOT / "modules" / "settings" / "CodeWorkflowNvimView.qml"
PAGE = ROOT / "modules" / "settings" / "CodeWorkflow.qml"

def fail(message):
    print("FAIL:", message)
    raise SystemExit(1)

view = VIEW.read_text(encoding="utf-8")
page = PAGE.read_text(encoding="utf-8")

for token in (
    "Canvas {",
    "function markRowDirty(row: int): void",
    "editorCanvas.markDirty(Qt.rect(",
    "function markFrameDirty(): void",
    "CodeWorkflowNvim.lastDirtyRows",
    "CodeWorkflowNvim.fullRepaintRequested",
    "onPaint: region =>",
    "const firstRow =",
    "const lastRow =",
    "CodeWorkflowNvim.gridRows",
    "CodeWorkflowNvim.highlights",
    "CodeWorkflowNvim.defaultColors",
    "CodeWorkflowNvim.cursorRow",
    "CodeWorkflowNvim.cursorCol",
    "Keys.onPressed: event =>",
    "id: nvimImeProxy",
    "inputMethodHints: Qt.ImhNone",
    "nvimImeProxy.inputMethodComposing",
    "function handleKeyEvent(event): bool",
    "onTextEdited:",
    "root.escapeInputText(committed)",
    "nvimImeProxy.forceActiveFocus()",
    "id: imePreeditBubble",
    "nvimImeProxy.preeditText",
    "visible: nvimImeProxy.inputMethodComposing",
    "CodeWorkflowNvim.cursorCol * root.cellWidth",
    "CodeWorkflowNvim.cursorRow * root.cellHeight",
    "CodeWorkflowNvim.input(token)",
    "function requestClipboardPaste(): void",
    'command: ["wl-paste", "-n"]',
    "CodeWorkflowNvim.paste(text)",
    "event.key === Qt.Key_V",
    "event.key === Qt.Key_Insert",
    "function resetCursorBlink(): void",
    "id: cursorBlinkTimer",
    "style.blinkwait",
    "style.blinkon",
    "style.blinkoff",
    "&& root.cursorBlinkVisible",
    "function eventKeyToken(event): string",
    'replace(/</g, "<lt>")',
    "function updateNvimSize(): void",
    "CodeWorkflowNvim.resize(root.requestedCols, root.requestedRows)",
    "function mouseCell(x: real, y: real): var",
    "CodeWorkflowNvim.mouse(",
    "hoverEnabled: CodeWorkflowNvim.mouseEnabled",
):
    if token not in view:
        fail("embedded Neovim view missing " + token)

for token in (
    "property bool sourceEditorUseNvim: false",
    '"Use embedded Neovim"',
    "CodeWorkflowNvimView {",
    "id: embeddedNvimEditor",
    "sourcePath: root.sourceEditorTargetPath",
    '"Save Neovim buffer"',
    "CodeWorkflowNvim.save()",
):
    if token not in page:
        fail("Code Workflow page missing embedded Neovim integration " + token)

if "TextEdit {" in view or "SyntaxHighlighter {" in view:
    fail("embedded Neovim view must render the Neovim grid, not emulate Vim with TextEdit")

print("ok - Code Workflow embedded Neovim view contract")
