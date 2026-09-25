#!/usr/bin/env python3
"""Regression contract for shared minute-resolution service ticks."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DATE_TIME = ROOT / "services/DateTime.qml"
WEATHER = ROOT / "services/Weather.qml"
EVENTS = ROOT / "services/Events.qml"
THEME = ROOT / "services/ThemeService.qml"
SCREEN_TIME = ROOT / "services/ScreenTime.qml"


def main() -> int:
    date_time = DATE_TIME.read_text(encoding="utf-8")
    weather = WEATHER.read_text(encoding="utf-8")
    events = EVENTS.read_text(encoding="utf-8")
    theme = THEME.read_text(encoding="utf-8")
    screen_time = SCREEN_TIME.read_text(encoding="utf-8")

    if "readonly property int minuteEpoch: Math.floor(clock.date.getTime() / 60000)" not in date_time:
        raise AssertionError("DateTime must expose a stable shared minute epoch")
    if "onMinuteEpochChanged: refreshUptime()" not in date_time:
        raise AssertionError("DateTime uptime must reuse the shared minute epoch")
    if "Component.onCompleted: refreshUptime()" not in date_time:
        raise AssertionError("DateTime uptime must retain its immediate initial refresh")
    if "interval: 60000" in date_time:
        raise AssertionError("DateTime must not restore a parallel uptime minute timer")

    if "readonly property int _clockTick: DateTime.minuteEpoch" not in weather:
        raise AssertionError("Weather live context must reuse DateTime.minuteEpoch")
    if "id: clockTickTimer" in weather:
        raise AssertionError("Weather must not restore its private minute timer")
    if "root._clockTick // recompute every minute" not in weather:
        raise AssertionError("Weather sun progress must retain minute dependency")
    if re.search(r"property int _clockTick:\s*0", weather):
        raise AssertionError("Weather clock tick must stay bound to the shared clock")

    if "target: DateTime" not in events or "function onMinuteEpochChanged()" not in events:
        raise AssertionError("Events reminders must reuse DateTime.minuteEpoch")
    if "id: checkTimer" in events or "interval: 60000 // 1 minute" in events:
        raise AssertionError("Events must not restore its private reminder minute timer")

    if "target: DateTime" not in theme or "function onMinuteEpochChanged()" not in theme:
        raise AssertionError("Theme scheduling must reuse DateTime.minuteEpoch")
    if "enabled: root.scheduleEnabled" not in theme:
        raise AssertionError("Theme minute callback must sleep while scheduling is disabled")
    if "onScheduleEnabledChanged:" not in theme or "Qt.callLater(root.applyScheduledTheme)" not in theme:
        raise AssertionError("Theme scheduling must retain immediate activation behavior")
    if "interval: 60000  // Check every minute" in theme:
        raise AssertionError("ThemeService must not restore its private schedule timer")

    if "target: DateTime" not in screen_time or "function onMinuteEpochChanged()" not in screen_time:
        raise AssertionError("ScreenTime day rollover must reuse DateTime.minuteEpoch")
    if "enabled: root.enabled && root.ready && root._initialized" not in screen_time:
        raise AssertionError("ScreenTime rollover callback must retain lifecycle gating")
    if "id: dayRolloverTimer" in screen_time:
        raise AssertionError("ScreenTime must not restore its private rollover minute timer")

    print("shared minute tick contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
