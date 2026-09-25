#!/usr/bin/env python3
"""Regression contract for the accepted translucent Orbital Weather liquid sheet."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEATHER_DIR = ROOT / "modules/bar/weather"


def require(source: str, *features: str) -> None:
    for feature in features:
        if feature not in source:
            raise AssertionError(f"Weather liquid sheet lost {feature!r}")


def main() -> None:
    field = (WEATHER_DIR / "LiquidOrbitalField.qml").read_text(encoding="utf-8")
    orbital = (WEATHER_DIR / "OrbitalWeather.qml").read_text(encoding="utf-8")
    popup = (WEATHER_DIR / "WeatherPopupContent.qml").read_text(encoding="utf-8")
    dashboard = (ROOT / "modules/dashboard/DashWeather.qml").read_text(encoding="utf-8")

    # Visual parity, not implementation novelty, is the contract. The accepted
    # reference is the b0629861 continuous translucent ribbon: one deformed
    # annulus with smoky sheets/bands and moving caustics.
    require(
        field,
        "VISUAL CONTRACT (2026-09-25)",
        "readonly property int sampleCount: 120",
        "readonly property real baseThickness: Math.max(5.5,",
        "let outerThickness = root.baseThickness",
        "let innerThickness = root.baseThickness * 0.96",
        "function liquidSample(angle: real, time: real): var",
        "function traceClosed(ctx, points): void",
        "function traceOpen(ctx, points): void",
        "for (let sheet = 0; sheet < 2; ++sheet)",
        "for (let band = 0; band < 3; ++band)",
        "for (let streak = 0; streak < 4; ++streak)",
        "root.traceClosed(ctx, outer)",
        "root.traceClosed(ctx, inner.slice().reverse())",
        "root.sheetColorA",
        "root.sheetColorB",
        "root.podFill",
        "root.activePodFill",
        "renderStrategy: Canvas.Threaded",
        "renderTarget: Canvas.Image",
        "onTriggered: liquidCanvas.requestPaint()",
    )

    # These are the exact topology changes that produced the segmented/capsule
    # appearance seen in the regression screenshots.
    for forbidden in (
        "ShaderEffect {",
        "fragmentShader:",
        "function drawBridgeMass(",
        "function drawMassUnion(",
        "function drawPulseLobe(",
        "root.drawBridgeMass(",
        "root.drawMassUnion(",
        "ConnectedSurfaceIrisField",
    ):
        if forbidden in field:
            raise AssertionError(
                f"Liquid sheet regressed to segmented/shader topology: {forbidden!r}"
            )

    # Reduced visual effects may simplify highlights, but must not freeze the
    # physical surface motion.
    frame_block = field.split("FrameAnimation {", 1)[1].split("}", 1)[0]
    if "&& Appearance.effectsEnabled" in frame_block:
        raise AssertionError("Disabling visual effects must not freeze the liquid sheet")

    # Keep current popup/layout integration intact; only its renderer is pinned.
    require(
        orbital,
        "property bool liquidMode: false",
        "LiquidOrbitalField {",
        "hourAngles: root.hourAngles",
        "activeIndex: root.activeIndex",
        "animate: root.liquidAnimationActive",
    )
    require(
        popup,
        "liquidMode: true",
        "liquidAnimationActive: root.currentTab === 0",
    )
    if "liquidMode: true" in dashboard:
        raise AssertionError("Dashboard must retain its simpler shared orbital view")

    print("Weather translucent liquid-sheet contract: PASS")


if __name__ == "__main__":
    main()
