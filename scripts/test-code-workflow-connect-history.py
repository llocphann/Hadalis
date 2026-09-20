#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
session = (ROOT / "services/CodeWorkflowSession.qml").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
coordinator = (
    ROOT / "scripts/code-workflow/connect_preview.py"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

target = manifest["graphs"]["bar/clock"]["connectTargets"][0]
if target.get("previewable") is not False or target.get("editable") is not False:
    fail("2K-G must not turn reviewed descriptor presence into mutation authority")
if target.get("typeCompatibility") != "unknown-unresolved":
    fail("2K-G fixture must retain TYPE UNKNOWN")
if target.get("cycleStatus") != "unknown-incomplete-projection":
    fail("2K-G fixture must retain CYCLE UNKNOWN")

for token in (
    'property string selectedConnectTargetId: ""',
    'state.codeWorkflowConnectTargetId = root.selectedConnectTargetId',
    'state.codeWorkflowConnectTargetId ?? ""',
    'function selectConnectTarget(connectTargetId: string): bool',
    'CodeWorkflowIr.connectTargetFor(',
    'target.previewable !== false',
    'target.editable !== false',
    'target.typeCompatibility !== "unknown-unresolved"',
    'target.cycleStatus !== "unknown-incomplete-projection"',
    'root.selectedConnectTargetId = ""',
):
    if token not in session:
        fail("Connect session identity/persistence missing " + token)

for token in (
    'readonly property bool previewBusy:',
    'connectPreviewProcess.running',
    'function previewConnectBinding(',
    'function _startConnectPreview(',
    'Quickshell.shellPath("scripts/code-workflow/connect_preview.py")',
    '"--target-id", nextTargetId',
    '"--connect-target-id", nextConnectTargetId',
    'kind: "connect-binding"',
    'targetId: root._pendingConnectGraphTargetId',
    'connectTargetId: root._pendingConnectTargetId',
    'sourceWritable: false',
    'if (commandKind === "connect-binding")',
    'payload?.applyEnabled === false',
    'payload?.artifactsStaged === false',
    '=== "unknown-unresolved"',
    '=== "unknown-incomplete-projection"',
):
    if token not in transaction:
        fail("Connect preview history/regenerate integration missing " + token)

if 'Quickshell.shellPath("scripts/code-workflow/connect.py")' in transaction:
    fail("production transaction service must invoke coordinator, never connect.py")

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    'if (!root.applyEnabled)',
):
    if token not in transaction:
        fail("literal-only Apply isolation drifted: " + token)

for token in (
    "reviewedConnectTargetsForSelection",
    "selectedConnectTarget",
    "connectPreviewEligible",
    'CodeWorkflowSession.selectConnectTarget(',
    'CodeWorkflowTransaction.previewConnectBinding(',
    'mainText: "Preview Connect"',
    'text: "TYPE UNKNOWN · CYCLE UNKNOWN · PREVIEW ONLY"',
    '=== "connect-binding"',
    '"connect-binding"',
    "root.previewSelectedConnectTarget()",
):
    if token not in page:
        fail("Connect preview UI/diagnostics missing " + token)

for forbidden in (
    "typeCompatibility === \"compatible\"",
    "cycleStatus === \"safe\"",
):
    if forbidden in page or forbidden in transaction:
        fail("UNKNOWN must not be presented as qualified safety")

for token in (
    '"typeCompatibility": TYPE_UNKNOWN',
    '"cycleStatus": CYCLE_UNKNOWN',
    '"applyEnabled": False',
    '"artifactsStaged": False',
):
    if token not in coordinator:
        fail("coordinator UNKNOWN/write blocker missing " + token)

for token in (
    "Milestone 2K-G — preview-only Connect history and UI",
    "TYPE UNKNOWN · CYCLE UNKNOWN · PREVIEW ONLY",
    "coordinator-only invocation",
    "literal-only Apply authorization",
):
    if token not in phase2:
        fail("2K-G documentation missing " + token)

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/connect_preview.py" not in set(payload):
    fail("production Connect coordinator must ship in runtime payload")

print("ok - Code Workflow 2K-G preview-only Connect history/UI integration")
