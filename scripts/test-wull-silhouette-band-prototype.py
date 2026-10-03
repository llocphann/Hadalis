#!/usr/bin/env python3
"""INERT proof obligations for a static, NOT production, Wull curve model.

No compositor, QML mask staging, backend, network, or real input.
"""
import ast
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/wull-silhouette-band-prototype.py"
BODY = ROOT / "modules/abyss/companion/WaterDropletBody.qml"
text = SOURCE.read_text(encoding="utf-8")
ast.parse(text)
assert "subprocess" not in text
assert "wdotool" not in text
assert "private" not in text.split("if __name__")[0].split("def static_summary")[0]
m = runpy.run_path(str(SOURCE), run_name="wull_static_silhouette_inert")
# This research model deliberately pins a HISTORICAL contour. Exercise that
# blob and rejection of altered bytes, without requiring production to revert.
reviewed = subprocess.run(
    ["git", "cat-file", "blob", m["REVIEWED_BODY_BLOB"]],
    cwd=ROOT, check=True, capture_output=True).stdout
assert m["source_ok"](reviewed)
assert not m["source_ok"](reviewed + b"\n")
if BODY.read_bytes() != reviewed:
    assert not m["source_ok"](BODY.read_bytes())
assert not m["source_ok"](b"")
assert not m["source_ok"]("invalid")
assert (m["BASE_WIDTH"], m["BASE_HEIGHT"]) == (76, 92)
assert m["SUBDIVISIONS"] == 400
assert m["INSET"] >= 1.5

for bad in (-0.1, 1.1, float("nan"), float("inf"), "0.5"):
    try:
        m["cubic"]((0, 0), (1, 1), (2, 2), (3, 3), bad)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid static Bezier parameter accepted")
assert m["cubic"]((0, 0), (1, 2), (2, 4), (3, 6), 0) == (0, 0)
assert m["cubic"]((0, 0), (1, 2), (2, 4), (3, 6), 1) == (3, 6)

outline = m["static_outline"]()
assert len(outline) == 1601
assert outline[0] == outline[-1] == (38.0, 2.0)
assert len(m["intersections"](outline, 45.5)) == 2

original = m["top_interior_bands"]()
assert 30 <= len(original) <= 64
assert len(original) < m["BASE_HEIGHT"]
area = sum(w * height for _, _, w, height in original)
# An intentionally conservative interior-only shape, NOT a release mask:
# it loses visible stroke, tip pixels and animated halo coverage.
assert 2750 <= area <= 3300
assert area < .5 * m["BASE_WIDTH"] * m["BASE_HEIGHT"]
original_pixels = set()
for x, y, w, height in original:
    assert 0 <= x < 76 and 0 <= y < 92
    assert 0 < w <= 76 - x and 0 < height <= 92 - y
    for py in range(y, y + height):
        # Across 3 sub-row samples each band must remain WITHIN the
        # source-derived static outline with a positive side inset.
        for row_sample in (.01, .5, .99):
            hits = m["intersections"](outline, py + row_sample)
            assert len(hits) == 2
            assert hits[0] + 1.3 <= x
            assert x + w <= hits[1] - 1.3
        for px in range(x, x + w):
            assert (px, py) not in original_pixels
            original_pixels.add((px, py))
assert len(original_pixels) == area
assert (38, 46) in original_pixels
assert (0, 46) not in original_pixels
assert (75, 46) not in original_pixels
assert (38, 0) not in original_pixels

sample = (20, 30, 15, 8)
assert m["rotated"](sample, "top") == sample
assert m["rotated"](sample, "bottom") == (41, 54, 15, 8)
assert m["rotated"](sample, "left") == (54, 20, 8, 15)
assert m["rotated"](sample, "right") == (30, 41, 8, 15)
for edge in ("top", "bottom", "left", "right"):
    bands = m["edge_bands"](edge)
    assert len(bands) == len(original)
    assert sum(w * height for _, _, w, height in bands) == area
    host_w, host_h = m["HOST"][edge]
    seen = set()
    for x, y, width, height in bands:
        assert 0 <= x < host_w and 0 <= y < host_h
        assert width > 0 and height > 0
        assert x + width <= host_w and y + height <= host_h
        for py in range(y, y + height):
            for px in range(x, x + width):
                assert (px, py) not in seen
                seen.add((px, py))
    assert len(seen) == area
for bad_edge in ("", "diagonal", None, "TOP"):
    try:
        m["edge_bands"](bad_edge)
    except ValueError as err:
        assert str(err) == "unreviewed_static_edge"
    else:
        raise AssertionError("Unreviewed static edge accepted")
for bad_rect in (
    (0, 0, 0, 2), (-1, 0, 1, 1), (70, 0, 7, 1),
    (0, 91, 1, 2), (1.2, 1, 2, 3), (True, 1, 2, 3),
):
    try:
        m["rotated"](bad_rect, "top")
    except ValueError:
        pass
    else:
        raise AssertionError("Unreviewed static rectangle accepted")
summary = m["static_summary"]()
assert summary["kind"] == "inert_static_source_pinned_wull_curve_band_feasibility"
assert summary["conservative_interior_pixels"] == area
assert summary["static_body_bbox_pixels"] == 6992
assert summary["max_rectangles_per_edge"] <= 64
assert summary["rectangles_by_edge"] == dict.fromkeys(
    ("top", "bottom", "left", "right"), len(original))
assert summary["live_pointer_and_hover"] == "not_run"
assert summary["animation_halo_scale_qualification"] == "not_run"
assert summary["production_changes"] is False
payload = json.dumps(summary)
for forbidden in ('"x":', '"y":', '"raw_pointer_coordinates":',
                  '"observed_point":', '"requested_point":'):
    assert forbidden not in payload, forbidden
print("WULL_SILHOUETTE_BAND_INERT_FEASIBILITY_PASS")
