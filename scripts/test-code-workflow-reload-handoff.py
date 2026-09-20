#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)

service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
bridge = (ROOT / "services/CodeWorkflowReloadBridge.qml").read_text(encoding="utf-8")
shell = (ROOT / "shell.qml").read_text(encoding="utf-8")
probe = (ROOT / "scripts/code-workflow/runtime/ProbeShell.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    'readonly property string reloadStateJson: JSON.stringify({',
    'function restoreReloadStateJson(encoded: string): bool',
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
):
    if token not in service:
        fail("reload-stable transaction handoff missing " + token)

for token in (
    'reloadableId: "code-workflow-reload-bridge"',
    "PersistentProperties {",
    'reloadableId: "code-workflow-transaction-state"',
    'property string stateJson: ""',
    "CodeWorkflowTransaction.restoreReloadStateJson(encoded)",
    "persisted.stateJson = CodeWorkflowTransaction.reloadStateJson",
    "onLoaded: bridge.restorePersistedState()",
    "function restorePersistedState(): void",
    "function onReloadStateJsonChanged(): void",
):
    if token not in bridge:
        fail("root-owned reload bridge missing " + token)

if "CodeWorkflowReloadBridge 1.0 CodeWorkflowReloadBridge.qml" not in qmldir:
    fail("services/qmldir must export the root-owned reload bridge")
if "CodeWorkflowReloadBridge {}" not in shell:
    fail("production ShellRoot must own the Workflow reload bridge")
if "CodeWorkflowReloadBridge {}" not in probe:
    fail("acceptance ProbeShell must exercise the production reload bridge")

if "PersistentProperties {" in service:
    fail("transaction singleton must not own cross-generation PersistentProperties")

persistent_block = bridge.split("PersistentProperties {", 1)[1].split(
    "    function restorePersistedState", 1
)[0]
for line in persistent_block.splitlines():
    match = re.match(r"\s*property\s+(\w+)\s+(\w+)\s*:", line)
    if match and match.group(1) not in {"string", "int", "bool", "real"}:
        fail(
            "root reload bridge property must stay primitive: "
            + match.group(2)
            + " uses "
            + match.group(1)
        )
for forbidden in ("byteRange", "valueRange"):
    if forbidden in persistent_block:
        fail("root reload bridge must not persist transient ranges: " + forbidden)

if "readonly property bool applyCommandMatchesHandoff:" not in service:
    fail("Apply enablement must preserve reload-stable semantic handoff identity")

if "Milestone 2G" not in phase2 or "PersistentProperties" not in phase2:
    fail("Phase 2 status must document full reload-stable lifecycle handoff")

print("ok - Code Workflow reload-stable transaction handoff contract")
