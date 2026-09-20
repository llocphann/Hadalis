#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"

transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (
    ROOT / "modules/settings/CodeWorkflow.qml"
).read_text(encoding="utf-8")
probe = (
    SCRIPT_DIR / "runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
prepare = (
    SCRIPT_DIR / "binding_prepare.py"
).read_text(encoding="utf-8")
commit = (
    SCRIPT_DIR / "binding_commit.py"
).read_text(encoding="utf-8")
harness = (
    SCRIPT_DIR / "run-binding-production-lifecycle.py"
).read_text(encoding="utf-8")
phase2 = (
    ROOT / "docs/CODE_WORKFLOW_PHASE2.md"
).read_text(encoding="utf-8")
workflow = (
    ROOT / ".github/workflows/code-workflow-acceptance.yml"
).read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


for token in (
    "readonly property bool bindingPreparationBusy:",
    "readonly property bool bindingLifecycleBusy:",
    "readonly property var activeBindingPreparation:",
    "readonly property bool bindingArtifactsReady:",
    "readonly property var activeBindingAuthorization:",
    "readonly property bool bindingAuthorizationReady:",
    "readonly property bool bindingPrepareEnabled:",
    "readonly property bool bindingAuthorizeEnabled:",
    "readonly property bool bindingApplyEnabled:",
    'String(root.activeCommand?.reviewedReplacementId ?? "")',
    '=== "clock.text.time-to-date"',
    '=== "bar/clock"',
    '=== "modules/bar/ClockWidget.qml"',
    "function prepareBindingArtifacts(): bool",
    "function finishBindingPreparation(exitCode: int): void",
    "function authorizeBindingWrite(): bool",
    "function revokeBindingAuthorization(",
    "function beginAuthorizedBindingApply(): bool",
    "function beginBindingLifecycle(): bool",
    "function finishBindingCommit(exitCode: int): void",
    "function finishBindingVerify(exitCode: int): void",
    "function _beginBindingPostconditionCheck(): void",
    "function _finishBindingPostconditionIfReady(): void",
    'CodeWorkflowAnalyzer.semanticRebind?.status === "resolved"',
    'CodeWorkflowAnalyzer.semanticRebind?.semanticValueText',
    '=== "DateTime.date"',
    "function _startBindingRollback(reason: string): void",
    "function _finalizeBindingRollback(payload): void",
    "function _recoverBindingLifecycle(): void",
    '"explicit-binding-write-authorization-v1"',
    '"semantic-anchor-rebound-exact-expression"',
    '"exact-snapshot-auto-rollback-v1"',
    'Quickshell.shellPath(\n                "scripts/code-workflow/binding_prepare.py")',
    'Quickshell.shellPath(\n                "scripts/code-workflow/binding_commit.py")',
):
    if token not in transaction:
        fail("2K-U-B transaction boundary missing " + token)

# Reload completion and reload failure are separate lifecycle branches. Keep
# Binding failure handling inside _handleReloadFailed so a duplicate lexical
# declaration cannot make the singleton fail QML construction at shell startup.
reload_completed_start = transaction.find("function _handleReloadCompleted(): void")
reload_failed_start = transaction.find(
    "function _handleReloadFailed(errorString: string): void",
    reload_completed_start,
)
clear_presentation_start = transaction.find(
    "function _clearPresentation(): void",
    reload_failed_start,
)
if min(reload_completed_start, reload_failed_start, clear_presentation_start) < 0:
    fail("Binding reload lifecycle handlers are missing")
reload_completed_block = transaction[
    reload_completed_start:reload_failed_start
]
reload_failed_block = transaction[
    reload_failed_start:clear_presentation_start
]
if reload_completed_block.count(
    "const bindingPhase = reloadState.pendingBindingPhase"
) != 1:
    fail("_handleReloadCompleted must declare bindingPhase exactly once")
if "pendingBindingReloadOutcome = \"failed\"" in reload_completed_block:
    fail("Binding reload failure handling leaked into _handleReloadCompleted")
if reload_failed_block.count(
    "const bindingPhase = reloadState.pendingBindingPhase"
) != 1:
    fail("_handleReloadFailed must declare bindingPhase exactly once")
for token in (
    'pendingBindingReloadOutcome = "failed"',
    "pendingBindingError = message",
    "root._startBindingRollback(message)",
    '"binding-rollback-failed"',
):
    if token not in reload_failed_block:
        fail("Binding reload failure branch missing " + token)

postcondition_start = transaction.find(
    "function _beginBindingPostconditionCheck(): void"
)
postcondition_end = transaction.find(
    "function _finishBindingPostconditionIfReady(): void",
    postcondition_start,
)
if postcondition_start < 0 or postcondition_end < 0:
    fail("2K-U-B Binding postcondition block is missing")
postcondition_block = transaction[
    postcondition_start:postcondition_end
]
if '"text: DateTime.date"' in postcondition_block:
    fail(
        "Binding postcondition must not use duplicate-prone replacement needle"
    )
if (
    'reloadState.pendingBindingSourcePath,\n            "",\n'
    '            reloadState.pendingBindingSemanticAnchor'
    not in postcondition_block
):
    fail("Binding postcondition must request exact anchor without a source needle")

# Binding authorization must be replacement-specific and must not copy Connect
# proof vocabulary into its authorization snapshot block.
auth_start = transaction.find("function authorizeBindingWrite(): bool")
auth_end = transaction.find("function revokeBindingAuthorization(", auth_start)
if auth_start < 0 or auth_end < 0:
    fail("2K-U-B Binding authorization block is missing")
auth_block = transaction[auth_start:auth_end]
for forbidden in (
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "typeCompatibility",
    "cycleStatus",
):
    if forbidden in auth_block:
        fail("Binding authorization inherited Connect proof field: " + forbidden)

for token in (
    "function previewBinding(nextValue: string): void",
    "CodeWorkflowSession.subflowTargetId",
    "readonly property string bindingLifecyclePhaseText:",
    '"VERIFYING EXACT REBIND"',
    '"Prepare Binding artifacts"',
    '"Authorize Binding write"',
    '"Apply Binding replacement"',
    '"Revoke Binding authorization"',
    "CodeWorkflowTransaction.prepareBindingArtifacts()",
    "CodeWorkflowTransaction.authorizeBindingWrite()",
    "CodeWorkflowTransaction.beginAuthorizedBindingApply()",
    "CodeWorkflowTransaction.revokeBindingAuthorization(",
    '"DISCONNECT APPLY READY"',
    '"DISCONNECT APPLIED"',
    '"DISCONNECT ROLLED BACK"',
    '"Binding identity · "',
    "postcondition SAME ANCHOR + EXACT EXPRESSION",
    "no TYPE/CYCLE proof is used for Binding replacement",
):
    if token not in page:
        fail("2K-U-B Settings boundary missing " + token)

if "binding_prepare.py" in page or "binding_commit.py" in page:
    fail("Settings must never invoke Binding Python helpers directly")
if "CodeWorkflowTransaction.beginBindingLifecycle()" in page:
    fail("Settings must use authorized Binding Apply wrapper only")

for token in (
    "connectApplyEnabled:",
    "bindingPreparationBusy:",
    "bindingArtifactsReady:",
    "bindingLifecycleBusy:",
    "pendingBindingPhase:",
    "bindingAuthorizationReady:",
    "bindingAuthorizeEnabled:",
    "bindingApplyEnabled:",
    "activeBindingAuthorization:",
    "activeBindingPreparation:",
    "function workflowBindingAnalyze(): void",
    "function workflowBindingAnalyzeBullet(): void",
    "function workflowBindingPreview(): bool",
    "function workflowBindingPrepare(): bool",
    "function workflowBindingAuthorize(): bool",
    "function workflowBindingRevoke(): bool",
    "function workflowBindingApply(): bool",
    "function workflowBindingOverridePreparedAnchor(",
):
    if token not in probe:
        fail("2K-U-B ProbeShell instrumentation missing " + token)

for token in (
    'ARTIFACT_PROOF = "prepared-reviewed-binding-replacement-artifacts-v1"',
    'POSTCONDITION = "semantic-anchor-rebound-exact-expression"',
    '"clock.text.time-to-date": {',
    '"propertyName": "text"',
    '"expectedCurrent": "DateTime.timeDisplay"',
):
    if token not in prepare:
        fail("2K-U-B Binding preparation contract missing " + token)

for token in (
    "def commit_binding(",
    "def verify_binding(",
    "def rollback_binding(",
    '"candidate-present"',
    '"base-present"',
    '"prepared binding manifest hash mismatch"',
):
    if token not in commit:
        fail("2K-U-B Binding engine contract missing " + token)

for forbidden in (
    "connect_type",
    "connect_cycle",
    "connect_qualify",
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
):
    if forbidden in prepare or forbidden in commit:
        fail("Binding helper inherited Connect proof stack: " + forbidden)

for token in (
    "def run_success(",
    "def run_postcondition_failure(",
    '"workflowBindingApply"',
    '"binding-applied"',
    '"binding-rollback-complete"',
    '"binding-rolled-back"',
    '"semanticRebind"]',
    '"resolved"',
    '"DateTime.date"',
    '"ProbeShell could not align Binding postcondition fixture"',
):
    if token not in harness:
        fail("2K-U-B live Binding harness missing " + token)

excluded = set(exclusions.get("excludedPaths", []))
for helper in (
    "scripts/code-workflow/binding_prepare.py",
    "scripts/code-workflow/binding_commit.py",
):
    if helper in excluded:
        fail("2K-U-B production helper is still runtime-excluded: " + helper)
if "scripts/code-workflow/run-binding-production-lifecycle.py" not in excluded:
    fail("2K-U-B live harness must remain outside runtime payload")

runtime_payload = subprocess.run(
    [
        sys.executable,
        str(ROOT / "sdata/lib/runtime-payload.py"),
        "list",
        "--root",
        str(ROOT),
    ],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
runtime_set = set(runtime_payload)
for helper in (
    "scripts/code-workflow/binding_prepare.py",
    "scripts/code-workflow/binding_commit.py",
):
    if helper not in runtime_set:
        fail("2K-U-B production helper missing from runtime payload: " + helper)
if "scripts/code-workflow/run-binding-production-lifecycle.py" in runtime_set:
    fail("2K-U-B live harness leaked into runtime payload")

for token in (
    "Milestone 2K-U-B — reviewed direct-binding replacement production lifecycle",
    "explicit-binding-write-authorization-v1",
    "semantic-anchor-rebound-exact-expression",
    "Apply Binding replacement",
    "no Connect qualification",
    "clock.text.time-to-date",
    "Other direct-binding previews remain non-writing",
):
    if token not in phase2:
        fail("2K-U-B documentation missing " + token)

for token in (
    "Validate reviewed Binding replacement production lifecycle",
    "test-code-workflow-binding-production-lifecycle.py",
    "Run isolated reviewed Binding replacement production lifecycle",
    "run-binding-production-lifecycle.py",
    "binding-production-lifecycle-report.json",
):
    if token not in workflow:
        fail("2K-U-B acceptance workflow missing " + token)

for token in (
    '"clock.text.time-to-date"',
    '"DateTime.timeDisplay"',
    '"DateTime.date"',
    '"semantic-anchor-rebound-exact-expression"',
    '"explicit-binding-write-authorization-v1"',
):
    if token not in transaction and token not in prepare:
        fail("2K-U-B exact replacement invariant missing " + token)

if '"direct-binding"' not in transaction:
    fail("2K-U-B must promote direct-binding, not a renamed Disconnect kind")
if "semanticRebind?.status === \"resolved\"" not in transaction:
    fail("2K-U-B success must require resolved semantic rebind")
if (
    'semanticRebind?.semanticValueText ?? "")\n'
    '                === "DateTime.date"'
    not in transaction
):
    fail(
        "2K-U-B success must require exact replacement expression "
        "from the rebound semantic anchor"
    )

print("ok - Code Workflow 2K-U-B reviewed direct-binding replacement production lifecycle")
