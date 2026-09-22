#!/usr/bin/env python3
"""Static contract for the adaptive Dashboard Todo presentation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
todo = (ROOT / "modules" / "dashboard" / "DashTodo.qml").read_text(encoding="utf-8")

for token in (
    "import QtQuick.Shapes",
    "readonly property bool narrowLayout:",
    "readonly property bool shallowLayout:",
    "id: tabShell",
    "id: inactiveRightShape",
    "id: inactiveLeftShape",
    "PathQuad {",
    "x: tabShell.halfWidth - tabShell.notch",
    "id: activeTabPill",
    "width: tabShell.halfWidth - tabShell.inset * 2",
    "id: leftTabHover",
    "id: rightTabHover",
    'Translation.tr("Unfinished")',
    'Translation.tr("Done")',
    "root.unfinishedTasks.length",
    "root.doneTasks.length",
    "visible: !root.narrowLayout",
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

print("Dashboard Todo adaptive layout contract: PASS")
