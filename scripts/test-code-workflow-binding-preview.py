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


source = b"Item { width: parent.width }\n"
start = source.index(b"parent.width")
end = start + len(b"parent.width")
base_sha = sha256(source).hexdigest()
entry = {
    "anchor": "binding-width",
    "anchor_unique": True,
    "kind": "binding",
    "name": "width",
    "range": [7, end],
    "value_range": [start, end],
    "value_kind": "member_expression",
    "opaque_context": False,
    "editable": False,
}

prepared, candidate = workflow_transaction.prepare_binding_patch(
    source, base_sha, entry, "root.width")
if prepared.get("status") != "candidate":
    fail("safe direct member binding must produce an in-memory candidate")
if candidate != b"Item { width: root.width }\n":
    fail("direct binding candidate must replace only semantic value bytes")
if prepared["patch"]["oldText"] != "parent.width":
    fail("direct binding preview old text drifted")

identifier_entry = dict(entry)
identifier_entry["value_kind"] = "identifier"
identifier_source = b"Item { visible: enabled }\n"
identifier_start = identifier_source.index(b"enabled")
identifier_entry["value_range"] = [
    identifier_start,
    identifier_start + len(b"enabled"),
]
prepared, candidate = workflow_transaction.prepare_binding_patch(
    identifier_source,
    sha256(identifier_source).hexdigest(),
    identifier_entry,
    "active",
)
if prepared.get("status") != "candidate" or b"visible: active" not in candidate:
    fail("identifier direct binding must remain in preview subset")

for bad_kind in ("call_expression", "binary_expression", "ternary_expression"):
    unsupported_entry = dict(entry)
    unsupported_entry["value_kind"] = bad_kind
    unsupported, bad_candidate = workflow_transaction.prepare_binding_patch(
        source, base_sha, unsupported_entry, "root.width")
    if unsupported.get("status") != "unsupported" or bad_candidate is not None:
        fail("complex expression must stay outside direct binding preview: " + bad_kind)

property_entry = dict(entry)
property_entry["kind"] = "property"
unsupported, bad_candidate = workflow_transaction.prepare_binding_patch(
    source, base_sha, property_entry, "root.width")
if unsupported.get("status") != "unsupported" or bad_candidate is not None:
    fail("Phase 2J direct binding preview must not retarget property declarations")

transaction_source = (SCRIPT_DIR / "transaction.py").read_text(encoding="utf-8")
service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    'DIRECT_BINDING_VALUE_KINDS = {"identifier", "member_expression"}',
    "def prepare_binding_patch(",
    '"--mode"',
    'choices=("literal", "binding")',
    '"commandKind": command_kind',
    '"candidate-left-direct-binding-subset"',
):
    if token not in transaction_source:
        fail("direct binding transaction helper missing " + token)

for forbidden in ("write_text(", "write_bytes(", "os.replace(", "setText("):
    if forbidden in transaction_source:
        fail("transaction preview helper must stay source-non-writing: " + forbidden)

for token in (
    'property string _pendingCommandKind: "literal-property"',
    "function previewBinding(",
    '"direct-binding"',
    'blockers.push("write-subset-not-authorized")',
    'String(command.kind ?? "") !== "literal-property"',
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
):
    if token not in service:
        fail("binding preview/write isolation missing " + token)

for token in (
    "root.bindingPreviewEligible",
    "CodeWorkflowTransaction.previewBinding(",
    '"Preview binding patch"',
    '"PREVIEW ONLY"',
    '"Only qualified literal-property commands may Apply. Direct bindings are preview-only."',
):
    if token not in page:
        fail("binding preview UI missing " + token)

if "Milestone 2J — direct binding preview" not in phase2:
    fail("Phase 2 status must document preview-only direct binding subset")
if "No direct binding command can stage Apply artifacts" not in phase2:
    fail("Phase 2 status must document the write isolation boundary")

print("ok - Code Workflow Phase 2J direct binding preview contract")
