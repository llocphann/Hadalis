#!/usr/bin/env python3
"""Contract for the responsive connected Weather popup and shared orbit."""

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

    # StyledPopup supplies its output size to content. Both axes remain
    # bounded for desktop and compact presentations.
    require(wrapper, "StyledPopup {", "WeatherPopupContent {",
            "availableWidth: root.presentationWindow?.width",
            "availableHeight: root.presentationWindow?.height")
    require(source, "property real availableWidth:", "property real availableHeight:",
            "readonly property real panelWidth:", "readonly property real panelHeight:",
            "Math.min(1440,", "Math.min(960,", "root.availableWidth - 64",
            "root.availableHeight - Appearance.sizes.barHeight - 64",
            "readonly property int tabCount: 2", "property int currentTab: 0",
            "property int selectedHourIndex: 0")

    # Pages slide vertically inside one clipped surface. Navigation arrows
    # belong only to Hourly; the dot rail stays at the right edge.
    require(source, "id: tabViewport", "clip: true",
            "y: (0 - root.currentTab) * tabViewport.height",
            "y: (1 - root.currentTab) * tabViewport.height",
            "liquidMode: true", "activeIndex: root.selectedHourIndex",
            "function cycleHour(direction): void",
            "visible: root.currentTab === 0", "id: modeSwitch",
            "id: tabIndicator", "anchors.right: parent.right",
            "anchors.verticalCenter: parent.verticalCenter",
            "model: (Weather.data?.forecast ?? []).slice(0, 7)",
            "id: sunTimeline", "WheelHandler {")
    if source.count("Behavior on y") != 2:
        raise AssertionError("Hourly and Daily must each retain a slide transition")
    if "WeatherCard {" in source:
        raise AssertionError("Daily details must not fall back to the old flat cards")

    require(orbital, "(Weather.data?.hourly ?? []).slice(0, 8)",
            "function orbitAngleForHour(label): real",
            "readonly property real conceptOrbitAspect:",
            "readonly property real orbitRadiusX:",
            "readonly property real orbitRadiusY:",
            "readonly property real footerHeight:", "id: conceptFooter",
            "Weather.airQuality?.available", "root.liquidMode")
    require(dashboard, "import qs.modules.bar.weather", "OrbitalWeather {")

    print("Weather responsive popup and shared orbit contract: PASS")


if __name__ == "__main__":
    main()
