#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
transaction = (ROOT / "scripts/code-workflow/transaction.py").read_text(encoding="utf-8")

for token in (
    "property var history: []",
    "property int historyIndex: -1",
    "readonly property bool canUndo:",
    "readonly property bool canRedo:",
    "function undoPreview(): bool",
    "function redoPreview(): bool",
    "function regenerate(baseSha: string): bool",
    "function _markHistoryStale(path: string): void",
    "root.history.slice(0, root.historyIndex + 1)",
    "next[root._pendingReplaceIndex] = command",
    'kind: "literal-property"',
    "semanticAnchor: root.semanticAnchor",
    "baseSha256: root.baseSha256",
):
    if token not in service:
        fail("semantic preview history missing " + token)

if "byteRange:" in service or "valueRange:" in service:
    fail("history command identity must not persist transient byte ranges")

for token in (
    "CodeWorkflowTransaction.canUndo",
    "CodeWorkflowTransaction.undoPreview()",
    "CodeWorkflowTransaction.canRedo",
    "CodeWorkflowTransaction.redoPreview()",
    "CodeWorkflowTransaction.regenerate(currentSha)",
    'mainText: "Regenerate"',
    '"STALE: "',
):
    if token not in page:
        fail("patch drawer history/regenerate UI missing " + token)

for forbidden in (
    "FileView {",
    "setText(",
    "writeAdapter(",
    "atomicWrites",
):
    if forbidden in service:
        fail("history milestone must not add a source writer: " + forbidden)

for forbidden in (
    "write_text(",
    "write_bytes(",
    "os.replace(",
):
    if forbidden in transaction:
        fail("transaction helper must remain dry-run: " + forbidden)

if "readonly property bool applyEnabled: false" not in service:
    fail("Apply must remain disabled after history/regenerate milestone")
if "Apply workflow" in page:
    fail("Code Workflow page must not expose Apply yet")

print("ok - Code Workflow semantic preview history/regenerate contract")
