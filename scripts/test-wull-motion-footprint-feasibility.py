#!/usr/bin/env python3
"""INERT tested counterexample: static body rectangle is NOT a motion mask.

No Quickshell/Niri process, input injection, QML writes or production edit.
Only exact-source reviewed defaults, formulas and negative conditions.
"""
import ast
import math
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-motion-footprint-feasibility.py"
SOURCE = SCRIPT.read_text(encoding="utf-8")
ast.parse(SOURCE)
for forbidden in ("subprocess", "socket", "wdotool", "requests", "git push"):
    assert forbidden not in SOURCE
motion = runpy.run_path(str(SCRIPT), run_name="wull_motion_static_inert")
motion["verify_reviewed_source"]()
for path, expected in motion["SOURCE_BLOBS"].items():
    raw = (ROOT / path).read_bytes()
    assert motion["git_blob"](raw) == expected
    assert motion["git_blob"](raw + b"\n") != expected
for invalid in ("x", None, True, 22):
    try:
        motion["git_blob"](invalid)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid blob type accepted")
for invalid in (None, "./", 2):
    try:
        motion["verify_reviewed_source"](invalid)
    except ValueError:
        pass
    else:
        raise AssertionError("Untrusted source root accepted")

assert motion["TOP_PATH_TIP"] == (38.0, 2.0)
assert motion["BODY_WIDTH"] == 76
assert motion["BODY_HEIGHT"] == 92
assert motion["TOP_BODY_OFFSET"] == (18, 3)
neutral = motion["explicit_tip_vertical_scale"](0, 0)
assert neutral == {
    "y_scale": 1.0,
    "tip_y_relative_to_static_body": 2.0,
    "tip_y_relative_to_host": 5.0,
    "private_bbox_top_relative_to_host": 3,
}
stretch = motion["explicit_tip_vertical_scale"](0, 1)
assert stretch == {
    "y_scale": 1.06,
    "tip_y_relative_to_static_body": -3.4,
    "tip_y_relative_to_host": -0.4,
    "private_bbox_top_relative_to_host": 3,
}
# This is a POSSIBLE static source-state counterexample; no claim that
# a real Rust trace hits exactly 1 or that the QML frame rendered here.
assert stretch["tip_y_relative_to_host"] < 0
assert stretch["tip_y_relative_to_host"] < stretch[
    "private_bbox_top_relative_to_host"]
strongest = motion["explicit_tip_vertical_scale"](-1, 1)
assert strongest["y_scale"] == 1.095
assert strongest["tip_y_relative_to_host"] < stretch["tip_y_relative_to_host"]
for args in ((-1.001, 0), (0, 1.001), (0, math.nan),
             (False, 0), ("1", 0), (0, math.inf)):
    try:
        motion["explicit_tip_vertical_scale"](*args)
    except ValueError:
        pass
    else:
        raise AssertionError("Unreviewed motion input accepted")

budget = motion["nominal_parameter_budget"]()
assert budget["state_xscale_nominal"] == (.925, 1.075)
assert budget["state_yscale_nominal"] == (.905, 1.095)
assert budget["root_animated_scale_nominal"] == (.98775, 1.035)
assert budget["rotation_degrees_nominal"] == (-9.6, 10.59)
assert budget["bob_nominal_target_y"] == (-3.6, 1.8)
assert budget["max_pulse_halo_static_local"] == (76, 90.16)
assert budget["nominal_stretched_tip"] == stretch
assert budget["body_bbox"] == (76, 92)
assert budget["source_host_top"] == (112, 98)
assert budget["source_host_side"] == (98, 112)
assert budget["parent_config_scale"] == (.65, 1.5)
assert budget["parent_scale_1_5_nominal_bbox_top"] == (114, 138)
assert budget["parent_scale_1_5_nominal_bbox_side"] == (138, 114)
assert budget["parent_scale_1_5_nominal_bbox_top"][0] > 112
assert budget["parent_scale_1_5_nominal_bbox_top"][1] > 98
assert budget["parent_scale_1_5_nominal_bbox_side"][0] > 98
assert budget["independently_bounded_spring_runtime_extrema"] is False
assert budget["qt_transform_order_and_mask_coordinates_verified"] is False
assert budget["compositor_motion_hover_or_hit_accuracy"] == "not_run"
assert budget["mask_or_production_changed"] is False

# The pre-existing static scanline curve contract cannot become an
# animated, scale/halo interaction mask based on these calculations.
silhouette = runpy.run_path(
    str(ROOT / "scripts/wull-silhouette-band-prototype.py"),
    run_name="wull_static_band_inert_crosscheck")
assert silhouette["source_ok"](
    (ROOT / "modules/abyss/companion/WaterDropletBody.qml").read_bytes())
summary = silhouette["static_summary"]()
assert summary["static_body_bbox_pixels"] == 76 * 92
assert summary["animation_halo_scale_qualification"] == "not_run"
assert summary["live_pointer_and_hover"] == "not_run"
print("WULL_MOTION_FOOTPRINT_INERT_COUNTEREXAMPLE_PASS")
