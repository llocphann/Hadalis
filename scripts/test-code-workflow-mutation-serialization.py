#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
PHASE2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def region(start: str, end: str) -> str:
    a = SERVICE.find(start)
    b = SERVICE.find(end, a + len(start))
    if a < 0 or b < 0:
        fail("missing contract region: " + start)
    return SERVICE[a:b]


apply_gate = region(
    "readonly property bool applyLifecycleReady:",
    "readonly property bool previewBusy:",
)
for token in (
    "!root.connectLifecycleBusy",
    "!root.bindingLifecycleBusy",
    "!root.disconnectLifecycleBusy",
):
    if token not in apply_gate:
        fail("Literal Apply gate missing cross-pipeline blocker " + token)

for start, end, label in (
    ("function stageConnectLifecycleHandoff(): bool", "function clearConnectLifecycleHandoff", "Connect"),
    ("function stageDisconnectLifecycleHandoff(): bool", "function clearDisconnectLifecycleHandoff", "Disconnect"),
    ("function stageBindingLifecycleHandoff(): bool", "function clearBindingLifecycleHandoff", "Binding"),
):
    block = region(start, end)
    for token in (
        "root.applyLifecycleBusy",
        "root.connectLifecycleBusy",
        "root.bindingLifecycleBusy",
        "root.disconnectLifecycleBusy",
    ):
        if token not in block:
            fail(label + " lifecycle stage missing blocker " + token)

helper = region(
    "function _invalidateCompetingHandoffsForOwnedSource(",
    "function markSourceChanged(",
)
for token in (
    "root._markHistoryStaleExcept(changedPath, preserved)",
    'owner === "connect" ? preserved : -1',
    'owner === "binding" ? preserved : -1',
    'owner === "disconnect" ? preserved : -1',
    'owner !== "literal"',
    "root._invalidateApplyHandoff()",
):
    if token not in helper:
        fail("competing handoff invalidation missing " + token)

for start, end, label in (
    ("function _markHistoryStaleExcept(", "function markSourceChanged(", "history"),
    ("function _markConnectSafetyStaleExcept(", "function _startConnectSafetyFreshnessCheck", "Connect"),
    ("function _markBindingArtifactsStaleExcept(", "function _markDisconnectArtifactsStale", "Binding"),
    ("function _markDisconnectArtifactsStaleExcept(", "function _startPreview(", "Disconnect"),
):
    block = region(start, end)
    if "index === preserved" not in block:
        fail(label + " stale helper does not preserve lifecycle owner index")

source_change = region(
    "function markSourceChanged(path: string): void",
    "function _markBindingArtifactsStale",
)
for owner, index_name in (
    ("literal", "pendingApplyHistoryIndex"),
    ("connect", "pendingConnectHistoryIndex"),
    ("binding", "pendingBindingHistoryIndex"),
    ("disconnect", "pendingDisconnectHistoryIndex"),
):
    token = (
        "root._invalidateCompetingHandoffsForOwnedSource(\n"
        "                changedPath,\n"
        f'                "{owner}",\n'
        f"                reloadState.{index_name})"
    )
    if token not in source_change:
        fail(owner + " source owner does not invalidate competing handoffs")

for owner_marker, next_marker, label in (
    ("if (lifecycleOwnsSource) {", "const connectLifecycleOwnsSource", "Literal"),
    ("if (connectLifecycleOwnsSource) {", "const bindingLifecycleOwnsSource", "Connect"),
    ("if (bindingLifecycleOwnsSource) {", "const disconnectLifecycleOwnsSource", "Binding"),
    ("if (disconnectLifecycleOwnsSource) {", 'if (connectPhase !== "idle"', "Disconnect"),
):
    block = region(owner_marker, next_marker)
    call = "root._invalidateCompetingHandoffsForOwnedSource("
    if call not in block or block.find(call) > block.find("return"):
        fail(label + " owner invalidation must run before watcher return")

restore = region(
    "function _restoreReloadState(): void",
    "function restoreReloadStateJson(",
)
for token in (
    "const activeApplyPhases = [",
    'restoredOwnerKind = "literal"',
    "reloadState.pendingApplyHistoryIndex",
    'restoredOwnerKind = "connect"',
    "reloadState.pendingConnectHistoryIndex",
    'restoredOwnerKind = "binding"',
    "reloadState.pendingBindingHistoryIndex",
    'restoredOwnerKind = "disconnect"',
    "reloadState.pendingDisconnectHistoryIndex",
    "root._invalidateCompetingHandoffsForOwnedSource(",
):
    if token not in restore:
        fail("cross-generation owner invalidation missing " + token)

for token in (
    "Milestone 2K-V-A — cross-pipeline mutation serialization hardening",
    "stageConnectLifecycleHandoff",
    "preserves the active lifecycle owner",
    "stales every competing handoff on the changed source",
):
    if token not in PHASE2:
        fail("2K-V-A documentation missing " + token)

print("ok - Code Workflow 2K-V-A cross-pipeline mutation serialization contract")
