#!/usr/bin/env python3
"""FAKE-ONLY 12-case paired full/core static exterior alpha contract.

No Qt, Wayland, screenshot, network, desktop access, source mutation, or
publication; all image bytes are generated from synthetic RGBA fixtures.
"""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL_FILE = ROOT / "scripts/wull-private-static-paired-matrix-model.py"
ALPHA_FILE = ROOT / "scripts/wull-private-painted-alpha-model.py"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(MODEL_FILE) == "b8870420db8d1e6cc08f1f5b0f792c4ab186be61"
assert blob(ALPHA_FILE) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
model = runpy.run_path(str(MODEL_FILE),
                       run_name="wull_matrix_fake_only_classifier")
alpha = runpy.run_path(str(ALPHA_FILE),
                       run_name="wull_matrix_fake_only_png_decoder")
assert model["ALPHA_BLOB"] == blob(ALPHA_FILE)
assert model["EDGES"] == ("top", "right", "bottom", "left")
assert model["SCALES"] == (0.65, 1.0, 1.5)
assert model["CANVAS"] == (320, 300)
assert model["HOST_ORIGIN"] == (100, 100)
assert model["MIN_INSIDE_PIXELS"] >= 8
assert model["spec"](0)[0:2] == ("top", 0.65)
assert model["spec"](11)[0:2] == ("left", 1.5)
assert model["spec"](3)[2][2:4] == (98*.65, 112*.65)


def rejected(reason, function, *args):
    try:
        function(*args)
    except model["Unqualified"] as exc:
        assert str(exc) == reason, (str(exc), reason)
    else:
        raise AssertionError("Unsafe synthetic input accepted: " + reason)


def chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data +
            struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))


def fake_png(points):
    width, height = model["CANVAS"]
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend((81, 93, 107, 255) if (x, y) in points
                       else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
            + chunk(b"IEND", b""))


# This interior patch and outer points apply to ALL source-mapped host
# rects, including 0.65 and 1.5 scales and both horizontal/vertical edges.
interior = {(x, y) for x in range(148, 154) for y in range(142, 148)}
outside_left = (60, 150)
outside_right = (260, 150)
full_both = fake_png(interior | {outside_left})
core_both = fake_png(interior | {outside_left})
core_disjoint = fake_png(interior | {outside_right})
just_inside = fake_png(interior)
transparent = fake_png(set())
clipped = fake_png(interior | {(0, 0)})

cases = []
for index in range(12):
    edge, scale, geometry = model["spec"](index)
    assert all(isinstance(v, (int, float)) for v in geometry)
    assert geometry[0] >= 2 * alpha["EDGE_MARGIN"]
    assert geometry[1] >= 2 * alpha["EDGE_MARGIN"]
    result = model["classify"](index, full_both, core_both, alpha)
    assert result["edge"] == edge and result["scale"] == scale
    assert result["composite_outside_host"] is True
    assert result["source_core_outside_host"] is True
    assert result["same_pixel_exterior_overlap"] is True
    cases.append(result)
    disjoint = model["classify"](index, full_both, core_disjoint, alpha)
    assert disjoint["composite_outside_host"] is True
    assert disjoint["source_core_outside_host"] is True
    assert disjoint["same_pixel_exterior_overlap"] is False
    one_sided = model["classify"](index, full_both, just_inside, alpha)
    assert one_sided["composite_outside_host"] is True
    assert one_sided["source_core_outside_host"] is False
    assert one_sided["same_pixel_exterior_overlap"] is False

assert model["classify"](0, just_inside, just_inside, alpha) == {
    "edge": "top", "scale": 0.65,
    "composite_outside_host": False,
    "source_core_outside_host": False,
    "same_pixel_exterior_overlap": False,
}
rejected("CASE_INDEX_INVALID", model["spec"], True)
rejected("CASE_INDEX_INVALID", model["spec"], 12)
rejected("PRIVATE_PNG_INVALID",
         model["classify"], 0, b"host-private-data", core_both, alpha)
rejected("MISSING_INSIDE_PAINT",
         model["classify"], 0, transparent, core_both, alpha)
rejected("CAPTURE_PAINT_REACHES_CANVAS_EDGE",
         model["classify"], 0, clipped, core_both, alpha)
rejected("PINNED_ALPHA_PARSER_REQUIRED",
         model["classify"], 0, full_both, core_both,
         {**alpha, "ALPHA_THRESHOLD": 2})
summary = model["summarize"](cases)
assert summary["qualified_case_count"] == 12
assert summary["session_source"] == "one_private_qt_process"
assert summary["captures_sequential_not_simultaneous"] is True
assert summary["core_scene_altered_sibling_visibility"] is True
assert summary["compositor_clip_and_input"] == "not_tested"
assert summary["dynamic_painted_motion"] == "not_tested"
assert summary["production_mask_changed"] is False
assert len(summary["cases"]) == 12
for forbidden in (
    "/home/", "host_rect", "local_png", "alpha_bytes",
    "private_path", "pixel_counts", "desktop_data", "raw_image",
):
    assert forbidden not in json.dumps(summary)
rejected("INCOMPLETE_PAIRED_MATRIX",
         model["summarize"], cases[:-1])
dup = copy.deepcopy(cases)
dup[-1] = dup[0]
rejected("PAIRED_MATRIX_CASE_INVALID",
         model["summarize"], dup)
spoof = copy.deepcopy(cases)
spoof[0]["same_pixel_exterior_overlap"] = "true"
rejected("PAIRED_MATRIX_CASE_INVALID",
         model["summarize"], spoof)
spoof = copy.deepcopy(cases)
spoof[0]["coordinates"] = [60, 150]
rejected("PAIRED_MATRIX_CASE_INVALID",
         model["summarize"], spoof)
spoof = copy.deepcopy(cases)
spoof[1]["same_pixel_exterior_overlap"] = True
spoof[1]["composite_outside_host"] = False
rejected("PAIRED_MATRIX_CASE_INVALID",
         model["summarize"], spoof)
print("WULL_PRIVATE_PAIRED_STATIC_MATRIX_INERT_PASS")
