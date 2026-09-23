#!/usr/bin/env python3
"""Regression contract for the popup-only continuous liquid-mass Weather orbit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORBITAL = ROOT / "modules/bar/weather/OrbitalWeather.qml"
LIQUID = ROOT / "modules/bar/weather/LiquidOrbitalField.qml"
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"
WEATHER_SERVICE = ROOT / "services/Weather.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing liquid-mass token: {token!r}")


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
        "id: conceptFooter",
        "Weather.airQuality?.available",
        "return -Math.PI / 2 + shiftedHour * Math.PI / 12",
        "LiquidOrbitalField {",
        "animate: root.liquidAnimationActive",
    ):
        require(orbital, token, "OrbitalWeather.qml")

    for token in (
        "FrameAnimation {",
        "onTriggered: liquidCanvas.requestPaint()",
        "Appearance.animationsEnabled",
        "renderStrategy: Canvas.Threaded",
        "renderTarget: Canvas.Image",
        "readonly property real activeNodeScale: 1.28",
        "function drawBridgeMass(ctx, segment: int, slot: int, time: real,",
        "const fraction = slot === 0 ? 0.32 : 0.68",
        "const tangentOffset = Math.sin(time * 0.57 + seed) * 2.8",
        "const normalOffset = Math.sin(time * 0.83 + seed * 1.7) * 3.4",
        "const majorPulse = 1",
        "const minorPulse = 1",
        "root.drawBridgeMass(ctx, segment, 0, time, grow, style, 1)",
        "root.drawBridgeMass(ctx, segment, 1, time, grow, style, 1)",
        "root.drawMassUnion(ctx, time, 0, root.bodyColor)",
        "Internal highlights are also moving masses, not strokes.",
    ):
        require(liquid, token, "LiquidOrbitalField.qml")

    # This renderer must never regress to an orbital line/ribbon whose surface
    # is merely decorated with animation. The connector geometry itself is the
    # moving union of node/bridge masses.
    for forbidden in (
        "outerThickness",
        "innerThickness",
        "traceClosed",
        "traceOpen",
        "ctx.stroke()",
        "ctx.lineTo(",
        "ConnectedSurfaceIrisField",
        "Timer {",
    ):
        if forbidden in liquid:
            raise AssertionError(
                f"Liquid mass renderer regressed to line/ribbon geometry: {forbidden!r}")

    if "&& Appearance.effectsEnabled" in liquid.split("FrameAnimation {", 1)[1].split("}", 1)[0]:
        raise AssertionError("Liquid mass motion must not be disabled by effectsEnabled")

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

    print("Weather continuous liquid-mass orbital contract: PASS")


if __name__ == "__main__":
    main()
