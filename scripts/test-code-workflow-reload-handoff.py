#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    'reloadableId: "code-workflow-transaction"',
    "PersistentProperties {",
    'reloadableId: "code-workflow-transaction-state"',
    'property string historyJson: "[]"',
    "property int historyIndex: -1",
    'property string pendingApplyPhase: "idle"',
    'property string pendingApplySourcePath: ""',
    'property string pendingApplyBaseSha256: ""',
    'property string pendingApplyCandidateSha256: ""',
    'property string pendingApplySemanticAnchor: ""',
    'property string pendingApplyReplacement: ""',
    "property int pendingApplyHistoryIndex: -1",
    "function _syncReloadState(): void",
    "function _restoreReloadState(): void",
    "JSON.stringify(root.history ?? [])",
    "JSON.parse(",
    "function stageApplyHandoff(): bool",
    "if (!root.preApplyReady || !command)",
    'reloadState.pendingApplyPhase = "prepared"',
    "function clearApplyHandoff(): void",
    "onLoaded: root._restoreReloadState()",
    "onReloaded: root._restoreReloadState()",
):
    if token not in service:
        fail("reload-stable transaction handoff missing " + token)

persistent_block = service.split("PersistentProperties {", 1)[1].split(
    "    Connections {", 1
)[0]

for line in persistent_block.splitlines():
    match = re.match(
        r"\s*property\s+(\w+)\s+(historyJson|historyIndex|pendingApply\w+)\s*:",
        line,
    )
    if match and match.group(1) not in {"string", "int", "bool", "real"}:
        fail(
            "reload handoff property must stay primitive: "
            + match.group(2)
            + " uses "
            + match.group(1)
        )

for forbidden in ("byteRange", "valueRange"):
    if forbidden in persistent_block:
        fail("reload handoff must not persist transient parser ranges: " + forbidden)

if "readonly property bool applyEnabled: false" not in service:
    fail("Apply must remain disabled through lifecycle wiring")

if "Milestone 2G" not in phase2 or "PersistentProperties" not in phase2:
    fail("Phase 2 status must document full reload-stable lifecycle handoff")

print("ok - Code Workflow reload-stable transaction handoff contract")
