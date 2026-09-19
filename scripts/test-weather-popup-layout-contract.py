#!/usr/bin/env python3
"""Regression contract for the weather-only two-panel hover composition."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
CARD = ROOT / "modules/bar/weather/WeatherCard.qml"

def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")
    required = (
        "readonly property real compactBreakpoint: 900",
        "columns: root.compact ? 1 : 2",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "implicitHeight: composition.implicitHeight",
        "readonly property real panelHeight: 270",
        "anchors.topMargin: -12",
        "anchors.bottomMargin: 0",
        "anchors.verticalCenterOffset: 0",
        "readonly property real radiusX: Math.max(122, (width - 84) / 2)",
        "readonly property real radiusY: Math.max(82, (height - 104) / 2)",
        "function orbitAngle(index, count): real",
        "width: 52",
        "height: 64",
        'text: Qt.formatDate(root.now, "dddd, MMM d")',
        'text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)',
    )
    for token in required:
        if token not in source:
            raise AssertionError(f"Weather popup missing two-panel token: {token!r}")

    for forbidden in (
        "id: calendarPanel",
        "function firstDayOffset()",
        "function daysInMonth()",
        "function calendarDay(index)",
        "columns: root.compact ? 1 : 3",
        "DateTime.timeDisplay",
        "implicitHeight: 300",
        "width: 58",
        "height: 72",
    ):
        if forbidden in source:
            raise AssertionError(f"Weather popup still contains retired token: {forbidden!r}")

    if source.count("implicitHeight: root.panelHeight") != 2:
        raise AssertionError("Weather orbit and detail panels must share panelHeight")
    for token in (
        "implicitWidth: columnLayout.implicitWidth + 10 * 2",
        "implicitHeight: columnLayout.implicitHeight + 10 * 2",
    ):
        if token not in card:
            raise AssertionError(f"Weather metric card lost compact sizing token: {token!r}")

    print("Weather popup two-panel composition contract: OK")

if __name__ == "__main__":
    main()
