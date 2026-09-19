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
    "readonly property bool applyEnabled: false",
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
    '"write path still disabled"',
):
    if token not in page:
        fail("Code Workflow pre-Apply diagnostics UI missing " + token)

for forbidden in (
    "Apply workflow",
    "onClicked: CodeWorkflowTransaction.apply",
    "CodeWorkflowTransaction.applyEnabled",
):
    if forbidden in page:
        fail("pre-Apply milestone must not expose a write action: " + forbidden)

for forbidden in ("FileView {", "setText(", "writeAdapter(", "atomicWrites"):
    if forbidden in service:
        fail("pre-Apply service must remain non-writing: " + forbidden)

if "READY means the" not in phase2 or "does not enable" not in phase2:
    fail("Phase 2 status must distinguish readiness from Apply authorization")

print("ok - Code Workflow pre-Apply diagnostics gate contract")
