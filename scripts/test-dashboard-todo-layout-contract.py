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
    "readonly property real arcKappa: 0.5522847498",
    "readonly property int iconSlotSize:",
    "readonly property int tabIconSize:",
    "readonly property int badgeSize:",
    "readonly property real contentPadding:",
    "readonly property real contentSpacing:",
    "id: inactiveTabShape",
    "PathCubic {",
    "xScale: root.currentTab === 0 ? -1 : 1",
    "width: tabShell.halfWidth + tabShell.cornerRadius",
    "id: activeTabPill",
    "? tabShell.inset",
    ": tabShell.halfWidth",
    "width: tabShell.halfWidth - tabShell.inset",
    "radius: tabShell.cornerRadius",
    "id: leftTabHover",
    "id: rightTabHover",
    'Translation.tr("Unfinished")',
    'Translation.tr("Done")',
    "horizontalAlignment: Text.AlignHCenter",
    "verticalAlignment: Text.AlignVCenter",
    "font.weight: Font.Medium",
    "Layout.preferredWidth: tabShell.iconSlotSize",
    "Layout.preferredWidth: tabShell.badgeSize",
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

# Only one inactive path is maintained; right-side presentation is a mirror of
# the same canonical geometry. Both convex and concave ends use the same R and
# cubic-circle constant, so the two tab states cannot drift apart.
assert todo.count("id: inactiveTabShape") == 1
assert "id: inactiveLeftShape" not in todo
assert "id: inactiveRightShape" not in todo
assert todo.count("PathCubic {") == 4
assert todo.count("tabShell.arcKappa * tabShell.cornerRadius") >= 8
assert todo.count("id: activeTabPill") == 1
assert "PathArc.Counterclockwise" not in todo
assert "PathArc.Clockwise" not in todo

# Both logical halves use identical icon and badge slots, fixed text weight and
# centered labels. Active state may change color, not metrics or typography.
assert todo.count("Layout.preferredWidth: tabShell.iconSlotSize") == 2
assert todo.count("Layout.preferredWidth: tabShell.badgeSize") == 2
assert todo.count("font.weight: Font.Medium") >= 2
assert todo.count("horizontalAlignment: Text.AlignHCenter") >= 2

assert "seamOverlap" not in todo
assert "tabSurfaceWidth" not in todo
assert "implicitHeight: root.tabControlHeight" in todo
assert "Layout.minimumHeight: root.veryShallowLayout" in todo
assert todo.count("Layout.preferredWidth: root.actionButtonSize") >= 4
assert "id: setupRow" not in todo
assert "id: editRow" not in todo
assert "id: addRow" not in todo
assert "tabShell.notch" not in todo

print("Dashboard Todo adaptive layout contract: PASS")
