#!/usr/bin/env python3
"""Regression contract for the popup-only continuous liquid-mass Weather orbit."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIQUID = ROOT / "modules/bar/weather/LiquidOrbitalField.qml"
WEATHER_CONTENT = ROOT / "modules/bar/weather/WeatherPopupContent.qml"
DASH_WEATHER = ROOT / "modules/dashboard/DashWeather.qml"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing liquid-mass token: {token!r}")


def main() -> None:
    liquid = LIQUID.read_text(encoding="utf-8")
    weather = WEATHER_CONTENT.read_text(encoding="utf-8")
    dashboard = DASH_WEATHER.read_text(encoding="utf-8")

    # Visual topology is the contract. The 2026-09-24 regression happened
    # because compile success was treated as permission to replace this moving
    # mass union with a ring-distance shader. Keep the accepted renderer as 8
    # node masses + exactly 2 independently moving bridge masses per segment.
    for token in (
        "Regression guard (2026-09-25)",
        "FrameAnimation {",
        "onTriggered: liquidCanvas.requestPaint()",
        "Appearance.animationsEnabled",
        "renderStrategy: Canvas.Threaded",
        "renderTarget: Canvas.Image",
        "readonly property real activeNodeScale: 1.28",
        "Math.max(6.8, Math.min(10.0, root.regularNodeRadius * 0.46))",
        "function drawBridgeMass(ctx, segment: int, slot: int, time: real,",
        "const fraction = slot === 0 ? 0.32 : 0.68",
        "const tangentOffset = Math.sin(time * 0.57 + seed) * 2.8",
        "const normalOffset = Math.sin(time * 0.83 + seed * 1.7) * 3.4",
        "Math.max(23, Math.min(34, arcLength * 0.37))",
        "root.drawBridgeMass(ctx, segment, 0, time, grow, style, 1)",
        "root.drawBridgeMass(ctx, segment, 1, time, grow, style, 1)",
        "root.drawMassUnion(ctx, time, 0, root.bodyColor)",
        "function drawBridgeSheets(ctx, time: real): void",
        "opacity: Appearance.effectsEnabled ? 0.78 : 0.70",
        "Internal highlights are also moving masses, not strokes.",
    ):
        require(liquid, token, "LiquidOrbitalField.qml")

    # A third bridge slot, annulus tracing, or an automatically selected shader
    # is not the same visual object even if it animates and compiles.
    for forbidden in (
        "ShaderEffect {",
        "fragmentShader:",
        "visible: liquidShader.status",
        "fieldDistance",
        "ringDistance",
        "drawPulseLobe",
        "slot === 1 ? 0.50 : 0.76",
        "root.drawBridgeMass(ctx, segment, 2",
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
                f"Liquid mass renderer regressed to ribbon/shader topology: {forbidden!r}")

    if "&& Appearance.effectsEnabled" in liquid.split("FrameAnimation {", 1)[1].split("}", 1)[0]:
        raise AssertionError("Liquid mass motion must not be disabled by effectsEnabled")

    for token in (
        "liquidMode: true",
        "liquidAnimationActive: root.currentTab === 0",
    ):
        require(weather, token, "WeatherPopupContent.qml")

    if "liquidMode: true" in dashboard:
        raise AssertionError("Dashboard Weather must not opt into popup liquid mode")

    print("Weather continuous liquid-mass orbital contract: PASS")


if __name__ == "__main__":
    main()
