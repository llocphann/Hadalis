#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import transaction as workflow_transaction


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


source = b"Item { property bool flag: false }\n"
start = source.index(b"false")
end = start + len(b"false")
base_sha = sha256(source).hexdigest()
entry = {
    "anchor": "literal-flag",
    "anchor_unique": True,
    "kind": "property",
    "name": "flag",
    "range": [7, end],
    "value_range": [start, end],
    "value_kind": "false",
    "opaque_context": False,
    "editable": False,
}

prepared, candidate = workflow_transaction.prepare_literal_patch(
    source, base_sha, entry, "true")
if prepared.get("status") != "candidate":
    fail("safe literal property must produce an in-memory candidate")
if candidate != b"Item { property bool flag: true }\n":
    fail("literal candidate must change only the value bytes")
if prepared["patch"]["oldText"] != "false" or prepared["patch"]["newText"] != "true":
    fail("patch preview old/new text drifted")

conflict, conflict_candidate = workflow_transaction.prepare_literal_patch(
    source, "0" * 64, entry, "true")
if conflict.get("status") != "conflict" or conflict_candidate is not None:
    fail("base SHA mismatch must fail closed before a candidate is created")

binding_entry = dict(entry)
binding_entry["kind"] = "binding"
unsupported, unsupported_candidate = workflow_transaction.prepare_literal_patch(
    source, base_sha, binding_entry, "true")
if unsupported.get("status") != "unsupported" or unsupported_candidate is not None:
    fail("first Phase 2 transform must not rewrite general bindings")

expression_entry = dict(entry)
expression_entry["value_kind"] = "member_expression"
unsupported, unsupported_candidate = workflow_transaction.prepare_literal_patch(
    source, base_sha, expression_entry, "true")
if unsupported.get("status") != "unsupported" or unsupported_candidate is not None:
    fail("non-literal property values must remain outside the first transform subset")

multiline, multiline_candidate = workflow_transaction.prepare_literal_patch(
    source, base_sha, entry, "true\nfalse")
if multiline.get("status") != "unsupported" or multiline_candidate is not None:
    fail("dry-run literal replacement must stay one trimmed expression")

transaction_source = (SCRIPT_DIR / "transaction.py").read_text(encoding="utf-8")
for forbidden in (
    "write_text(",
    "write_bytes(",
    "os.replace(",
    "atomicWrites",
    "setText(",
):
    if forbidden in transaction_source:
        fail("dry-run transaction helper must not write source: " + forbidden)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")

if "singleton CodeWorkflowTransaction 1.0 CodeWorkflowTransaction.qml" not in qmldir:
    fail("transaction preview singleton must be exported")

for token in (
    'property string status: "clean"',
    "readonly property bool applyEnabled:",
    "readonly property bool applyCommandMatchesHandoff:",
    "function previewLiteral(",
    'Quickshell.shellPath("scripts/code-workflow/transaction.py")',
    "function markSourceChanged(path: string): void",
):
    if token not in service:
        fail("transaction service missing " + token)

for forbidden in ("setText(", "writeAdapter(", "atomicWrites"):
    if forbidden in service:
        fail("transaction preview service must not own a source write path: " + forbidden)

for token in (
    "root.literalPreviewEligible",
    "CodeWorkflowTransaction.previewLiteral(",
    "CodeWorkflowTransaction.markSourceChanged(root.sourcePath)",
    '"Literal Transaction · "',
):
    if token not in page:
        fail("Code Workflow literal preview UI missing " + token)

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/transaction.py" not in set(payload):
    fail("transaction preview helper must ship in runtime payload")

print("ok - Code Workflow Phase 2 dry-run literal transaction contract")
