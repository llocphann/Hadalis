#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
IR = json.loads((ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8"))
IR_SERVICE = (ROOT / "services/CodeWorkflowIr.qml").read_text(encoding="utf-8")
SESSION = (ROOT / "services/CodeWorkflowSession.qml").read_text(encoding="utf-8")
CANVAS = (ROOT / "modules/settings/CodeWorkflowIrCanvas.qml").read_text(encoding="utf-8")
TRANSACTION = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
PAGE = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
PROBE = (ROOT / "scripts/code-workflow/runtime/ProbeShell.qml").read_text(encoding="utf-8")
HARNESS = (ROOT / "scripts/code-workflow/run-signal-action-user-apply.py").read_text(encoding="utf-8")
PRODUCTION_HARNESS = (ROOT / "scripts/code-workflow/run-signal-action-production-lifecycle.py").read_text(encoding="utf-8")
PHASE2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/code-workflow-acceptance.yml").read_text(encoding="utf-8")
EXCLUSIONS = json.loads((ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8"))


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


media = (IR.get("graphs") or {}).get("bar/media") or {}
edges = [edge for edge in (media.get("edges") or []) if edge.get("id") == "media.event.input"]
if len(edges) != 1 or edges[0].get("signalActionTargetId") != "media.signal.doubleClickToggle":
    fail("2K-W-D exact reviewed event edge identity drifted")
targets = [target for target in (media.get("signalActionTargets") or []) if target.get("id") == "media.signal.doubleClickToggle"]
if len(targets) != 1:
    fail("2K-W-D reviewed signal/action target must resolve exactly once")
target = targets[0]
if (
    target.get("eventNodeId") != "media.input"
    or target.get("actionNodeId") != "media.toggle"
    or target.get("handlerName") != "onDoubleClicked"
    or target.get("actionExpression") != "root.toggleExpanded()"
    or target.get("previewable") is not False
    or target.get("editable") is not False
):
    fail("2K-W-D exact reviewed target identity drifted")

for token in (
    "function signalActionTargetsFor(",
    "function signalActionTargetFor(",
    "function reviewedSignalActionTargetForEdge(",
    "function reviewedSignalActionTargetForNode(",
    '!== "bar/media"',
    '!== "media.signal.doubleClickToggle"',
):
    if token not in IR_SERVICE:
        fail("2K-W-D IR selection boundary missing " + token)

for token in (
    "CodeWorkflowIr.reviewedSignalActionTargetForEdge(",
    "if (signalAction !== null)",
    'actionNode.kind !== "action"',
    "root.selectedEdgeId = edge.id",
):
    if token not in SESSION:
        fail("2K-W-D session selection boundary missing " + token)

for token in (
    "function selectableEdgeAt(",
    "root.previewableEdgeAt(screenX, screenY)",
    "CodeWorkflowIr.reviewedSignalActionTargetForEdge(",
    "CodeWorkflowSession.selectEdge(edgeId)",
):
    if token not in CANVAS:
        fail("2K-W-D canvas selection boundary missing " + token)

for token in (
    "readonly property var selectedSignalActionTarget:",
    "readonly property var reviewedSignalActionTargetForSelection:",
    "readonly property var reviewedSignalActionEdgeForSelection:",
    '"Select Signal/Action · "',
    '"Reviewed Signal/Action"',
    '"Preview Signal/Action"',
    "function previewSelectedSignalAction(): void",
    "CodeWorkflowTransaction.previewSignalAction(",
    '"media.signal.doubleClickToggle"',
    '"Prepare Signal/Action artifacts"',
    '"Authorize Signal/Action write"',
    '"Apply Signal/Action"',
    '"Revoke Signal/Action authorization"',
    "CodeWorkflowTransaction.prepareSignalActionArtifacts()",
    "CodeWorkflowTransaction.authorizeSignalActionWrite()",
    "CodeWorkflowTransaction.beginAuthorizedSignalActionApply()",
    "CodeWorkflowTransaction.revokeSignalActionAuthorization(",
    '"SIGNAL/ACTION APPLY READY"',
    '"SIGNAL/ACTION APPLIED"',
    '"SIGNAL/ACTION ROLLED BACK"',
    '"Signal/Action Apply lifecycle · "',
    "mutation/history/preparation controls are locked",
    "no TYPE/CYCLE proof is used for Signal/Action",
):
    if token not in PAGE:
        fail("2K-W-D Settings boundary missing " + token)

for forbidden in (
    "CodeWorkflowTransaction.beginSignalActionLifecycle()",
    "signal_action.py",
    "signal_action_prepare.py",
    "signal_action_commit.py",
):
    if forbidden in PAGE:
        fail("Settings bypasses Signal/Action transaction boundary: " + forbidden)

for token in (
    "readonly property bool signalActionPrepareEnabled:",
    "readonly property bool signalActionAuthorizeEnabled:",
    "readonly property bool signalActionApplyEnabled:",
    "function prepareSignalActionArtifacts(): bool",
    "function authorizeSignalActionWrite(): bool",
    "function revokeSignalActionAuthorization(",
    "function beginAuthorizedSignalActionApply(): bool",
    '"explicit-signal-action-write-authorization-v1"',
    '"inserted-handler-rebound-exact-action"',
):
    if token not in TRANSACTION:
        fail("2K-W-D transaction wrapper missing " + token)

for token in (
    "signalActionApplyEnabled:",
    "function workflowSignalActionApply(): bool",
    "CodeWorkflowTransaction.beginAuthorizedSignalActionApply()",
):
    if token not in PROBE:
        fail("2K-W-D ProbeShell user-Apply boundary missing " + token)

for token in (
    "def run_user_apply_success(",
    "def run_user_apply_rollback(",
    '"Phase 2K-W-D"',
    "prod.run_success(",
    "prod.run_postcondition_failure(",
    '"signal-action-user-apply-report.json"',
):
    if token not in HARNESS:
        fail("2K-W-D live user Apply harness missing " + token)

for token in (
    '"workflowSignalActionApply"',
    '"signal-action-applied"',
    '"signal-action-rollback-complete"',
    '"signal-action-rolled-back"',
):
    if token not in PRODUCTION_HARNESS:
        fail("2K-W-D reused live wrapper proof missing " + token)

excluded = set(EXCLUSIONS.get("excludedPaths", []))
if "scripts/code-workflow/run-signal-action-user-apply.py" not in excluded:
    fail("2K-W-D live harness must remain outside runtime payload")
runtime_payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"), "list", "--root", str(ROOT)],
    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
).stdout.splitlines()
if "scripts/code-workflow/run-signal-action-user-apply.py" in set(runtime_payload):
    fail("2K-W-D live harness leaked into runtime payload")

for token in (
    "Milestone 2K-W-D — user-facing reviewed Signal/Action Apply",
    "media.event.input",
    "Apply Signal/Action",
    "beginAuthorizedSignalActionApply()",
    "exactly once",
    "automatic exact rollback",
    "no TYPE/CYCLE",
    "Additional Signal/Action targets remain unavailable",
):
    if token not in PHASE2:
        fail("2K-W-D documentation missing " + token)

for token in (
    "Validate user-facing Signal/Action Apply boundary",
    "test-code-workflow-signal-action-settings.py",
    "Run isolated user-facing Signal/Action Apply acceptance",
    "run-signal-action-user-apply.py",
    "signal-action-user-apply-report.json",
):
    if token not in WORKFLOW:
        fail("2K-W-D acceptance workflow missing " + token)

print("ok - Code Workflow 2K-W-D user-facing reviewed Signal/Action Apply")
