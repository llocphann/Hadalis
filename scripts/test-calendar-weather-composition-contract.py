#!/usr/bin/env python3
"""Regression contract for the v1.0 Calendar / Weather composition."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "modules" / "bar" / "weather" / "WeatherPopupContent.qml"
SURFACE = ROOT / "modules" / "perimeter" / "WeatherConnectedSurface.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing Calendar/Weather contract token: {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} still contains retired Calendar/Weather token: {token!r}")


def main() -> None:
    content = CONTENT.read_text(encoding="utf-8")
    surface = SURFACE.read_text(encoding="utf-8")

    for token in (
        "readonly property real compactBreakpoint: 900",
        "columns: root.compact ? 1 : 3",
        "id: calendarPanel",
        "function calendarDay(index): int",
        "id: timeWeatherPanel",
        "text: DateTime.timeDisplay",
        "id: hourlyTimeline",
        "Weather.data.hourly.slice(0, 5)",
        "PathQuad {",
        "id: detailPanel",
        'title: Translation.tr("UV Index")',
        'title: Translation.tr("Wind")',
        'title: Translation.tr("Humidity")',
        'title: Translation.tr("Pressure")',
        'title: Translation.tr("Sunrise")',
        'title: Translation.tr("Sunset")',
    ):
        require(content, token, "WeatherPopupContent.qml")

    for token in (
        "Math.max(320, weatherContent.implicitWidth + 24)",
        "Math.max(220, weatherContent.implicitHeight + 24)",
        "compact: geometry.maximumBodyWidth < weatherContent.compactBreakpoint",
        "readonly property color surfaceColor: Appearance.colors.colLayer0",
        'borderColor: "transparent"',
        "borderWidth: 0",
    ):
        require(surface, token, "WeatherConnectedSurface.qml")

    forbid(surface, "Appearance.inirEverywhere", "WeatherConnectedSurface.qml")

    print("Calendar / Weather v1.0 composition contract: PASS")


if __name__ == "__main__":
    main()
