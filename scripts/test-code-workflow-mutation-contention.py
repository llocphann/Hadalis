#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROBE = (
    ROOT / "scripts/code-workflow/runtime/ProbeShell.qml"
).read_text(encoding="utf-8")
HARNESS = (
    ROOT / "scripts/code-workflow/run-mutation-contention.py"
).read_text(encoding="utf-8")
WORKFLOW = (
    ROOT / ".github/workflows/code-workflow-acceptance.yml"
).read_text(encoding="utf-8")
PHASE2 = (
    ROOT / "docs/CODE_WORKFLOW_PHASE2.md"
).read_text(encoding="utf-8")
EXCLUSIONS = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


for token in (
    'property string mutationContentionJson: "{}"',
    "historySummary: CodeWorkflowTransaction.history.map(",
    "function workflowTestSelectHistoryIndex(index: int): bool",
    "function workflowTestSetHistoryIndexQuiet(index: int): bool",
    "function workflowContentionStartBindingAgainstAll(",
    "CodeWorkflowTransaction.beginAuthorizedBindingApply()",
    "beginDisconnectLifecycle()",
    "CodeWorkflowTransaction.beginConnectLifecycle()",
    "CodeWorkflowTransaction.beginApplyLifecycle()",
    "state.mutationContentionJson = JSON.stringify(evidence)",
):
    if token not in PROBE:
        fail("2K-V-B ProbeShell contract missing " + token)

for token in (
    'CONTENTION_DISCONNECT_EDGE_ID = "clock.data.time"',
    "disconnect.prepare_disconnect(",
    "probe, clock_path, CONTENTION_DISCONNECT_EDGE_ID",
    "def prepare_four_pipelines(",
    "def force_binding_postcondition_failure(",
    "def authorize_siblings_and_owner(",
    "def run_contention(",
    '"workflowContentionStartBindingAgainstAll"',
    '"binding-rollback-complete"',
    '"binding-rolled-back"',
    '"base-present"',
    '"disconnectPreparationStatus"',
    '"connectSafetyFreshness"',
    '"connectPreparationStatus"',
    '"sourceBeforeSha256"',
    '"sourceBeforeBytes"',
    'prepared_report.pop("sourceBefore", None)',
    "mutation-contention-report.json",
):
    if token not in HARNESS:
        fail("2K-V-B live harness missing " + token)

for token in (
    "Validate cross-pipeline mutation contention harness",
    "test-code-workflow-mutation-contention.py",
    "Run cross-pipeline mutation contention acceptance",
    "run-mutation-contention.py",
    "mutation-contention-report.json",
):
    if token not in WORKFLOW:
        fail("2K-V-B acceptance workflow missing " + token)

for token in (
    "Milestone 2K-V-B — live cross-pipeline mutation contention",
    "all four mutation pipelines",
    "same-source Connect and Disconnect sibling",
    "exact Binding rollback identity",
    "No mutation allowlist",
):
    if token not in PHASE2:
        fail("2K-V-B documentation missing " + token)

excluded = set(EXCLUSIONS.get("excludedPaths", []))
if "scripts/code-workflow/run-mutation-contention.py" not in excluded:
    fail("2K-V-B live harness must remain outside runtime payload")

print("ok - Code Workflow 2K-V-B live mutation contention contract")
