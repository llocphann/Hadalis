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
    "id: inactiveRightShape",
    "id: inactiveLeftShape",
    "PathQuad {",
    "readonly property real innerHeight:",
    "readonly property real innerRadius:",
    "readonly property real seamRadius:",
    "x: tabShell.halfWidth - tabShell.inset",
    "y: tabShell.inset",
    "clip: false",
    "id: activeTabPill",
    "width: tabShell.halfWidth - tabShell.inset * 2",
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

# The connected tab shell must keep one active inner pill and two mirrored
# inactive concave segments rather than regressing to two independent pills.
assert todo.count("id: activeTabPill") == 1
assert todo.count("Shape {") >= 2
assert todo.count("PathQuad {") >= 8
assert "implicitHeight: root.tabControlHeight" in todo
assert "Layout.minimumHeight: root.veryShallowLayout" in todo
assert todo.count("Layout.preferredWidth: root.actionButtonSize") >= 4
assert "id: setupRow" not in todo
assert "id: editRow" not in todo
assert "id: addRow" not in todo
assert "tabShell.notch" not in todo

print("Dashboard Todo adaptive layout contract: PASS")
