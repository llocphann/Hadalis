#!/usr/bin/env python3
"""Regression contract for right-rail sliding Weather tabs and shared orbital view."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
ORBITAL = ROOT / "modules/bar/weather/OrbitalWeather.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"
CARD = ROOT / "modules/bar/weather/WeatherCard.qml"

def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing weather contract token: {token!r}")

def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    orbital = ORBITAL.read_text(encoding="utf-8")
    dash_weather = DASH_WEATHER.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")

    popup_required = (
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
        "OrbitalWeather {",
        "id: orbitalTimeline",
        "id: detailSummary",
        "id: primaryMetrics",
        "component PrimaryMetric: Rectangle",
        "component SecondaryMetric: RowLayout",
        "id: secondaryStrip",
        "id: sunTimeline",
        "root.sunProgress",
        'Translation.tr("Last refresh: %1")',
    )
    for token in popup_required:
        require(source, token, "WeatherPopupContent.qml")

    orbital_required = (
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "function hourFromLabel(label): real",
        "function arcAngle(startAngle, endAngle, fraction): real",
        "function orbitAngleForHour(label): real",
        "const quadrant = Math.floor(shiftedHour / 6)",
        "const fraction = (shiftedHour - quadrant * 6) / 6",
        "return root.arcAngle(start, end, fraction)",
        "root.orbitAngleForHour(modelData?.label)",
        "readonly property real pointWidth:",
        "readonly property real pointHeight:",
        "readonly property real orbitRadiusX:",
        "readonly property real orbitRadiusY:",
        'root.width >= 380',
        'Qt.formatDate(root.now, "dddd, MMM d")',
        'Qt.formatDate(root.now, "ddd, MMM d")',
    )
    for token in orbital_required:
        require(orbital, token, "OrbitalWeather.qml")

    require(dash_weather, "import qs.modules.bar.weather", "DashWeather.qml")
    require(dash_weather, "OrbitalWeather {", "DashWeather.qml")

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
        "function orbitAngle(index, count): real",
        "+ (shiftedHour / 24) * Math.PI * 2",
        "DateTime.timeDisplay",
        "implicitHeight: 300",
        "width: 58",
        "height: 72",
    ):
        if forbidden in source or forbidden in orbital:
            raise AssertionError(
                f"Weather composition contains retired token: {forbidden!r}")

    for retired in (
        "WeatherCard {",
        'title: Translation.tr("Sunrise")',
        'title: Translation.tr("Sunset")',
    ):
        if retired in source:
            raise AssertionError(
                f"Detailed Weather regressed to flat metric grid: {retired!r}")

    print("Weather popup + shared orbital composition contract: OK")

if __name__ == "__main__":
    main()
