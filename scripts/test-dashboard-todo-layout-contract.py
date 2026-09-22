#!/usr/bin/env python3
"""Static contract for the adaptive Dashboard Todo presentation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
todo = (ROOT / "modules" / "dashboard" / "DashTodo.qml").read_text(encoding="utf-8")

for token in (
    "import QtQuick.Shapes",
    "readonly property bool narrowLayout:",
    "readonly property bool shallowLayout:",
    "readonly property bool veryShallowLayout:",
    "id: tabShell",
    "readonly property real innerHeight:",
    "readonly property real cornerRadius: innerHeight / 2",
    "id: inactiveLeftShape",
    "id: inactiveRightShape",
    "id: activeTabPill",
    "PathArc.Counterclockwise",
    "PathArc.Clockwise",
    "radiusX: tabShell.cornerRadius",
    "radiusY: tabShell.cornerRadius",
    "x: tabShell.halfWidth - tabShell.cornerRadius",
    "radius: tabShell.cornerRadius",
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

# The inactive contact edge must be a true inward semicircle whose radius is
# exactly the same as the ordinary outer pill radius. The active pill uses that
# same R, so the two silhouettes are complementary rather than approximate.
assert todo.count("id: inactiveLeftShape") == 1
assert todo.count("id: inactiveRightShape") == 1
assert todo.count("id: activeTabPill") == 1
assert todo.count("radiusX: tabShell.cornerRadius") >= 6
assert todo.count("radiusY: tabShell.cornerRadius") >= 6
assert "seamOverlap" not in todo
assert "tabSurfaceWidth" not in todo
assert "id: leftTabSurface" not in todo
assert "id: rightTabSurface" not in todo
assert "implicitHeight: root.tabControlHeight" in todo
assert "Layout.minimumHeight: root.veryShallowLayout" in todo
assert todo.count("Layout.preferredWidth: root.actionButtonSize") >= 4
assert "id: setupRow" not in todo
assert "id: editRow" not in todo
assert "id: addRow" not in todo
assert "tabShell.notch" not in todo

print("Dashboard Todo adaptive layout contract: PASS")
