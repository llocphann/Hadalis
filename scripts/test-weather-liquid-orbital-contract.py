#!/usr/bin/env python3
"""Regression contract for the popup's animated liquid orbit."""

from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
WEATHER_DIR = ROOT / "modules/bar/weather"


def require(source: str, *features: str) -> None:
    for feature in features:
        if feature not in source:
            raise AssertionError(f"Weather liquid orbit lost {feature!r}")


def main() -> None:
    field = (WEATHER_DIR / "LiquidOrbitalField.qml").read_text()
    shader_path = WEATHER_DIR / "LiquidOrbitalField.frag"
    shader = shader_path.read_text()
    compiled_path = WEATHER_DIR / "LiquidOrbitalField.frag.qsb"
    orbital = (WEATHER_DIR / "OrbitalWeather.qml").read_text()
    popup = (WEATHER_DIR / "WeatherPopupContent.qml").read_text()
    dashboard = (ROOT / "modules/dashboard/DashWeather.qml").read_text()

    # The GPU field is primary; the Canvas is a fallback for Qt backends
    # which cannot compile the bundled shader pack.
    require(field, "ShaderEffect {", 'fragmentShader: Qt.resolvedUrl("LiquidOrbitalField.frag.qsb")',
            "visible: status === ShaderEffect.Compiled",
            "visible: liquidShader.status !== ShaderEffect.Compiled",
            "renderTarget: Canvas.Image", "FrameAnimation {",
            "seconds: root.timeSeconds", "property int activeIndex: 0")
    if "&& Appearance.effectsEnabled" in field.split("FrameAnimation {", 1)[1].split("}", 1)[0]:
        raise AssertionError("Disabling visual effects must not freeze the orbit")
    if not compiled_path.is_file() or compiled_path.stat().st_size < 1000:
        raise AssertionError("Compiled Qt shader pack is missing")

    # One shaded distance field has a moving contour and independent folds.
    require(shader, "float softUnion(", "fieldDistance = softUnion(",
            "float displacement =", "float neck =", "float foldPhase =",
            "float brightFold =", "float darkFold =", "float fineCaustic =",
            "float podAlpha =", "float halo =", "u.seconds", "u.selectedIndex")
    if "ctx.stroke()" in field or "ctx.lineTo(" in field:
        raise AssertionError("Fallback connector must be a mass union, not a stroke")

    qsb = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"
    if Path(qsb).is_file():
        with tempfile.TemporaryDirectory() as temp_dir:
            rebuilt = Path(temp_dir) / "LiquidOrbitalField.frag.qsb"
            subprocess.run([qsb, "--qt6", "-o", str(rebuilt), str(shader_path)],
                           check=True, capture_output=True, text=True)
            if rebuilt.read_bytes() != compiled_path.read_bytes():
                raise AssertionError("Bundled shader pack differs from its GLSL source")

    require(orbital, "property bool liquidMode: false", "LiquidOrbitalField {",
            "hourAngles: root.hourAngles", "activeIndex: root.activeIndex",
            "animate: root.liquidAnimationActive")
    require(popup, "liquidMode: true",
            "liquidAnimationActive: root.currentTab === 0")
    if "liquidMode: true" in dashboard:
        raise AssertionError("Dashboard must retain its simpler shared orbital view")

    print("Weather animated liquid orbital contract: PASS")


if __name__ == "__main__":
    main()
