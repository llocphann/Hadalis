#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    "property var preApplyDiagnostics:",
    "readonly property bool preApplyReady:",
    "readonly property bool applyEnabled:",
    "root.applyLifecycleReady",
    "function evaluatePreApply(",
    'blockers.push("no-active-command")',
    'blockers.push("transaction-not-preview")',
    'blockers.push("preview-stale")',
    'blockers.push("analyzer-not-ready")',
    'blockers.push("source-selection-mismatch")',
    'blockers.push("base-sha-mismatch")',
    'blockers.push("semantic-anchor-mismatch")',
    'blockers.push("current-semantic-rebind-unresolved")',
    'blockers.push("parser-diagnostics-present")',
    'blockers.push("candidate-semantic-rebind-unresolved")',
    'blockers.push("candidate-sha-missing")',
    'blockers.push("candidate-noop")',
    'blockers.push("source-read-only")',
    "applyEnabled: false",
):
    if token not in service:
        fail("pre-Apply gate missing " + token)

for token in (
    "function evaluatePreApplyGate(): void",
    "CodeWorkflowTransaction.evaluatePreApply(",
    "CodeWorkflowAnalyzer.diagnostics.length",
    '"PRE-APPLY READY"',
    '"PRE-APPLY BLOCKED"',
    '"Pre-Apply blockers: "',
    '"prepare exact artifacts before Apply is enabled"',
):
    if token not in page:
        fail("Code Workflow pre-Apply diagnostics UI missing " + token)

if "CodeWorkflowTransaction.applyEnabled" not in page:
    fail("Apply UI must consume the later artifact/lifecycle gate, not preApplyReady directly")

for forbidden in ("setText(", "writeAdapter(", "atomicWrites"):
    if forbidden in service:
        fail("pre-Apply service must remain non-writing: " + forbidden)

if "Pre-Apply READY alone does not enable Apply" not in phase2:
    fail("Phase 2 status must distinguish diagnostics readiness from Apply authorization")

print("ok - Code Workflow pre-Apply diagnostics gate contract")
