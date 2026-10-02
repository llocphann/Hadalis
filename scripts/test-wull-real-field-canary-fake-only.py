#!/usr/bin/env python3
"""Inert fake alpha and renderer-scope contract; never launches Qt."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
runner_text = (ROOT / "scripts/wull-manual-real-field-canary.py").read_text()
fixture = (ROOT / "scripts/wull-fixtures/real-field-canary/shell.qml").read_text()
actual_field = (ROOT / "modules/abyss/looks/AbyssField.qml").read_text()
actual_host = (ROOT / "modules/abyss/companion/AbyssCompanion.qml").read_text()
assert fixture.count("AbyssField {") == 1
assert fixture.count("AbyssCompanion {") == 1
assert fixture.count("FieldCase {") == 4
assert "readonly property bool shaderReady: realField.ready" in fixture
assert "records: []" in fixture and "waveTexture: null" in fixture
assert 'Quickshell.env("WULL_FIELD_CANARY_PRIVATE_PNG")' in fixture
assert "sheet.grabToImage" in fixture
assert "if (!cell.shaderReady)" in fixture
for category in ("FIELD_FRAME_NOT_PRESENTED", "FIELD_GRAPHICS_API_UNSUPPORTED",
                 "FIELD_EFFECT_UNQUALIFIED"):
    assert category in fixture and category in runner_text
assert '"--capture-default-backend"' in runner_text
assert 'env.pop("QSG_RHI_BACKEND", None)' in runner_text
assert 'env.pop("QT_QUICK_BACKEND", None)' in runner_text
for category in ("WINDOW_NOT_BACKING", "SHEET_DIMENSIONS_INVALID",
                 "FOUR_CELLS_UNAVAILABLE"):
    assert category in fixture and category in runner_text

assert "AbyssField.frag.qsb" in actual_field
assert "orientationAngle: root.edge" in actual_host
for marker in (
    'QT_QPA_PLATFORM": "offscreen"',
    '"QSG_RHI_BACKEND": "opengl"',
    '"QT_QUICK_BACKEND": "rhi"',
    "borrowed[\"private_env\"](xdg, output)",
    "borrowed[\"staged\"](owned)",
    "PRIVATE_IMAGE_UNQUALIFIED",
    "LIVE_PANEL_OR_MODULES=NOT_TESTED",
    "ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED",
):
    assert marker in runner_text, marker
assert "shell=True" not in runner_text
assert "git push" not in runner_text
assert "grim " not in runner_text
module = runpy.run_path(
    str(ROOT / "scripts/wull-manual-real-field-canary.py"),
    run_name="wull_inert_actual_shader_alpha",
)
paint = module["painted_cells"]
assert len(module["CELLS"]) == 4
w = h = 512
mask = bytearray(w * h)
for x0, y0 in module["CELLS"]:
    # Fake body plus independent shader-only corner, never actual pixels.
    for y in range(y0 + 65, y0 + 130):
        for x in range(x0 + 80, x0 + 140):
            mask[y * w + x] = 255
    for y in range(y0 + 3, y0 + 19):
        for x in range(x0 + 3, x0 + 19):
            mask[y * w + x] = 255
assert paint(mask)
corner_missing = bytearray(mask)
x0, y0 = module["CELLS"][2]
for y in range(y0 + 3, y0 + 19):
    for x in range(x0 + 3, x0 + 19):
        corner_missing[y * w + x] = 0
try:
    paint(corner_missing)
    raise AssertionError("missing actual-shader-only corner accepted")
except module["Unqualified"] as e:
    assert str(e) == "REAL_FIELD_PAINT_UNQUALIFIED"
no_body = bytearray(mask)
x0, y0 = module["CELLS"][1]
for y in range(y0 + 65, y0 + 130):
    for x in range(x0 + 80, x0 + 140):
        no_body[y * w + x] = 0
try:
    paint(no_body)
    raise AssertionError("missing body in second ROI accepted")
except module["Unqualified"] as e:
    assert str(e) == "REAL_FIELD_PAINT_UNQUALIFIED"
print("WULL_REAL_FIELD_CANARY_FAKE_ONLY_PASS")
