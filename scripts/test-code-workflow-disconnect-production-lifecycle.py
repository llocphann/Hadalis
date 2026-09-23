#!/usr/bin/env python3
import ast
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
    SCRIPT_DIR / "disconnect_prepare.py"
).read_text(encoding="utf-8")
commit = (
    SCRIPT_DIR / "disconnect_commit.py"
).read_text(encoding="utf-8")
harness = (
    SCRIPT_DIR / "run-disconnect-production-lifecycle.py"
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


def literal_assignment(source: str, name: str):
    tree = ast.parse(source)
    for node in tree.body:
        if isinstance(node, ast.Assign):
            if any(
                isinstance(target, ast.Name) and target.id == name
                for target in node.targets
            ):
                return ast.literal_eval(node.value)
        elif (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.target.id == name
        ):
            return ast.literal_eval(node.value)
    fail("missing literal assignment " + name)


expected_reviewed_targets = {
    "clock.data.time": {
        "graphTargetId": "bar/clock",
        "sourcePath": "modules/bar/ClockWidget.qml",
        "propertyName": "text",
        "expectedCurrent": "DateTime.timeDisplay",
        "resultingState": "unbound/default",
    },
    "clock.data.date": {
        "graphTargetId": "bar/clock",
        "sourcePath": "modules/bar/ClockWidget.qml",
        "propertyName": "text",
        "expectedCurrent": "DateTime.date",
        "resultingState": "unbound/default",
    },
}
if literal_assignment(prepare, "REVIEWED_TARGETS") != expected_reviewed_targets:
    fail("2K-T-C production Disconnect allowlist must remain exactly two reviewed Clock edges")

expected_harness_targets = {
    "clock.data.time": {
        "expectedCurrent": "DateTime.timeDisplay",
        "otherEdgeId": "clock.data.date",
        "otherExpectedCurrent": "DateTime.date",
    },
    "clock.data.date": {
        "expectedCurrent": "DateTime.date",
        "otherEdgeId": "clock.data.time",
        "otherExpectedCurrent": "DateTime.timeDisplay",
    },
}
if literal_assignment(harness, "DISCONNECT_TARGETS") != expected_harness_targets:
    fail("2K-T-C live acceptance must cover exactly the two production Disconnect targets")

for source_name, source, function_indent in (
    ("transaction", transaction, "    "),
    ("probe", probe, "        "),
):
    start = source.find("function reviewedDisconnectTarget(edgeId: string): var")
    end = source.find("\n" + function_indent + "function ", start + 1)
    if start < 0 or end < 0:
        fail("2K-T-C " + source_name + " reviewed Disconnect resolver is missing")
    resolver = source[start:end]
    if resolver.count('if (id === "') != 2:
        fail("2K-T-C " + source_name + " resolver widened beyond two exact targets")
    for target_id in ("clock.data.time", "clock.data.date"):
        if ('id === "' + target_id + '"') not in resolver:
            fail("2K-T-C " + source_name + " resolver missing " + target_id)
    if "return null" not in resolver:
        fail("2K-T-C " + source_name + " resolver must fail closed")


for token in (
    "readonly property bool disconnectPreparationBusy:",
    "readonly property bool disconnectLifecycleBusy:",
    "readonly property var activeDisconnectPreparation:",
    "readonly property bool disconnectArtifactsReady:",
    "readonly property var activeDisconnectAuthorization:",
    "readonly property bool disconnectAuthorizationReady:",
    "readonly property bool disconnectPrepareEnabled:",
    "readonly property bool disconnectAuthorizeEnabled:",
    "readonly property bool disconnectApplyEnabled:",
    "function reviewedDisconnectTarget(edgeId: string): var",
    'id === "clock.data.time"',
    'id === "clock.data.date"',
    'graphTargetId: "bar/clock"',
    'sourcePath: "modules/bar/ClockWidget.qml"',
    'expectedCurrent: "DateTime.timeDisplay"',
    'expectedCurrent: "DateTime.date"',
    "function reviewedDisconnectCommandMatches(command): bool",
    "function prepareDisconnectArtifacts(): bool",
    "function finishDisconnectPreparation(exitCode: int): void",
    "function authorizeDisconnectWrite(): bool",
    "function revokeDisconnectAuthorization(",
    "function beginAuthorizedDisconnectApply(): bool",
    "function beginDisconnectLifecycle(): bool",
    "function finishDisconnectCommit(exitCode: int): void",
    "function finishDisconnectVerify(exitCode: int): void",
    "function _beginDisconnectPostconditionCheck(): void",
    "function _finishDisconnectPostconditionIfReady(): void",
    'CodeWorkflowAnalyzer.semanticRebind?.status === "missing"',
    "function _startDisconnectRollback(reason: string): void",
    "function _finalizeDisconnectRollback(payload): void",
    "function _recoverDisconnectLifecycle(): void",
    '"explicit-disconnect-write-authorization-v1"',
    '"semantic-anchor-missing"',
    '"exact-snapshot-auto-rollback-v1"',
    'Quickshell.shellPath(\n                "scripts/code-workflow/disconnect_prepare.py")',
    'Quickshell.shellPath(\n                "scripts/code-workflow/disconnect_commit.py")',
):
    if token not in transaction:
        fail("2K-T-B transaction boundary missing " + token)

# Disconnect authorization must be deletion-specific and must not copy Connect
# proof vocabulary into its authorization snapshot block.
auth_start = transaction.find("function authorizeDisconnectWrite(): bool")
auth_end = transaction.find("function revokeDisconnectAuthorization(", auth_start)
if auth_start < 0 or auth_end < 0:
    fail("2K-T-B Disconnect authorization block is missing")
auth_block = transaction[auth_start:auth_end]
for forbidden in (
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "typeCompatibility",
    "cycleStatus",
):
    if forbidden in auth_block:
        fail("Disconnect authorization inherited Connect proof field: " + forbidden)

for token in (
    "function previewSelectedEdgeDisconnect(): void",
    "CodeWorkflowSession.subflowTargetId",
    'String(root.selectedIrEdge?.id ?? "")',
    "readonly property string disconnectLifecyclePhaseText:",
    '"VERIFYING BINDING ABSENCE"',
    '"Prepare Disconnect artifacts"',
    '"Authorize Disconnect write"',
    '"Apply Disconnect"',
    '"Revoke Disconnect authorization"',
    "CodeWorkflowTransaction.prepareDisconnectArtifacts()",
    "CodeWorkflowTransaction.authorizeDisconnectWrite()",
    "CodeWorkflowTransaction.beginAuthorizedDisconnectApply()",
    "CodeWorkflowTransaction.revokeDisconnectAuthorization(",
    '"DISCONNECT APPLY READY"',
    '"DISCONNECT APPLIED"',
    '"DISCONNECT ROLLED BACK"',
    '"Disconnect identity · "',
    "postcondition OLD ANCHOR MISSING",
    "no TYPE/CYCLE proof is used for Disconnect",
):
    if token not in page:
        fail("2K-T-B Settings boundary missing " + token)

if "disconnect_prepare.py" in page or "disconnect_commit.py" in page:
    fail("Settings must never invoke Disconnect Python helpers directly")
if "CodeWorkflowTransaction.beginDisconnectLifecycle()" in page:
    fail("Settings must use authorized Disconnect Apply wrapper only")

for token in (
    "connectApplyEnabled:",
    "disconnectPreparationBusy:",
    "disconnectArtifactsReady:",
    "disconnectLifecycleBusy:",
    "pendingDisconnectPhase:",
    "disconnectAuthorizationReady:",
    "disconnectAuthorizeEnabled:",
    "disconnectApplyEnabled:",
    "activeDisconnectAuthorization:",
    "activeDisconnectPreparation:",
    "function reviewedDisconnectTarget(edgeId: string): var",
    "function workflowDisconnectAnalyzeEdge(edgeId: string): bool",
    "function workflowDisconnectAnalyze(): void",
    "function workflowDisconnectAnalyzeDate(): void",
    "function workflowDisconnectPreviewEdge(edgeId: string): bool",
    "function workflowDisconnectPreview(): bool",
    "activeCommandReviewedEdgeId:",
    "function workflowDisconnectPrepare(): bool",
    "function workflowDisconnectAuthorize(): bool",
    "function workflowDisconnectRevoke(): bool",
    "function workflowDisconnectApply(): bool",
    "function workflowDisconnectOverridePreparedAnchor(",
):
    if token not in probe:
        fail("2K-T-B ProbeShell instrumentation missing " + token)

for token in (
    'ARTIFACT_PROOF = "prepared-reviewed-disconnect-artifacts-v1"',
    'POSTCONDITION = "semantic-anchor-missing"',
    '"clock.data.time": {',
    '"clock.data.date": {',
    '"propertyName": "text"',
    '"expectedCurrent": "DateTime.timeDisplay"',
    '"expectedCurrent": "DateTime.date"',
):
    if token not in prepare:
        fail("2K-T-B Disconnect preparation contract missing " + token)

for token in (
    "def commit_disconnect(",
    "def verify_disconnect(",
    "def rollback_disconnect(",
    '"candidate-present"',
    '"base-present"',
    '"prepared Disconnect manifest hash mismatch"',
):
    if token not in commit:
        fail("2K-T-B Disconnect engine contract missing " + token)

for forbidden in (
    "connect_type",
    "connect_cycle",
    "connect_qualify",
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
):
    if forbidden in prepare or forbidden in commit:
        fail("Disconnect helper inherited Connect proof stack: " + forbidden)

for token in (
    "def run_success(",
    "def run_postcondition_failure(",
    '"workflowDisconnectApply"',
    '"disconnect-applied"',
    '"disconnect-rollback-complete"',
    '"disconnect-rolled-back"',
    '"semanticRebind"]',
    '"missing"',
    "DISCONNECT_TARGETS = {",
    '"clock.data.time"',
    '"clock.data.date"',
    '"DateTime.timeDisplay"',
    '"DateTime.date"',
    '"workflowDisconnectAnalyzeEdge"',
    '"workflowDisconnectPreviewEdge"',
    '"ProbeShell could not align Disconnect postcondition fixture for {edge_id}"',
):
    if token not in harness:
        fail("2K-T-B live Disconnect harness missing " + token)

excluded = set(exclusions.get("excludedPaths", []))
for helper in (
    "scripts/code-workflow/disconnect_prepare.py",
    "scripts/code-workflow/disconnect_commit.py",
):
    if helper in excluded:
        fail("2K-T-B production helper is still runtime-excluded: " + helper)
if "scripts/code-workflow/run-disconnect-production-lifecycle.py" not in excluded:
    fail("2K-T-B live harness must remain outside runtime payload")

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
    "scripts/code-workflow/disconnect_prepare.py",
    "scripts/code-workflow/disconnect_commit.py",
):
    if helper not in runtime_set:
        fail("2K-T-B production helper missing from runtime payload: " + helper)
if "scripts/code-workflow/run-disconnect-production-lifecycle.py" in runtime_set:
    fail("2K-T-B live harness leaked into runtime payload")

phase2_compact = " ".join(phase2.split())
for token in (
    "Milestone 2K-T-B — reviewed Disconnect production lifecycle",
    "Milestone 2K-T-C — second exact reviewed Disconnect target",
    "explicit-disconnect-write-authorization-v1",
    "semantic-anchor-missing",
    "Apply Disconnect",
    "no Connect qualification",
    "clock.data.time",
    "clock.data.date",
    "All other Disconnect previews remain non-writing",
):
    if token not in phase2_compact:
        fail("2K-T-C documentation missing " + token)

for token in (
    "Validate reviewed Disconnect production lifecycle",
    "test-code-workflow-disconnect-production-lifecycle.py",
    "Run isolated reviewed Disconnect production lifecycle",
    "run-disconnect-production-lifecycle.py",
    "disconnect-production-lifecycle-report.json",
):
    if token not in workflow:
        fail("2K-T-B acceptance workflow missing " + token)

print("ok - Code Workflow 2K-T-C exact two-target Disconnect production lifecycle")
