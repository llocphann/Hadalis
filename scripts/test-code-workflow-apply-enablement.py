#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(
    encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8")
transaction = (ROOT / "scripts/code-workflow/transaction.py").read_text(
    encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(
    encoding="utf-8")
evidence = json.loads(
    (
        ROOT
        / "docs/evidence/code-workflow/phase2h-apply-lifecycle-c991631a.json"
    ).read_text(encoding="utf-8")
)

for token in (
    "readonly property bool applyCommandMatchesHandoff:",
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    "root.historyIndex === reloadState.pendingApplyHistoryIndex",
    "root.applyArtifactsReady",
    "root.applyCommandMatchesHandoff",
    "Quickshell.watchFiles",
    "readonly property bool applyEnabled:",
    "root.applyLifecycleReady",
    "function beginApplyLifecycle(): bool",
    "if (!root.applyEnabled)",
):
    if token not in service:
        fail("literal Apply service gate missing " + token)

for token in (
    'mainText: "Prepare Apply"',
    'mainText: "Apply"',
    "visible: CodeWorkflowTransaction.applyArtifactsReady",
    "enabled: CodeWorkflowTransaction.applyEnabled",
    "root.transactionMatchesSelection",
    "CodeWorkflowTransaction.beginApplyLifecycle()",
):
    if token not in page:
        fail("literal Apply two-step UI missing " + token)

if page.index('mainText: "Prepare Apply"') > page.index('mainText: "Apply"'):
    fail("Prepare Apply must remain the first explicit write step")

if 'mainText: "Apply"' in page and "root.transactionMatchesSelection" not in page:
    fail("Apply must be selection-matched in the UI")

for token in (
    'LITERAL_VALUE_KINDS = {"true", "false", "number", "string"}',
    'entry.get("kind") != "property"',
    '"current-value-is-not-supported-literal"',
):
    if token not in transaction:
        fail("first production write subset must remain literal-property only: " + token)

if evidence.get("status") != "passed":
    fail("Gate 2H evidence must pass before Apply enablement")
checks = evidence.get("checks", [])
if len(checks) != 3 or not all(item.get("passed") is True for item in checks):
    fail("Gate 2H must retain all three passing lifecycle checks")

if "Milestone 2I — guarded literal Apply enabled" not in phase2:
    fail("Phase 2 status must document literal Apply enablement")
if "Direct binding transforms remain disabled." not in phase2:
    fail("Phase 2 status must keep broader transforms disabled")

print("ok - Code Workflow guarded literal Apply enablement contract")
