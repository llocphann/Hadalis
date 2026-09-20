#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

driver = (ROOT / "scripts/code-workflow/run-apply-lifecycle.py").read_text(
    encoding="utf-8")
probe = (ROOT / "scripts/code-workflow/runtime/ProbeShell.qml").read_text(
    encoding="utf-8")
fixture = (ROOT / "scripts/code-workflow/runtime/ApplyTarget.qml").read_text(
    encoding="utf-8")
prepare = (ROOT / "scripts/code-workflow/prepare-runtime.py").read_text(
    encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(
    encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8"))

for token in (
    'property bool applyFlag: false',
    'property int rollbackProbe: 1',
    'property bool conflictProbe: false',
):
    if token not in fixture:
        fail("Apply lifecycle fixture missing " + token)

for token in (
    "ApplyTarget 1.0 ApplyTarget.qml",
    "for path in sorted((HERE / 'runtime').glob('*.qml'))",
):
    if token not in prepare:
        fail("runtime staging does not export the dev-only fixture: " + token)

for token in (
    "import qs.services",
    "ApplyTarget { id: applyTarget }",
    "CodeWorkflowAnalyzer.request(",
    "CodeWorkflowTransaction.previewLiteral(",
    "CodeWorkflowTransaction.evaluatePreApply(",
    "CodeWorkflowTransaction.prepareApplyArtifacts()",
    "CodeWorkflowTransaction.beginApplyLifecycle()",
    "CodeWorkflowTransaction.markSourceChanged(",
):
    if token not in probe:
        fail("probe must control production Workflow services: " + token)

for token in (
    'parser.add_argument("--sway", type=Path, required=True)',
    'parser.add_argument("--grammar", type=Path, required=True)',
    "prepare_module.prepare(work_dir, args.revision)",
    'probe.env["HADALIS_WORKFLOW_GRAMMAR"] = str(grammar)',
    "run_success(probe, target, report)",
    "run_rollback(probe, target, report)",
    "run_external_edit(probe, target, report)",
    'target.resolve().relative_to((work_dir / "config").resolve())',
    "apply-lifecycle-report.json",
):
    if token not in driver:
        fail("acceptance driver missing " + token)

for forbidden in (
    "Quickshell.reload(",
    "/usr/share/quickshell/inir",
    "~/.config/quickshell",
):
    if forbidden in driver:
        fail("acceptance driver must not target installed/live shell: " + forbidden)

if "scripts/code-workflow/run-apply-lifecycle.py" not in exclusions["excludedPaths"]:
    fail("acceptance driver must stay outside the installed runtime payload")

if "beginApplyLifecycle()" in page or 'mainText: "Apply"' in page:
    fail("harness readiness must not enable user-triggered Apply")

for token in (
    "not yet qualified as passing evidence",
    "apply-lifecycle-report.json",
    "No claim of live acceptance",
):
    if token not in phase2:
        fail("Phase 2 status must not confuse harness existence with acceptance")

print("ok - Code Workflow isolated live acceptance harness contract")
