#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
ir_service = (ROOT / "services/CodeWorkflowIr.qml").read_text(encoding="utf-8")
analyzer = (ROOT / "scripts/code-workflow/analyze.py").read_text(encoding="utf-8")
transaction_service = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


clock = manifest["graphs"]["bar/clock"]
targets = clock.get("connectTargets") or []
if len(targets) != 1:
    fail("2K-E must expose exactly one reviewed connect-target fixture")

target = targets[0]
expected = {
    "id": "clock.connect.rootVisible",
    "parentNodeId": "clock.component",
    "sourcePath": "modules/bar/ClockWidget.qml",
    "parentObjectNeedle": "id: root",
    "bindingName": "visible",
    "sourceExpression": "root.showDate",
    "reviewedParentSemanticKind": "object",
    "reviewedValueKind": "member_expression",
    "typeCompatibility": "unknown-unresolved",
    "cycleStatus": "unknown-incomplete-projection",
    "previewable": False,
    "editable": False,
}
for key, value in expected.items():
    if target.get(key) != value:
        fail(f"connect target {key} drifted: {target.get(key)!r}")

source = (ROOT / target["sourcePath"]).read_text(encoding="utf-8")
if source.count(target["parentObjectNeedle"]) != 1:
    fail("parent object needle must be unique in reviewed source")
if ("\n    " + target["bindingName"] + ":") in source:
    fail("reviewed connect target must describe an absent direct member")
if target["sourceExpression"] not in source:
    fail("reviewed source expression must already have source evidence")

for token in (
    "function connectTargetsFor(targetId: string): var",
    "function connectTargetFor(targetId: string, connectTargetId: string): var",
):
    if token not in ir_service:
        fail("IR reviewed connect-target lookup missing " + token)

for token in (
    "def resolve_reviewed_object_anchor(",
    '"--object-needle"',
    '"reviewedObjectAnchor": reviewed_object_anchor',
    '"initializerRange": entry.get("initializer_range")',
    '"semanticKind": entry.get("kind", "")',
):
    if token not in analyzer:
        fail("analyzer parent-object protocol missing " + token)

if 'Quickshell.shellPath("scripts/code-workflow/connect.py")' in transaction_service:
    fail("production Connect preview must not bypass reviewed coordinator")
for token in (
    'Quickshell.shellPath("scripts/code-workflow/connect_preview.py")',
    'function previewConnectBinding(',
    '"connect-binding"',
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
):
    if token not in transaction_service:
        fail("reviewed Connect integration missing " + token)

for token in (
    "Milestone 2K-E — reviewed Connect target identity",
    "parentObjectNeedle",
    "previewable=false",
    "No Connect control is exposed",
):
    if token not in phase2:
        fail("2K-E documentation missing " + token)

print("ok - Code Workflow 2K-E reviewed Connect target identity contract")
