#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    "readonly property bool applyLifecycleBusy:",
    "readonly property bool applyLifecycleReady:",
    "function beginApplyLifecycle(): bool",
    'reloadState.pendingApplyPhase = "write-issued"',
    'Quickshell.shellPath("scripts/code-workflow/commit.py")',
    '"commit",',
    '"verify",',
    '"rollback",',
    "function _handleReloadCompleted(): void",
    "function _handleReloadFailed(errorString: string): void",
    "function _recoverApplyLifecycle(): void",
    "function _startCandidateVerify(): void",
    "function _beginSemanticRebind(): void",
    "CodeWorkflowAnalyzer.request(",
    "function _startRollback(reason: string): void",
    "function _startRollbackVerify(): void",
    'reloadState.pendingApplyPhase = "rollback-issued"',
    '"candidate-present"',
    '"base-present"',
):
    if token not in service:
        fail("Apply lifecycle wiring missing " + token)

write_issued = service.index('reloadState.pendingApplyPhase = "write-issued"')
commit_start = service.index("commitProcess.running = true")
if write_issued < 0 or commit_start < 0 or write_issued > commit_start:
    fail("write-issued must be persisted before commit.py is started")

if "Quickshell.reload(" in service:
    fail("Apply lifecycle must rely on exactly one watcher-driven reload")

for token in (
    "target: Quickshell",
    "function onReloadCompleted(): void",
    "function onReloadFailed(errorString): void",
    'property string pendingApplyReloadOutcome: "none"',
    'property string pendingApplyVerifyState: "unknown"',
    'property string pendingApplyError: ""',
):
    if token not in service:
        fail("reload observation/persistence missing " + token)

for token in (
    "lifecycleOwnsSource",
    "commit.py/rollback verification detects",
    "if (lifecycleOwnsSource)",
):
    if token not in service:
        fail("own source watcher event must preserve lifecycle handoff: " + token)

if "readonly property bool applyEnabled: false" not in service:
    fail("Apply must remain disabled until live lifecycle acceptance")
if "beginApplyLifecycle()" in page:
    fail("Settings must not invoke the write lifecycle yet")
if 'mainText: "Apply"' in page:
    fail("Settings must not expose an Apply button yet")

for forbidden in (
    "FileView {",
    "setText(",
    "writeAdapter(",
    "atomicWrites",
):
    if forbidden in service:
        fail("transaction service must delegate atomic writes to commit.py: " + forbidden)

if "watcher-driven commit/reload/rollback lifecycle" not in phase2:
    fail("Phase 2 status must document Milestone 2G")
if "live acceptance" not in phase2:
    fail("Phase 2 status must keep live acceptance as the enablement gate")

print("ok - Code Workflow watcher-driven Apply lifecycle wiring contract")
