#!/usr/bin/env python3
"""Regression contract for the compact timer visual language."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POMODORO = ROOT / "modules" / "sidebarRight" / "pomodoro" / "PomodoroTimer.qml"
COUNTDOWN = ROOT / "modules" / "sidebarRight" / "pomodoro" / "CountdownTimer.qml"
WIDGET = ROOT / "modules" / "sidebarRight" / "pomodoro" / "PomodoroWidget.qml"


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        fail(message + " (" + token + ")")


pomodoro = POMODORO.read_text(encoding="utf-8")
countdown = COUNTDOWN.read_text(encoding="utf-8")
widget = WIDGET.read_text(encoding="utf-8")

# Pomodoro owns an open orbital arc, not the generic full CircularProgress dial.
if "CircularProgress {" in pomodoro:
    fail("Pomodoro must not regress to the generic full circular timer")
for token in (
    "import QtQuick.Shapes",
    "id: focusDial",
    "readonly property real arcRadiusX:",
    "readonly property real arcRadiusY:",
    "readonly property real startAngle: 155",
    "readonly property real sweepAngle: 230",
    "PathAngleArc {",
    "strokeColor: root._colAccent",
    "TimerService.cyclesBeforeLongBreak",
    "index === TimerService.pomodoroCycle",
):
    require(pomodoro, token, "Pomodoro orbital focus presentation missing")

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

# Timer mode tabs should stay compact and centered to protect the timer viewport.
for token in (
    "anchors.horizontalCenter: parent.horizontalCenter",
    "width: Math.max(150, Math.min(",
    "pillHeight: 30",
    "Layout.topMargin: 6",
):
    require(widget, token, "Timer mode tabs must remain compact and centered")

print("ok - timer presentation contract")
