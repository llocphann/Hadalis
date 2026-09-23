#!/usr/bin/env python3
"""Regression contract for the popup-only animated liquid Weather orbit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORBITAL = ROOT / "modules/bar/weather/OrbitalWeather.qml"
LIQUID = ROOT / "modules/bar/weather/LiquidOrbitalField.qml"
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing animated-liquid token: {token!r}")


def main() -> None:
    orbital = ORBITAL.read_text(encoding="utf-8")
    liquid = LIQUID.read_text(encoding="utf-8")
    weather = WEATHER_CONTENT.read_text(encoding="utf-8")
    dashboard = DASH_WEATHER.read_text(encoding="utf-8")

    for token in (
        "property bool liquidMode: false",
        "property bool liquidAnimationActive: false",
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
        "readonly property int sampleCount: 96",
        "function liquidSample(angle: real, time: real): var",
        "Math.sin(angle * 3.0 - time * 1.15)",
        "function nodeInfluence(angle: real, nodeIndex: int, frame): var",
        "thickness += influence.profile",
        "tangentDrift += influence.profile * shoulder",
        "root.traceClosed(ctx, outer)",
        "root.traceClosed(ctx, inner.slice().reverse())",
        "Three travelling specular streaks visibly flow around the liquid.",
    ):
        require(liquid, token, "LiquidOrbitalField.qml")

    if "&& Appearance.effectsEnabled" in liquid.split("FrameAnimation {", 1)[1].split("}", 1)[0]:
        raise AssertionError("Liquid motion must not be disabled by the effects switch")
    if "ConnectedSurfaceIrisField" in liquid:
        raise AssertionError("Liquid animation must not regress to moving rigid SDF bodies")
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

    print("Weather animated liquid orbital contract: PASS")


if __name__ == "__main__":
    main()
