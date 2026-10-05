#!/usr/bin/env python3
"""Guard the bounded Wull render-cost policy without changing torso quality."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
body = (ROOT / "modules/abyss/companion/WaterDropletBody.qml").read_text(encoding="utf-8")
shader = (ROOT / "modules/abyss/companion/WaterDropletMaterial.frag").read_text(encoding="utf-8")

# The 76 px torso remains on the user-selected tier. Only tiny limbs and
# orbital droplets use the low-cost tier because their high-tier differences
# are sub-pixel at their rendered sizes.
assert "readonly property vector4d materialRenderingUniform: Qt.vector4d(qualityLevel, translucency, 0, 0)" in body
assert "readonly property vector4d smallMaterialRenderingUniform: Qt.vector4d(0, translucency, 0, 0)" in body
assert body.count("property vector4d rendering: root.materialRenderingUniform") == 1
assert body.count("property vector4d rendering: root.smallMaterialRenderingUniform") == 2

# The floor reflection is compressed to a 13-18 px contact strip and already
# softened by the contact shader. Keep the source capture at native Wull size
# rather than paying four times the offscreen pixels at tier 2.
assert "textureSize: Qt.size(76, 82)" in body
assert "Qt.size(152, 164)" not in body

# Lock the tiered ray-search structure that makes the small-material route a
# meaningful reduction. Tier 0 has 10 coarse steps / 3 refinements, compared
# with 18/5 at balanced and 28/7 at high.
assert "int steps=rendering.x>1.5 ? 28 : rendering.x>0.5 ? 18 : 10;" in shader
assert "int refinements=rendering.x>1.5 ? 7 : rendering.x>0.5 ? 5 : 3;" in shader
assert "if (rendering.x>1.5)" in shader

print("WULL_RENDER_COST_CONTRACT_PASS")
