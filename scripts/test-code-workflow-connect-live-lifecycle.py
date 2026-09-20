#!/usr/bin/env python3
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"

harness = (SCRIPT_DIR / "run-connect-lifecycle.py").read_text(
    encoding="utf-8"
)
probe = (
    SCRIPT_DIR / "runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8"
)
workflow = (
    ROOT / ".github/workflows/code-workflow-acceptance.yml"
).read_text(encoding="utf-8")
phase2 = (
    ROOT / "docs/CODE_WORKFLOW_PHASE2.md"
).read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


for token in (
    "def reset_connect(",
    "def recover_after_rollback(",
    '"explicit-recovery"',
    'probe.ipc("reload")',
    "def prepare_connect(",
    "def run_success(",
    "def run_rebind_failure(",
    "def run_external_dependency_edit(",
    '"workflowConnectPreview"',
    '"workflowConnectPrepare"',
    '"workflowConnectAnalyze"',
    '"connect_commit.py"',
    '"candidate-present"',
    '"semanticRebind"',
    '"resolved"',
    '"external-source-sha-mismatch-before-write"',
    '"sourceWritten") is False',
    '"reloadCompletions"] == 1',
    '"No production Settings Connect Apply action exists."',
):
    if token not in harness:
        fail("2K-P live Connect harness missing " + token)

for token in (
    "activeCommandKind:",
    "connectPreparationCapability:",
    "connectArtifactsReady:",
    "activeConnectSafety:",
    "activeConnectPreparation:",
    "function workflowConnectPreview(): bool",
    "function workflowConnectPrepare(): bool",
    "function workflowConnectAnalyze(anchor: string): void",
    '"bar/clock"',
    '"clock.connect.rootVisible"',
    '"modules/bar/ClockWidget.qml"',
    '"visible: root.showDate"',
):
    if token not in probe:
        fail("2K-P isolated ProbeShell instrumentation missing " + token)

if 'Quickshell.shellPath("scripts/code-workflow/connect_commit.py")' in transaction:
    fail("2K-P must not production-wire research Connect commit engine")
for forbidden in ("Connect Apply", "Apply Connect", "beginConnectApply"):
    if forbidden in page or forbidden in transaction:
        fail("2K-P must not expose user-facing Connect Apply: " + forbidden)

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-P must preserve literal-only production source Apply")

if "scripts/code-workflow/run-connect-lifecycle.py" not in exclusions.get(
        "excludedPaths", []):
    fail("2K-P live harness must remain outside runtime payload")
if "scripts/code-workflow/connect_commit.py" not in exclusions.get(
        "excludedPaths", []):
    fail("2K-P commit engine must remain outside runtime payload")

for token in (
    "Run isolated Connect lifecycle acceptance",
    "run-connect-lifecycle.py",
    "connect-lifecycle-report.json",
):
    if token not in workflow:
        fail("2K-P acceptance workflow missing " + token)

for token in (
    "Milestone 2K-P — live isolated Connect lifecycle acceptance",
    "watcher-driven reload",
    "inserted semantic anchor",
    "external Config edit",
    "user-facing Connect Apply remains unavailable",
):
    if token not in phase2:
        fail("2K-P documentation missing " + token)

print("ok - Code Workflow 2K-P live isolated Connect lifecycle contract")
