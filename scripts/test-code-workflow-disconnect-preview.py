#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import transaction as workflow_transaction


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


source = (
    b"Item {\n"
    b"    width: parent.width\n"
    b"    height: 20\n"
    b"}\n"
)
member_start = source.index(b"width: parent.width")
member_end = member_start + len(b"width: parent.width")
value_start = source.index(b"parent.width")
value_end = value_start + len(b"parent.width")
entry = {
    "anchor": "binding-width",
    "anchor_unique": True,
    "kind": "binding",
    "name": "width",
    "range": [member_start, member_end],
    "value_range": [value_start, value_end],
    "value_kind": "member_expression",
    "opaque_context": False,
    "editable": False,
}

prepared, candidate = workflow_transaction.prepare_disconnect_binding_patch(
    source,
    sha256(source).hexdigest(),
    entry,
    "parent.width",
)
if prepared.get("status") != "candidate":
    fail("verified standalone binding must produce disconnect candidate")
if candidate != b"Item {\n    height: 20\n}\n":
    fail("disconnect must delete exactly the standalone binding line")
if prepared.get("resultingState") != "unbound/default":
    fail("disconnect preview must disclose resulting unbound/default state")
if prepared["patch"]["newText"] != "":
    fail("disconnect patch must be deletion, never undefined replacement")

drift, drift_candidate = workflow_transaction.prepare_disconnect_binding_patch(
    source,
    sha256(source).hexdigest(),
    entry,
    "root.width",
)
if drift.get("status") != "conflict" or drift_candidate is not None:
    fail("reviewed source expression drift must fail closed")

inline = b"Item { width: parent.width; height: 20 }\n"
inline_start = inline.index(b"width: parent.width")
inline_value = inline.index(b"parent.width")
inline_entry = dict(entry)
inline_entry["range"] = [inline_start, inline_start + len(b"width: parent.width")]
inline_entry["value_range"] = [inline_value, inline_value + len(b"parent.width")]
blocked, blocked_candidate = workflow_transaction.prepare_disconnect_binding_patch(
    inline,
    sha256(inline).hexdigest(),
    inline_entry,
    "parent.width",
)
if blocked.get("status") != "unsupported" or blocked_candidate is not None:
    fail("inline member deletion must remain unsupported")

transaction_source = (SCRIPT_DIR / "transaction.py").read_text(encoding="utf-8")
service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    "def prepare_disconnect_binding_patch(",
    '"reviewed-edge-source-expression-drift"',
    '"binding-member-is-not-standalone-line"',
    'choices=("literal", "binding", "disconnect")',
    '"disconnected-semantic-anchor-still-resolves"',
    '"resultingState": prepared.get("resultingState", "")',
):
    if token not in transaction_source:
        fail("disconnect helper contract missing " + token)

for token in (
    "function previewDisconnectBinding(",
    '"disconnect-binding"',
    '"disconnect"',
    'String(command.kind ?? "") !== "literal-property"',
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
):
    if token not in service:
        fail("disconnect preview/write isolation missing " + token)

for token in (
    "function previewSelectedEdgeDisconnect(): void",
    "CodeWorkflowTransaction.previewDisconnectBinding(",
    'mainText: "Preview Disconnect"',
    '"Disconnect Preview · "',
):
    if token not in page:
        fail("disconnect preview UI missing " + token)

if "Milestone 2K-C — verified Disconnect preview" not in phase2:
    fail("Phase 2 status must document 2K-C")
if "old semantic anchor must resolve as missing" not in phase2:
    fail("Phase 2 status must document deletion rebind invariant")
if "Disconnect Apply remains disabled" not in phase2:
    fail("Phase 2 status must keep Disconnect write disabled")

print("ok - Code Workflow 2K-C verified Disconnect preview contract")
