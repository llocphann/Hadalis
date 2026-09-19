#!/usr/bin/env python3
"""Regression contract for right-rail sliding Weather tabs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
CARD = ROOT / "modules/bar/weather/WeatherCard.qml"

def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")

    required = (
        "readonly property real compactBreakpoint: 900",
        "readonly property real panelHeight: 270",
        "readonly property real panelWidth: root.compact ? 360 : 430",
        "readonly property int tabCount: 2",
        "property int currentTab: 0",
        "function selectTab(index): void",
        "id: tabViewport",
        "id: timeWeatherPanel",
        "width: tabViewport.width",
        "height: tabViewport.height",
        "id: detailPanel",
        "clip: true",
        "y: (0 - root.currentTab) * tabViewport.height",
        "y: (1 - root.currentTab) * tabViewport.height",
        "Behavior on y",
        "duration: root.slideDuration",
        "easing.type: Appearance.animation.elementMove.type",
        "easing.bezierCurve: Appearance.animation.elementMove.bezierCurve",
        "id: tabIndicator",
        "anchors.right: parent.right",
        "anchors.verticalCenter: parent.verticalCenter",
        "model: root.tabCount",
        "radius: width / 2",
        "WheelHandler {",
        "orientation: Qt.Vertical",
        "acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad",
        "event.angleDelta.y < 0",
        "event.angleDelta.y > 0",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "function orbitAngle(index, count): real",
        "width: 52",
        "height: 64",
        'text: Qt.formatDate(root.now, "dddd, MMM d")',
        'text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)',
    )
    for token in required:
        if token not in source:
            raise AssertionError(f"Weather popup missing tab contract token: {token!r}")

    if source.count("Behavior on y") != 2:
        raise AssertionError("Weather tabs must use exactly two vertical slide transitions")

    for forbidden in (
        "columns: root.compact ? 1 : 2",
        "columns: root.compact ? 1 : 3",
        "id: calendarPanel",
        "function firstDayOffset()",
        "function daysInMonth()",
        "function calendarDay(index)",
        "Behavior on x",
        "Behavior on opacity",
        "anchors.left: parent.left",
        "anchors.fill: parent\n        radius: Appearance.rounding.large",
        "DateTime.timeDisplay",
        "implicitHeight: 300",
        "width: 58",
        "height: 72",
    ):
        if forbidden in source:
            raise AssertionError(f"Weather popup still contains retired/non-fade token: {forbidden!r}")

    for token in (
        "implicitWidth: columnLayout.implicitWidth + 10 * 2",
        "implicitHeight: columnLayout.implicitHeight + 10 * 2",
    ):
        if token not in card:
            raise AssertionError(f"Weather metric card lost compact sizing token: {token!r}")

    print("Weather popup right-rail slide composition contract: OK")

if __name__ == "__main__":
    main()
