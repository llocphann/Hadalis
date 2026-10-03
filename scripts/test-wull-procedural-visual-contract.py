#!/usr/bin/env python3
"""Procedural renderer safety and semantic behavior; no aesthetic verdict."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
COMPANION = ROOT / "modules/abyss/companion"
# Runtime art must remain geometry/material, not an image/pose pack.
for filename in ("WaterDropletBody.qml", "WaterDropletFace.qml", "AbyssCompanion.qml"):
    text = (COMPANION / filename).read_text()
    assert not re.search(r"\b(?:Image|AnimatedImage|AnimatedSprite|SpriteSequence|Video)\s*\{", text)
    assert not re.search(r"(?:\.png|\.gif|\.webp|\.apng|\.jpg|mascot/manifest)", text, re.I)
body = (COMPANION / "WaterDropletBody.qml").read_text()
host = (COMPANION / "AbyssCompanion.qml").read_text()
for contract in ("implicitWidth: 76", "implicitHeight: 92", "property real orientationAngle: 0",
                 "rotation: -root.orientationAngle", "running: root.motionEnabled"):
    assert contract in body, contract
assert "Timer {" not in body, "Rust schedules semantic state; renderer interpolates locally"
assert "implicitWidth: verticalEdge ? 98 : 112" in host
assert "implicitHeight: verticalEdge ? 112 : 98" in host
defaults = json.loads((ROOT / "defaults/config.json").read_text())
assert defaults["abyss"]["companion"]["enabled"] is False
# Reproducible shader/source pairing where the shader compiler is installed.
compiler = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"
for filename in ("WaterDropletMaterial.frag", "WaterDropletContact.frag"):
    shader = COMPANION / filename
    package = shader.with_suffix(".frag.qsb")
    assert package.is_file() and package.stat().st_size > 1000
    if Path(compiler).is_file():
        with tempfile.TemporaryDirectory() as temporary:
            rebuilt = Path(temporary) / package.name
            subprocess.run([compiler, "--qt6", "-o", str(rebuilt), str(shader)], check=True, capture_output=True)
            assert rebuilt.read_bytes() == package.read_bytes(), f"stale bundled Wull shader: {filename}"
subprocess.run(["node", str(ROOT / "scripts/test-wull-expressions.cjs")], check=True)
print("WULL_PROCEDURAL_VISUAL_SOURCE_SAFETY_PASS")
