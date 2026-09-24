#!/usr/bin/env python3
"""Contract for the compact connected Weather popup and shared orbit."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEATHER_DIR = ROOT / "modules/bar/weather"


def require(source: str, *features: str) -> None:
    for feature in features:
        if feature not in source:
            raise AssertionError(f"Weather popup lost {feature!r}")


def main() -> None:
    source = (WEATHER_DIR / "WeatherPopupContent.qml").read_text()
    wrapper = (WEATHER_DIR / "WeatherPopup.qml").read_text()
    orbital = (WEATHER_DIR / "OrbitalWeather.qml").read_text()
    dashboard = (ROOT / "modules/dashboard/DashWeather.qml").read_text()

    # Keep one narrow, stable popup footprint for both tabs. Detailed Weather
    # must reflow instead of widening the connected surface.
    require(wrapper, "StyledPopup {", "WeatherPopupContent {",
            "compact: (root.presentationWindow?.width ?? 1920)")
    require(source, "readonly property real panelWidth: root.compact ? 360 : 390",
            "readonly property real panelHeight: root.compact ? 270 : 300",
            "readonly property real orbitalInset: root.compact ? 6 : 8",
            "readonly property real orbitalRightInset: root.orbitalInset",
            "columns: 2",
            "implicitHeight: root.compact ? 36 : 42",
            "readonly property int tabCount: 2", "property int currentTab: 0")

    # Two pages still slide inside one clipped surface, with the dot rail
    # remaining at the right edge as the compact tab control.
    require(source, "id: tabViewport", "clip: true",
            "y: (0 - root.currentTab) * tabViewport.height",
            "y: (1 - root.currentTab) * tabViewport.height",
            "liquidMode: true", "id: detailPanel",
            "id: tabIndicator", "anchors.right: parent.right",
            "anchors.verticalCenter: parent.verticalCenter",
            "id: primaryMetrics", "id: sunTimeline", "WheelHandler {")
    if source.count("Behavior on y") != 2:
        raise AssertionError("Hourly and Daily must each retain a slide transition")
    for removed in ("id: modeSwitch", "component OrbitArrow:",
                    "selectedHourIndex", "function cycleHour(",
                    "model: (Weather.data?.forecast ?? []).slice("):
        if removed in source:
            raise AssertionError(f"Removed large-popup control remains: {removed}")

    require(orbital, "(Weather.data?.hourly ?? []).slice(0, 8)",
            "function orbitAngleForHour(label): real",
            "readonly property real conceptOrbitAspect:",
            "readonly property real availableLiquidWidth:",
            "readonly property real availableLiquidHeight:",
            "readonly property real liquidOrbitAspect:",
            "Math.min(1.32, availableLiquidAspect)",
            "width * 0.13, root.orbitStageHeight * 0.19",
            "readonly property real orbitRadiusX:",
            "readonly property real orbitRadiusY:",
            "readonly property real orbitStageHeight: Math.max(1, height)",
            "LiquidOrbitalField {", "root.liquidMode")
    for removed in ("id: conceptFooter", "id: aqiPill", "footerHeight"):
        if removed in orbital:
            raise AssertionError(f"Removed footer status remains: {removed}")
    require(dashboard, "import qs.modules.bar.weather", "OrbitalWeather {")

    print("Weather compact popup and shared orbit contract: PASS")


if __name__ == "__main__":
    main()
