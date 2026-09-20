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
harness = (
    SCRIPT_DIR / "run-connect-user-apply.py"
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
    "readonly property bool connectApplyEnabled:",
    "function beginAuthorizedConnectApply(): bool",
    "if (!root.connectApplyEnabled)",
    "root.activeConnectAuthorization?.authorizationToken",
    "if (!root.beginConnectLifecycle())",
    'status: "consumed"',
    'reason: "connect-apply-started"',
    "function beginConnectLifecycle(): bool",
    'if (!root.connectAuthorizationReady',
):
    if token not in transaction:
        fail("2K-S transaction Apply boundary missing " + token)

# User-facing Connect Apply must not merge with the historical literal Apply.
for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    "readonly property bool applyEnabled:",
    "function beginApplyLifecycle(): bool",
):
    if token not in transaction:
        fail("2K-S must preserve independent literal Apply pipeline: " + token)

for token in (
    'mainText: "Apply Connect"',
    "enabled: CodeWorkflowTransaction.connectApplyEnabled",
    "CodeWorkflowTransaction.beginAuthorizedConnectApply()",
    '"CONNECT APPLY READY"',
    '"CONNECT APPLIED"',
    '"CONNECT ROLLED BACK"',
    '"CONNECT APPLY · "',
    '"WRITING SOURCE"',
    '"WAITING FOR RELOAD"',
    '"VERIFYING CANDIDATE"',
    '"REBINDING SEMANTIC ANCHOR"',
    '"RESTORING SNAPSHOT"',
    '"VERIFYING ROLLBACK"',
    '"Connect Apply lifecycle · "',
    "mutation/history/preparation controls are locked",
    '"Connect Apply complete · candidate verified',
    '"Connect Apply rolled back · exact base snapshot verified',
):
    if token not in page:
        fail("2K-S user-facing Apply UI missing " + token)

if "CodeWorkflowTransaction.beginConnectLifecycle()" in page:
    fail("Settings must never bypass the authorized Connect Apply wrapper")
if "connect_commit.py" in page:
    fail("Settings must never invoke the Connect commit engine directly")

for token in (
    "&& !CodeWorkflowTransaction.connectLifecycleBusy",
    "enabled: CodeWorkflowTransaction.canUndo",
    "enabled: CodeWorkflowTransaction.canRedo",
    "enabled: CodeWorkflowTransaction.connectPrepareEnabled",
):
    if token not in page:
        fail("2K-S lifecycle control lock missing " + token)

for token in (
    "connectApplyEnabled:",
    "function workflowConnectApply(): bool",
    "CodeWorkflowTransaction.beginAuthorizedConnectApply()",
    "function workflowConnectBeginLifecycle(): bool",
):
    if token not in probe:
        fail("2K-S ProbeShell boundary missing " + token)

for token in (
    "def run_user_apply_success(",
    "def run_user_apply_rollback(",
    '"workflowConnectApply"',
    '"workflowConnectAuthorize"',
    '"connectApplyEnabled"',
    '"connect-applied"',
    '"connect-rollback-complete"',
    '"connect-rolled-back"',
    '"2K-S Connect Apply was not exactly-once"',
    '"2K-S forced-failure Apply accepted a duplicate start"',
):
    if token not in harness:
        fail("2K-S live user Apply harness missing " + token)

if "scripts/code-workflow/run-connect-user-apply.py" not in exclusions.get(
        "excludedPaths", []):
    fail("2K-S live user Apply harness must remain outside runtime payload")

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
if "scripts/code-workflow/run-connect-user-apply.py" in set(runtime_payload):
    fail("2K-S live user Apply harness leaked into runtime payload")

for token in (
    "Milestone 2K-S — user-facing authorized Connect Apply",
    "beginAuthorizedConnectApply()",
    "CONNECT APPLY READY",
    "exactly once",
    "automatic rollback",
    "production TYPE/CYCLE remain UNKNOWN",
    "Direct binding and Disconnect remain preview-only",
):
    if token not in phase2:
        fail("2K-S documentation missing " + token)

for token in (
    "Validate user-facing Connect Apply boundary",
    "test-code-workflow-connect-apply.py",
    "Run isolated user-facing Connect Apply acceptance",
    "run-connect-user-apply.py",
    "connect-user-apply-report.json",
):
    if token not in workflow:
        fail("2K-S acceptance workflow missing " + token)

print("ok - Code Workflow 2K-S user-facing authorized Connect Apply")
