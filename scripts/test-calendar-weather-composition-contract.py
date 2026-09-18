#!/usr/bin/env python3
"""Regression contract for the v1.0 Calendar / Weather composition."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "modules" / "bar" / "weather" / "WeatherPopupContent.qml"
POPUP = ROOT / "modules" / "bar" / "weather" / "WeatherPopup.qml"
CLOCK = ROOT / "modules" / "bar" / "ClockWidget.qml"
CLOCK_TOOLTIP = ROOT / "modules" / "bar" / "ClockWidgetTooltip.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing Calendar/Weather contract token: {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} still contains retired Calendar/Weather token: {token!r}")


def main() -> None:
    content = CONTENT.read_text(encoding="utf-8")
    popup = POPUP.read_text(encoding="utf-8")
    clock = CLOCK.read_text(encoding="utf-8")

    forbid(clock, "ClockWidgetTooltip {", "ClockWidget.qml")
    if CLOCK_TOOLTIP.exists():
        raise AssertionError("retired ClockWidgetTooltip.qml must not remain as a public/live bar surface")

    for token in (
        "StyledPopup {",
        "id: weatherContent",
        "root.presentationWindow?.width",
        "compact: (root.presentationWindow?.width ?? 1920) < weatherContent.compactBreakpoint",
    ):
        require(popup, token, "WeatherPopup.qml")

    for token in (
        "readonly property real compactBreakpoint: 1180",
        "columns: root.compact ? 1 : 3",
        "id: calendarPanel",
        "function calendarDay(index): int",
        "id: timeWeatherPanel",
        "id: orbitalTimeline",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "Math.cos(angle)",
        "Math.sin(angle)",
        "id: orbitGuide",
        "text: DateTime.timeDisplay",
        "id: detailPanel",
        'title: Translation.tr("UV Index")',
        'title: Translation.tr("Wind")',
        'title: Translation.tr("Humidity")',
        'title: Translation.tr("Pressure")',
        'title: Translation.tr("Sunrise")',
        'title: Translation.tr("Sunset")',
    ):
        require(content, token, "WeatherPopupContent.qml")

    forbid(content, "id: hourlyTimeline", "WeatherPopupContent.qml")
    forbid(content, "Weather.data.hourly.slice(0, 5)", "WeatherPopupContent.qml")

    print("Calendar / Weather v1.0 composition contract: PASS")


if __name__ == "__main__":
    main()
