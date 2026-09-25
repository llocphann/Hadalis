#!/usr/bin/env python3
"""Regression contract for the compact timer visual language."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POMODORO = ROOT / "modules" / "sidebarRight" / "pomodoro" / "PomodoroTimer.qml"
COUNTDOWN = ROOT / "modules" / "sidebarRight" / "pomodoro" / "CountdownTimer.qml"
WIDGET = ROOT / "modules" / "sidebarRight" / "pomodoro" / "PomodoroWidget.qml"
PILL_TAB = ROOT / "modules" / "common" / "widgets" / "PillTabBar.qml"


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        fail(message + " (" + token + ")")


pomodoro = POMODORO.read_text(encoding="utf-8")
countdown = COUNTDOWN.read_text(encoding="utf-8")
widget = WIDGET.read_text(encoding="utf-8")
pill_tab = PILL_TAB.read_text(encoding="utf-8")

# Pomodoro owns an open orbital arc, not the generic full CircularProgress dial.
if "CircularProgress {" in pomodoro:
    fail("Pomodoro must not regress to the generic full circular timer")
for token in (
    "import QtQuick.Shapes",
    "id: focusDial",
    "readonly property real orbitStrokeWidth: 5",
    "readonly property real arcCenterX: width / 2",
    "readonly property real arcCenterY: height / 2 - 4",
    "preferredRendererType: Shape.CurveRenderer",
    "readonly property real arcRadiusX:",
    "readonly property real arcRadiusY:",
    "readonly property real startAngle: 155",
    "readonly property real sweepAngle: 230",
    "PathAngleArc {",
    "strokeColor: root._colAccent",
    "strokeWidth: focusDial.orbitStrokeWidth",
    "anchors.verticalCenterOffset: root.compactMode ? 9 : 8",
    "(root.compactMode ? 31 : 34)",
    "width: 8",
    "border.width: 1",
    "border.color: root._colLayer",
    "TimerService.cyclesBeforeLongBreak",
    "index === TimerService.pomodoroCycle",
):
    require(pomodoro, token, "Pomodoro orbital focus presentation missing")

if "width: parent.width + 8" in pomodoro:
    fail("Pomodoro endpoint must not regress to a soft halo marker")

# Countdown intentionally uses a linear segmented runway so Timer and Pomodoro
# remain recognizably related without sharing the same timer-ring silhouette.
if "CircularProgress {" in countdown:
    fail("Countdown Timer must not regress to a generic circular timer")
for token in (
    "id: timerDeck",
    "readonly property real progress:",
    "id: segmentRow",
    "model: 16",
    "activeSegment:",
    "timerDeck.progress * 16",
    'Translation.tr("Set duration")',
):
    require(countdown, token, "Countdown segmented runway presentation missing")

# Timer mode tabs should fit inside the existing corner popup without making
# the popup resize or letting long labels cross into adjacent pills.
for token in (
    "property bool showTabBar: true",
    "property bool showPinButton: true",
    "visible: root.showTabBar || root.showPinButton",
    "anchors.horizontalCenter: parent.horizontalCenter",
    "root.compactMode ? 296 : 260",
    "root.showPinButton",
    "(pinButton.width + 6) * 2 : 0",
    "pillHeight: root.compactMode ? 28 : 30",
    "Layout.topMargin: (root.showTabBar || root.showPinButton) ? 6 : 0",
):
    require(widget, token, "Timer mode tabs must remain compact and centered")

for token in (
    "property real horizontalContentPadding: 10",
    "property int hoveredIndex: -1",
    "readonly property bool hasIcon:",
    "readonly property bool hasBadge:",
    "clip: true",
    "Appearance.colors.colPrimaryContainerHover",
    "Appearance.colors.colLayer1Hover",
    "onEntered: root.hoveredIndex = tab.index",
    "width: Math.min(implicitWidth, Math.max(0,",
    "tab.width",
    "horizontalAlignment: Text.AlignHCenter",
):
    require(pill_tab, token,
            "PillTabBar must constrain centered labels to their own tab slot")

for token in (
    "Item { Layout.preferredWidth: settingsButton.width }",
    "id: settingsButton",
):
    require(pomodoro, token,
            "Pomodoro Start/Reset group must stay centered around the full row")

print("ok - timer presentation contract")
