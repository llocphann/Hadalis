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
commit_helper = (
    SCRIPT_DIR / "connect_commit.py"
).read_text(encoding="utf-8")
probe = (
    SCRIPT_DIR / "runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
harness = (
    SCRIPT_DIR / "run-connect-production-lifecycle.py"
).read_text(
    encoding="utf-8"
)
page = (
    ROOT / "modules/settings/CodeWorkflow.qml"
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
    "property var connectLifecycleResult:",
    "property string connectLifecycleError:",
    "readonly property bool connectLifecycleBusy:",
    "readonly property string pendingConnectPhase:",
    "function _connectLifecycleCommandMatchesHandoff(): bool",
    "function stageConnectLifecycleHandoff(): bool",
    "function clearConnectLifecycleHandoff(): void",
    "function _connectPayloadMatchesPending(payload): bool",
    "function beginConnectLifecycle(): bool",
    "function finishConnectCommit(exitCode: int): void",
    "function _startConnectCandidateVerify(): void",
    "function finishConnectVerify(exitCode: int): void",
    "function _beginConnectSemanticRebind(): void",
    "function _finishConnectSemanticRebindIfReady(): void",
    "function _startConnectRollback(reason: string): void",
    "function finishConnectRollback(exitCode: int): void",
    "function _recoverConnectLifecycle(): void",
    "connectRollbackReloadFallbackTimer",
    'Quickshell.reload(false)',
    '"scripts/code-workflow/connect_commit.py"',
    '"candidate-verify-issued"',
    '"rollback-waiting-reload"',
    '"explicit-recovery"',
):
    if token not in transaction:
        fail("2K-Q production Connect lifecycle missing " + token)

for token in (
    "pendingConnectPhase:",
    "pendingConnectManifestPath:",
    "pendingConnectInsertedSemanticAnchor:",
    "pendingConnectExternalSourcePath:",
    "pendingConnectExternalSourceSha256:",
    "pendingConnectRollbackRecovery:",
):
    if token not in transaction:
        fail("2K-Q reload persistence missing " + token)

for token in (
    '"manifestPath": str(manifest_path.expanduser().resolve())',
    '"dependency-drift-after-write"',
    '"external-source-sha-mismatch-before-write"',
    "def commit_connect_prepared(",
    "def verify_connect_prepared(",
    "def rollback_connect_prepared(",
):
    if token not in commit_helper:
        fail("2K-Q runtime Connect engine contract missing " + token)

for token in (
    "connectLifecycleBusy:",
    "pendingConnectPhase:",
    "connectLifecycleError:",
    "connectLifecycleResult:",
    "function workflowConnectBeginLifecycle(): bool",
    "function workflowConnectOverridePreparedAnchor(",
):
    if token not in probe:
        fail("2K-Q ProbeShell instrumentation missing " + token)

for token in (
    "def run_success(",
    "def run_automatic_rebind_rollback(",
    '"workflowConnectBeginLifecycle"',
    '"workflowConnectOverridePreparedAnchor"',
    '"connect-applied"',
    '"connect-rollback-complete"',
    '"connect-rolled-back"',
    '"explicit-recovery"',
    "run-connect-lifecycle.py",
):
    if token not in harness:
        fail("2K-Q live production lifecycle harness missing " + token)

for forbidden in (
    "Connect Apply",
    "Apply Connect",
    "beginConnectApply",
):
    if forbidden in page:
        fail("2K-Q must not expose user-facing Connect Apply: " + forbidden)

# The historical literal Apply pipeline remains independently scoped.
for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-Q must preserve literal Apply isolation: " + token)

if "scripts/code-workflow/connect_commit.py" in exclusions.get(
        "excludedPaths", []):
    fail("2K-Q production Connect commit engine must ship in runtime payload")
for path in (
    "scripts/code-workflow/run-connect-lifecycle.py",
    "scripts/code-workflow/run-connect-production-lifecycle.py",
):
    if path not in exclusions.get("excludedPaths", []):
        fail("live lifecycle harness must remain outside runtime payload: " + path)

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
    fail("2K-Q production Connect commit engine missing from runtime payload")
for path in (
    "scripts/code-workflow/run-connect-lifecycle.py",
    "scripts/code-workflow/run-connect-production-lifecycle.py",
):
    if path in runtime_set:
        fail("live lifecycle harness leaked into runtime payload: " + path)

for token in (
    "Milestone 2K-Q — production internal Connect lifecycle integration",
    "beginConnectLifecycle()",
    "watcher-driven reload",
    "automatically invokes exact rollback",
    "explicit reload fallback",
    "user-facing Connect Apply remains unavailable",
):
    if token not in phase2:
        fail("2K-Q documentation missing " + token)

for token in (
    "Integrate production internal Connect lifecycle",
    "run-connect-production-lifecycle.py",
    "connect-production-lifecycle-report.json",
):
    if token not in workflow:
        fail("2K-Q acceptance workflow missing " + token)

print("ok - Code Workflow 2K-Q production internal Connect lifecycle integration")
