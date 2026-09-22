#!/usr/bin/env python3
"""Static contract for the adaptive Dashboard Todo presentation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
todo = (ROOT / "modules" / "dashboard" / "DashTodo.qml").read_text(encoding="utf-8")

for token in (
    "readonly property bool narrowLayout:",
    "readonly property bool shallowLayout:",
    "readonly property bool veryShallowLayout:",
    "id: tabShell",
    "readonly property real innerHeight:",
    "readonly property real innerRadius:",
    "readonly property real seamOverlap:",
    "readonly property real tabSurfaceWidth:",
    "id: leftTabSurface",
    "id: rightTabSurface",
    "x: tabShell.halfWidth - tabShell.seamOverlap / 2",
    "radius: tabShell.innerRadius",
    "z: root.currentTab === 0 ? 2 : 1",
    "z: root.currentTab === 1 ? 2 : 1",
    "id: leftTabHover",
    "id: rightTabHover",
    'Translation.tr("Unfinished")',
    'Translation.tr("Done")',
    "root.unfinishedTasks.length",
    "root.doneTasks.length",
    "readonly property int safeEdgeInset: 2",
    "readonly property int actionButtonSize:",
    "Layout.leftMargin: root.safeEdgeInset",
    "Layout.rightMargin: root.safeEdgeInset",
    'Translation.tr("Prepare Obsidian")',
    'Translation.tr("Edit task source")',
    'Translation.tr("Add task")',
):
    assert token in todo, f"Dashboard Todo adaptive UI contract lost: {token}"

# The two tab surfaces must remain ordinary rounded rectangles. The center seam
# comes only from a small overlap plus z-order: active pill above inactive pill.
assert "import QtQuick.Shapes" not in todo
assert "Shape {" not in todo
assert "PathQuad {" not in todo
assert "id: activeTabPill" not in todo
assert "inactiveRightShape" not in todo
assert "inactiveLeftShape" not in todo
assert todo.count("radius: tabShell.innerRadius") >= 2
assert "implicitHeight: root.tabControlHeight" in todo
assert "Layout.minimumHeight: root.veryShallowLayout" in todo
assert todo.count("Layout.preferredWidth: root.actionButtonSize") >= 4
assert "id: setupRow" not in todo
assert "id: editRow" not in todo
assert "id: addRow" not in todo
assert "tabShell.notch" not in todo
assert "tabShell.seamRadius" not in todo

print("Dashboard Todo adaptive layout contract: PASS")
