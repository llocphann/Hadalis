#!/usr/bin/env python3
"""Regression contract for the popup-only concept-matched liquid Weather orbit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORBITAL = ROOT / "modules/bar/weather/OrbitalWeather.qml"
LIQUID = ROOT / "modules/bar/weather/LiquidOrbitalField.qml"
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"
WEATHER_SERVICE = ROOT / "services/Weather.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing concept-liquid token: {token!r}")


def main() -> None:
    orbital = ORBITAL.read_text(encoding="utf-8")
    liquid = LIQUID.read_text(encoding="utf-8")
    weather = WEATHER_CONTENT.read_text(encoding="utf-8")
    dashboard = DASH_WEATHER.read_text(encoding="utf-8")
    weather_service = WEATHER_SERVICE.read_text(encoding="utf-8")

    for token in (
        "property bool liquidMode: false",
        "property bool liquidAnimationActive: false",
        "readonly property real conceptOrbitAspect: 1.168",
        "readonly property real activePointSize: pointSize * 1.28",
        "readonly property real desiredOrbitRadiusX: width * 0.245",
        "Math.min(48, width * 0.086)",
        "liquidOrbitRadiusY * conceptOrbitAspect",
        "readonly property real footerHeight: root.liquidMode ? 30 : 0",
        "Math.max(42, Math.min(54, width * 0.13))",
        "Math.max(52, Math.min(66, height * 0.25))",
        "id: conceptFooter",
        "Weather.airQuality?.available",
        "if (root.liquidMode)",
        "return -Math.PI / 2 + shiftedHour * Math.PI / 12",
        "LiquidOrbitalField {",
        "visible: !root.liquidMode",
        "animate: root.liquidAnimationActive",
    ):
        require(orbital, token, "OrbitalWeather.qml")

    for token in (
        "FrameAnimation {",
        "onTriggered: liquidCanvas.requestPaint()",
        "Appearance.animationsEnabled",
        "renderStrategy: Canvas.Threaded",
        "renderTarget: Canvas.Image",
        "readonly property int sampleCount: 120",
        "function nodeRadius(nodeIndex: int, time: real): real",
        "const conceptScale = active ? 1.28 : 1.0",
        "Math.sqrt(Math.max(0, radius * radius - signedArc * signedArc))",
        "function smoothMax(a: real, b: real, k: real): real",
        "outerThickness = root.smoothMax(",
        "innerThickness = root.smoothMax(",
        "root.traceClosed(ctx, outer)",
        "root.traceClosed(ctx, inner.slice().reverse())",
        "Paint the hour pods as glass volumes inside the same continuous",
        "Two translucent moving sheets overlap inside the same annulus.",
        "Layered translucent sheets running around the whole ring.",
        "Moving internal caustic-like lines following the deformed ribbon.",
    ):
        require(liquid, token, "LiquidOrbitalField.qml")

    if "&& Appearance.effectsEnabled" in liquid.split("FrameAnimation {", 1)[1].split("}", 1)[0]:
        raise AssertionError("Liquid motion must not be disabled by the effects switch")
    if "ConnectedSurfaceIrisField" in liquid:
        raise AssertionError("Concept liquid must not regress to rigid SDF bodies")
    if "Timer {" in liquid:
        raise AssertionError("Liquid orbit must use scene-frame animation, not a fixed Timer")

    for token in (
        "liquidMode: true",
        "liquidAnimationActive: root.currentTab === 0",
        "anchors.right: parent.right",
    ):
        require(weather, token, "WeatherPopupContent.qml")

    if "liquidMode: true" in dashboard:
        raise AssertionError("Dashboard Weather must not opt into popup liquid mode")

    for token in (
        "const currentBucket = Math.floor(nowH / 3) * 3",
        "hour < currentBucket",
        "bucketStart.setHours(Math.floor(now.getHours() / 3) * 3)",
        "hour % 3 !== 0",
    ):
        require(weather_service, token, "Weather.qml")

    print("Weather concept liquid orbital contract: PASS")


if __name__ == "__main__":
    main()
