#!/usr/bin/env python3
"""Contract for the Quick Notes / Timers popup-level pin."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POPUP = (ROOT / "modules/screenCorners/QuickNotesPopup.qml").read_text(encoding="utf-8")
TIMER = (ROOT / "modules/sidebarRight/pomodoro/PomodoroWidget.qml").read_text(encoding="utf-8")

def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {message} ({token})")

for token in (
    "property bool popupPinned: false",
    "|| root.entryBridgeHeld || root.popupPinned",
    "id: popupPinButton",
    "toggled: root.popupPinned",
    "onClicked: root.popupPinned = !root.popupPinned",
    "root.popupPinned = false",
    "showPinButton: false",
):
    require(POPUP, token, "Quick Notes popup pin ownership missing")

for token in (
    "property bool showPinButton: true",
    "visible: root.showPinButton",
    "Persistent.states?.timer?.pinnedToBar",
):
    require(TIMER, token, "standalone timer-to-Bar pin compatibility missing")

if "Persistent.states.timer.pinnedToBar = !toggled" not in TIMER:
    raise SystemExit("FAIL: timer-to-Bar pin semantics changed outside Quick Notes")

print("ok - popup pin is output-local and timer-to-Bar pin keeps its separate meaning")
