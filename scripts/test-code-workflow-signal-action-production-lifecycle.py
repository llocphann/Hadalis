#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(
    encoding="utf-8"
)
PAGE = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8"
)
PROBE = (
    ROOT / "scripts/code-workflow/runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
PHASE2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(
    encoding="utf-8"
)
WORKFLOW = (
    ROOT / ".github/workflows/code-workflow-acceptance.yml"
).read_text(encoding="utf-8")
HARNESS = (
    ROOT / "scripts/code-workflow/run-signal-action-production-lifecycle.py"
).read_text(encoding="utf-8")
EXCLUSIONS = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


for token in (
    "readonly property bool signalActionPreparationBusy:",
    "readonly property bool signalActionLifecycleBusy:",
    "readonly property var activeSignalActionPreparation:",
    "readonly property bool signalActionArtifactsReady:",
    "readonly property var activeSignalActionAuthorization:",
    "readonly property bool signalActionAuthorizationReady:",
    "readonly property bool signalActionPrepareEnabled:",
    "readonly property bool signalActionAuthorizeEnabled:",
    "readonly property bool signalActionApplyEnabled:",
    '=== "bar/media"',
    '=== "media.signal.doubleClickToggle"',
    '=== "modules/bar/Media.qml"',
    '=== "onDoubleClicked"',
    '=== "root.toggleExpanded()"',
    '=== "handler-candidate"',
    '=== "call_expression"',
    "function previewSignalAction(",
    "function prepareSignalActionArtifacts(): bool",
    "function finishSignalActionPreparation(exitCode: int): void",
    "function authorizeSignalActionWrite(): bool",
    "function revokeSignalActionAuthorization(",
    "function beginAuthorizedSignalActionApply(): bool",
    "function beginSignalActionLifecycle(): bool",
    "function finishSignalActionCommit(exitCode: int): void",
    "function finishSignalActionVerify(exitCode: int): void",
    "function _beginSignalActionPostconditionCheck(): void",
    "function _finishSignalActionPostconditionIfReady(): void",
    "function _startSignalActionRollback(reason: string): void",
    "function _finalizeSignalActionRollback(payload): void",
    "function _recoverSignalActionLifecycle(): void",
    '"explicit-signal-action-write-authorization-v1"',
    '"inserted-handler-rebound-exact-action"',
    '"exact-snapshot-auto-rollback-v1"',
    'Quickshell.shellPath(\n                "scripts/code-workflow/signal_action.py")',
    'Quickshell.shellPath(\n                "scripts/code-workflow/signal_action_prepare.py")',
    'Quickshell.shellPath(\n                "scripts/code-workflow/signal_action_commit.py")',
    "pendingSignalActionInsertedHandlerSemanticAnchor",
    "pendingSignalActionExistingActionSemanticAnchor",
    "pendingSignalActionAuthorizationToken",
    "signalActionRollbackReloadFallbackTimer",
    "signalActionPreviewProcess",
    "signalActionPrepareProcess",
    "signalActionCommitProcess",
    "signalActionVerifyProcess",
    "signalActionRollbackProcess",
):
    if token not in SERVICE:
        fail("2K-W-C transaction boundary missing " + token)

post_start = SERVICE.find(
    "function _beginSignalActionPostconditionCheck(): void"
)
post_end = SERVICE.find(
    "function _markHistorySignalActionLifecycleResult(",
    post_start,
)
if min(post_start, post_end) < 0:
    fail("2K-W-C signal/action postcondition region missing")
post = SERVICE[post_start:post_end]
for token in (
    'pendingSignalActionSourcePath,\n            "",',
    "pendingSignalActionInsertedHandlerSemanticAnchor",
    '=== "handler-candidate"',
    '=== "onDoubleClicked"',
    '=== "root.toggleExpanded()"',
    "CodeWorkflowAnalyzer.diagnostics.length === 0",
):
    if token not in post:
        fail("2K-W-C exact postcondition missing " + token)
if "sourceNeedle" in post or '"onDoubleClicked:' in post:
    fail("W-C postcondition must rebind by semantic anchor, not source needle")

auth_start = SERVICE.find(
    "function authorizeSignalActionWrite(): bool"
)
auth_end = SERVICE.find(
    "function revokeSignalActionAuthorization(",
    auth_start,
)
if min(auth_start, auth_end) < 0:
    fail("2K-W-C authorization region missing")
auth = SERVICE[auth_start:auth_end]
for forbidden in (
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "typeCompatibility",
    "cycleStatus",
):
    if forbidden in auth:
        fail("Signal/action authorization inherited data-binding proof: " + forbidden)

for function_name in (
    "stageConnectLifecycleHandoff",
    "stageBindingLifecycleHandoff",
    "stageDisconnectLifecycleHandoff",
    "stageSignalActionLifecycleHandoff",
):
    start = SERVICE.find("function " + function_name + "(")
    end = SERVICE.find("\n    function ", start + 10)
    if start < 0:
        fail(function_name + " missing")
    block = SERVICE[start:end if end >= 0 else None]
    if "signalActionLifecycleBusy" not in block:
        fail(function_name + " does not serialize Signal/Action ownership")

for token in (
    'restoredOwnerKind = "signal-action"',
    "activeSignalActionPhases.includes(signalActionPhase)",
    "root._invalidateCompetingHandoffsForOwnedSource(",
    "owner === \"signal-action\" ? preserved : -1",
    "root._markSignalActionArtifactsStale(changedPath)",
    "Qt.callLater(root._recoverSignalActionLifecycle)",
    "root._finishSignalActionPostconditionIfReady()",
):
    if token not in SERVICE:
        fail("W-C reload/serialization persistence missing " + token)

reload_complete = SERVICE[
    SERVICE.find("function _handleReloadCompleted(): void"):
    SERVICE.find("function _handleReloadFailed(errorString: string): void")
]
reload_failed_start = SERVICE.find(
    "function _handleReloadFailed(errorString: string): void"
)
reload_failed_end = SERVICE.find(
    "function _clearPresentation(): void",
    reload_failed_start,
)
reload_failed = SERVICE[reload_failed_start:reload_failed_end]
for token in (
    "pendingSignalActionReloadOutcome = \"completed\"",
    "root._startSignalActionCandidateVerify()",
    "root._startSignalActionRollbackVerify()",
):
    if token not in reload_complete:
        fail("W-C reload completion handling missing " + token)
for token in (
    "pendingSignalActionReloadOutcome = \"failed\"",
    "root._startSignalActionRollback(message)",
    '"signal-action-rollback-failed"',
):
    if token not in reload_failed:
        fail("W-C reload failure handling missing " + token)

excluded = set(EXCLUSIONS.get("excludedPaths", []))
for helper in (
    "scripts/code-workflow/signal_action.py",
    "scripts/code-workflow/signal_action_prepare.py",
    "scripts/code-workflow/signal_action_commit.py",
):
    if helper in excluded:
        fail("2K-W-C production helper is still runtime-excluded: " + helper)
    if helper not in SERVICE:
        fail("2K-W-C service does not reference promoted helper: " + helper)
    if helper in PAGE:
        fail("Settings must never invoke Signal/Action Python helper directly")

# W-C qualifies the internal lifecycle only. User-facing Settings selection and
# Apply exposure remain a later gate.
for forbidden in (
    "Apply Signal/Action",
    "Prepare Signal/Action artifacts",
    "Authorize Signal/Action write",
    "CodeWorkflowTransaction.beginAuthorizedSignalActionApply()",
):
    if forbidden in PAGE:
        fail("W-C must not expose user-facing Signal/Action Apply yet: " + forbidden)

for token in (
    "signalActionPreparationBusy:",
    "signalActionArtifactsReady:",
    "signalActionLifecycleBusy:",
    "pendingSignalActionPhase:",
    "signalActionAuthorizationReady:",
    "signalActionAuthorizeEnabled:",
    "signalActionApplyEnabled:",
    "activeSignalActionAuthorization:",
    "activeSignalActionPreparation:",
    "function workflowSignalActionPreview(): bool",
    "function workflowSignalActionPrepare(): bool",
    "function workflowSignalActionAuthorize(): bool",
    "function workflowSignalActionRevoke(): bool",
    "function workflowSignalActionBeginLifecycle(): bool",
    "function workflowSignalActionApply(): bool",
    "function workflowSignalActionAnalyzeExistingAction(): void",
    "function workflowSignalActionOverridePreparedAnchor(",
):
    if token not in PROBE:
        fail("2K-W-C ProbeShell instrumentation missing " + token)

for token in (
    "def run_success(",
    "def run_postcondition_failure(",
    '"workflowSignalActionApply"',
    '"signal-action-applied"',
    '"signal-action-rollback-complete"',
    '"signal-action-rolled-back"',
    '"workflowSignalActionAnalyzeExistingAction"',
    '"workflowSignalActionOverridePreparedAnchor"',
    '"handler-candidate"',
    '"root.toggleExpanded()"',
    '"base-present"',
):
    if token not in HARNESS:
        fail("2K-W-C live harness missing " + token)

if (
    "scripts/code-workflow/run-signal-action-production-lifecycle.py"
    not in excluded
):
    fail("2K-W-C live harness must remain outside runtime payload")

for token in (
    "Milestone 2K-W-C — reviewed signal/action internal production lifecycle",
    "explicit-signal-action-write-authorization-v1",
    "inserted-handler-rebound-exact-action",
    "media.signal.doubleClickToggle",
    "Settings Apply remains unavailable",
    "no TYPE/CYCLE",
):
    if token not in PHASE2:
        fail("2K-W-C documentation missing " + token)

for token in (
    "Validate reviewed Signal/Action internal production lifecycle",
    "Run isolated reviewed Signal/Action production lifecycle",
    "run-signal-action-production-lifecycle.py",
    "signal-action-production-lifecycle-report.json",
    "hadalis-wf-sa-prod",
):
    if token not in WORKFLOW:
        fail("Code Workflow acceptance missing W-C live contract " + token)

if "hadalis-workflow-signal-action-production" in WORKFLOW:
    fail("W-C live workdir is too long for Quickshell AF_UNIX IPC socket path")

print(
    "ok - Code Workflow 2K-W-C reviewed signal/action internal "
    "production lifecycle contract"
)
