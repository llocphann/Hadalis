#!/usr/bin/env python3
"""Regression contract for Niri Overview exact-window drag/drop semantics."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERVIEW = ROOT / "modules" / "overview" / "OverviewNiriWidget.qml"
WAFFLE = ROOT / "modules" / "waffle" / "taskview" / "WaffleTaskViewContent.qml"
NIRI = ROOT / "services" / "NiriService.qml"

overview = OVERVIEW.read_text(encoding="utf-8")
waffle = WAFFLE.read_text(encoding="utf-8")
niri = NIRI.read_text(encoding="utf-8")

failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

def forbid(source: str, token: str, label: str) -> None:
    if token in source:
        failures.append(f"{label}: forbidden {token!r}")

# Each pointer drag owns an immutable Niri window id from press through release.
for token in (
    "property int draggingWindowId: -1",
    "root.draggingWindowId = draggedId",
    "const draggedWindowId = root.draggingWindowId",
    "Number(windowData.id) === draggedWindowId",
):
    require(overview, token, "Overview drag identity")

# Rebuilt window records must preserve identity by Niri window id. Without a
# key, ScriptModel compares whole mutable records, so workspace/layout changes
# can remove/reinsert multiple delegates during a single-window move.
require(overview, 'objectProp: "id"', "Overview stable window model identity")
require(
    overview,
    "&& root.draggingWindowId < 0",
    "Overview drag reflow animation isolation",
)
forbid(
    overview,
    "Qt.callLater(() => windowSpace.rebuildWindowItems())",
    "Overview drop must wait for authoritative Niri state",
)

# A fast reverse drag must cancel the previous delayed cleanup before publishing
# the next transaction, otherwise the old timer can erase from/target state.
require(overview, "dragCleanupTimer.stop()", "Overview reverse-drag lifecycle")
require(
    overview,
    "root.draggingTargetWorkspace = -1",
    "Overview reverse-drag lifecycle",
)
require(
    overview,
    "root.draggingWindowId = -1\n            root.draggingFromWorkspace = -1",
    "Overview cleanup",
)

# Workspace reorganization is non-focusing: only the captured window moves.
require(
    overview,
    "NiriService.moveWindowToWorkspaceById(\n                                        draggedWindowId, targetWorkspace, false)",
    "Overview exact-window drop",
)
forbid(
    overview,
    "NiriService.moveWindowToWorkspaceById(\n                                        windowData.id, targetWorkspace, true)",
    "Overview exact-window drop",
)
forbid(
    overview,
    "NiriService.moveWindowToWorkspaceById(windowData.id, targetWorkspace, true)",
    "Overview exact-window drop",
)

# The sibling Waffle task-view already uses the same Niri-safe no-focus rule.
for token in (
    '"--window-id", windowId.toString()',
    '"--focus", "false"',
):
    require(waffle, token, "Waffle drag parity")

# Service transport must keep explicit window_id and caller-controlled focus.
for token in (
    "function moveWindowToWorkspaceById(windowId, workspaceId, focus)",
    '"window_id": windowId',
    '"focus": focus === undefined ? false : focus',
):
    require(niri, token, "Niri move service")

if failures:
    print("Niri Overview drag/drop contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Niri Overview drag/drop contract: PASS")
