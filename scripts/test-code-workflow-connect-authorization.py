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
prepare = (
    SCRIPT_DIR / "connect_prepare.py"
).read_text(encoding="utf-8")
commit = (
    SCRIPT_DIR / "connect_commit.py"
).read_text(encoding="utf-8")
probe = (
    SCRIPT_DIR / "runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
production_harness = (
    SCRIPT_DIR / "run-connect-production-lifecycle.py"
).read_text(encoding="utf-8")
authorization_harness = (
    SCRIPT_DIR / "run-connect-authorization.py"
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
    "property var connectAuthorizationDiagnostics:",
    "readonly property var activeConnectAuthorization:",
    "readonly property bool connectAuthorizationReady:",
    "readonly property bool connectAuthorizeEnabled:",
    "function _connectAuthorizationIdentityMatchesCommand(command): bool",
    "function _connectAuthorizationMatchesCommand(command): bool",
    "function _expireConnectAuthorization(",
    "function _expireAllConnectAuthorizations(",
    "function authorizeConnectWrite(): bool",
    "function revokeConnectAuthorization(",
    '"explicit-connect-write-authorization-v1"',
    '"exact-snapshot-auto-rollback-v1"',
    '"cross-generation-reauthorization-required"',
    '"history-selection-changed"',
    '"preparation-capability-unavailable"',
    '"connect-lifecycle-failed"',
    "pendingConnectAuthorizationToken:",
    "pendingConnectManifestSha256:",
    'if (!root.connectAuthorizationReady',
    '"--manifest-sha256"',
):
    if token not in transaction:
        fail("2K-R transaction authorization boundary missing " + token)

for token in (
    "manifestSha256",
    "sha256(manifest_bytes).hexdigest()",
    '"manifestPath": str(manifest_path)',
):
    if token not in prepare:
        fail("2K-R prepared manifest identity missing " + token)

for token in (
    "expected_manifest_sha256",
    '"prepared Connect manifest hash mismatch"',
    'parser.add_argument("--manifest-sha256"',
    '"manifestSha256": manifest_sha256',
):
    if token not in commit:
        fail("2K-R commit engine manifest binding missing " + token)

for token in (
    '"CONNECT AUTHORIZED · APPLY BLOCKED"',
    '"CONNECT READY · AUTHORIZATION REQUIRED"',
    '"Authorize Connect write"',
    '"Revoke authorization"',
    "CodeWorkflowTransaction.authorizeConnectWrite()",
    "CodeWorkflowTransaction.revokeConnectAuthorization(",
    '"Authorization target · "',
    '"Proof evidence · freshness "',
    '"production TYPE/CYCLE remain UNKNOWN"',
    '"Source identity · "',
    '"Dependency identity · "',
    '"source Apply control is still unavailable"',
):
    if token not in page:
        fail("2K-R authorization UI evidence missing " + token)

for forbidden in (
    "Connect Apply",
    "Apply Connect",
    "beginConnectLifecycle()",
):
    if forbidden in page:
        fail("2K-R Settings must not expose Connect source Apply: " + forbidden)

for token in (
    "connectAuthorizationReady:",
    "connectAuthorizeEnabled:",
    "connectAuthorizationDiagnostics:",
    "activeConnectAuthorization:",
    "function workflowConnectAuthorize(): bool",
    "function workflowConnectRevoke(): bool",
    "function workflowConnectBeginLifecycle(): bool",
    "function workflowUndo(): bool",
    "function workflowRedo(): bool",
    "function workflowConnectOverridePreparedManifestSha(",
):
    if token not in probe:
        fail("2K-R ProbeShell instrumentation missing " + token)

for token in (
    "authorize_connect(probe)",
    '"workflowConnectAuthorize"',
    '"workflowConnectOverridePreparedManifestSha"',
    "manifest_sha = file_sha(manifest_path)",
):
    if token not in production_harness:
        fail("2K-Q lifecycle must pass through 2K-R authorization: " + token)

for token in (
    "def run_prepare_and_revoke(",
    "def run_history_expiration(",
    "def run_external_dependency_expiration(",
    "def run_manifest_drift(",
    '"workflowConnectBeginLifecycle"',
    '"workflowConnectAuthorize"',
    '"workflowConnectRevoke"',
    '"workflowUndo"',
    '"workflowRedo"',
    '"manifest hash mismatch"',
    '"connect-commit-failed"',
    '"Settings exposes authorization/revoke only; no Connect Apply."',
):
    if token not in authorization_harness:
        fail("2K-R live authorization harness missing " + token)

# Authorization must not broaden the historical literal Apply control.
for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-R must preserve literal Apply isolation: " + token)

if "scripts/code-workflow/connect_commit.py" in exclusions.get(
        "excludedPaths", []):
    fail("2K-R production Connect engine must remain in runtime payload")
if "scripts/code-workflow/run-connect-authorization.py" not in exclusions.get(
        "excludedPaths", []):
    fail("2K-R live harness must remain outside runtime payload")

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
if "scripts/code-workflow/connect_commit.py" not in runtime_set:
    fail("2K-R production Connect engine missing from runtime payload")
if "scripts/code-workflow/run-connect-authorization.py" in runtime_set:
    fail("2K-R acceptance harness leaked into runtime payload")

for token in (
    "Milestone 2K-R — explicit Connect write authorization boundary",
    "explicit-connect-write-authorization-v1",
    "manifest SHA-256",
    "Authorize Connect write",
    "production TYPE/CYCLE remain UNKNOWN",
    "Authorization expires",
    "user-facing Connect Apply remains unavailable",
):
    if token not in phase2:
        fail("2K-R documentation missing " + token)

for token in (
    "Validate explicit Connect authorization boundary",
    "test-code-workflow-connect-authorization.py",
    "Run isolated Connect authorization acceptance",
    "run-connect-authorization.py",
    "connect-authorization-report.json",
):
    if token not in workflow:
        fail("2K-R acceptance workflow missing " + token)

print("ok - Code Workflow 2K-R explicit Connect authorization boundary")
