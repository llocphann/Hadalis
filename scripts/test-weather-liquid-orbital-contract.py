#!/usr/bin/env python3
"""Regression contract for the popup-only liquid Weather orbit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORBITAL = ROOT / "modules/bar/weather/OrbitalWeather.qml"
LIQUID = ROOT / "modules/bar/weather/LiquidOrbitalField.qml"
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"
IRIS_FIELD = ROOT / "modules/common/perimeter/ConnectedSurfaceIrisField.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing liquid-orbit token: {token!r}")


def main() -> None:
    orbital = ORBITAL.read_text(encoding="utf-8")
    liquid = LIQUID.read_text(encoding="utf-8")
    weather = WEATHER_CONTENT.read_text(encoding="utf-8")
    dashboard = DASH_WEATHER.read_text(encoding="utf-8")
    iris_field = IRIS_FIELD.read_text(encoding="utf-8")

    for token in (
        "property bool liquidMode: false",
        "property bool liquidAnimationActive: false",
        "LiquidOrbitalField {",
        "visible: !root.liquidMode || root.liquidFallback",
        "animate: root.liquidAnimationActive",
    ):
        require(orbital, token, "OrbitalWeather.qml")

    for token in (
        "FrameAnimation {",
        "Appearance.animationsEnabled",
        "Appearance.effectsEnabled",
        "readonly property int ribbonCount: 12",
        "readonly property real fuseDepth: 36",
        "readonly property var ribbonAngles:",
        "component LiquidBody: QtObject",
        "readonly property string shapeId:",
        "readonly property var liquidShapes: [",
        "ConnectedSurfaceIrisField {",
        "shapes: root.liquidShapes",
        "tint: root.fieldColor",
        "rimColor: root.edgeColor",
        "field.shaderStatus === ShaderEffect.Error",
    ):
        require(liquid, token, "LiquidOrbitalField.qml")

    if "Timer {" in liquid:
        raise AssertionError("Liquid orbit must use the scene-frame clock, not a fixed Timer")
    if "ShaderEffectSource" in liquid or "MultiEffect" in liquid:
        raise AssertionError("Liquid orbit must remain a single-pass iRiS field")
    if liquid.count("LiquidBody { id:") != 20:
        raise AssertionError("Liquid orbit must keep exactly 12 ribbon + 8 hour bodies")
    if "readonly property var liquidShapes: {" in liquid:
        raise AssertionError("Liquid shapes must stay persistent instead of reallocating every frame")

    for token in (
        "liquidMode: true",
        "liquidAnimationActive: root.currentTab === 0",
        "anchors.right: parent.right",
    ):
        require(weather, token, "WeatherPopupContent.qml")

    if "liquidMode: true" in dashboard:
        raise AssertionError("Dashboard Weather must not opt into popup liquid mode")

    require(iris_field, 'list[i]?.id ?? list[i]?.shapeId ?? ""',
            "ConnectedSurfaceIrisField.qml")

    print("Weather liquid orbital contract: PASS")


if __name__ == "__main__":
    main()
