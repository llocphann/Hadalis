#!/usr/bin/env python3
"""INERT, no-Git publication schema, pin, redaction and branch scope checks."""
import ast
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
PUBLISHER = ROOT / "scripts/wull-motion-inert-publish.py"
code = PUBLISHER.read_text(encoding="utf-8")
ast.parse(code)
m = runpy.run_path(str(PUBLISHER), run_name="inert_wull_publisher_contract")
EXPECTED_BLOBS = {
    "scripts/wull-silhouette-band-prototype.py":
        "34dfa1710be2c7c1d1a500d04a5fd53c9b4489a4",
    "scripts/test-wull-silhouette-band-prototype.py":
        "e7161aa49f6c17c9213d47f7cefd21cbecf5bd1f",
    "scripts/wull-motion-footprint-feasibility.py":
        "2e307ee23bf076c99d0b1b60f8230c3bc40182cb",
    "scripts/test-wull-motion-footprint-feasibility.py":
        "7669ae72c86a0b1d17cf5efb847b0474ebfddfb2",
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/companion/CompanionBridge.qml":
        "93c8d99497988f86660547773e8c30d90ac4bb66",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
}
assert m["REVIEWED"] == EXPECTED_BLOBS
assert m["TESTS"] == (
    ("bezier", "scripts/test-wull-silhouette-band-prototype.py",
     "WULL_SILHOUETTE_BAND_INERT_FEASIBILITY_PASS"),
    ("motion", "scripts/test-wull-motion-footprint-feasibility.py",
     "WULL_MOTION_FOOTPRINT_INERT_COUNTEREXAMPLE_PASS"),
)
assert m["MODELS"] == (
    ("bezier", "scripts/wull-silhouette-band-prototype.py"),
    ("motion", "scripts/wull-motion-footprint-feasibility.py"),
)
for marker in (
    'private_clean_owned_dev_clone_required',
    'private_inert_evidence_commit',
    'remote_diverged_private_inert_receipt_retained',
    'reviewed_static_or_motion_dependency_changed',
    'HEAD:refs/heads/dev',
    'git("rebase", "--onto", remote, old_parent)',
    '"--acknowledge-inert-motion-receipt"',
):
    # Test the actual exact API strings, not simulated real execution.
    if marker == "private_inert_evidence_commit":
        marker = 'not_exclusive_single_inert_evidence_commit'
    assert marker in code, marker
for forbidden in ('"reset"', '"--force"', '"/dev/uinput"',
                  "wdotool", "subprocess.Popen(", "niri msg"):
    assert forbidden not in code, forbidden

bezier = {
    "kind": "inert_static_source_pinned_wull_curve_band_feasibility",
    "production_changes": False,
    "live_pointer_and_hover": "not_run",
    "animation_halo_scale_qualification": "not_run",
    "static_body_bbox_pixels": 6992,
    "conservative_interior_pixels": 3006,
    "max_rectangles_per_edge": 43,
    "rectangles_by_edge": dict.fromkeys(
        ("top", "bottom", "left", "right"), 43),
}
motion = {
    "mask_or_production_changed": False,
    "compositor_motion_hover_or_hit_accuracy": "not_run",
    "independently_bounded_spring_runtime_extrema": False,
    "qt_transform_order_and_mask_coordinates_verified": False,
    "body_bbox": [76, 92],
    "source_host_top": [112, 98],
    "source_host_side": [98, 112],
    "state_xscale_nominal": [.925, 1.075],
    "state_yscale_nominal": [.905, 1.095],
    "parent_config_scale": [.65, 1.5],
    "parent_scale_1_5_nominal_bbox_top": [114, 138],
    "parent_scale_1_5_nominal_bbox_side": [138, 114],
    "nominal_stretched_tip": {
        "y_scale": 1.06,
        "tip_y_relative_to_static_body": -3.4,
        "tip_y_relative_to_host": -.4,
        "private_bbox_top_relative_to_host": 3,
    },
}
report = m["allow_report"](bezier, motion, "a" * 40, "b" * 40)
assert report["status"] == "pass"
assert report["scope"] == "exact_source_static_formula_only_no_desktop_or_pointer"
assert report["static_interior_area_pixels"] == 3006
assert report["static_rectangles_each_edge"] == 43
assert report["nominal_stretch_tip_host_y"] == -.4
assert report["spring_and_qt_composition"] == "unqualified"
assert report["actual_animated_rust_frame"] == "not_run"
assert report["quickshell_compositor_pointer_hover"] == "not_run"
assert report["production_mask_changed"] is False
assert report["raw_coordinates_or_screenshots"] == "never_collected"
for forbidden in ('"x":', '"y":', '"file_path":', '"screenshot":',
                  '"backend_private_log":', '"observed_pointer":'):
    assert forbidden not in json.dumps(report)
# Extra unreviewed input MUST NOT leave the allowlisted public payload.
extra = m["allow_report"](
    {**bezier, "host_absolute_x": 23456},
    {**motion, "private_host_name": "secret"}, "a" * 40, "b" * 40)
assert extra == report
for bad_bezier, bad_motion, sha, parent in (
    ({**bezier, "conservative_interior_pixels": 99999},
     motion, "a" * 40, "b" * 40),
    ({**bezier, "max_rectangles_per_edge": True},
     motion, "a" * 40, "b" * 40),
    ({**bezier, "rectangles_by_edge": {"top": 43}},
     motion, "a" * 40, "b" * 40),
    (bezier, {**motion, "compositor_motion_hover_or_hit_accuracy": "pass"},
     "a" * 40, "b" * 40),
    (bezier, {**motion, "nominal_stretched_tip":
              {**motion["nominal_stretched_tip"],
               "tip_y_relative_to_host": 2.0}},
     "a" * 40, "b" * 40),
    (bezier, motion, "short", "b" * 40),
    (bezier, motion, "a" * 40, None),
):
    try:
        m["allow_report"](bad_bezier, bad_motion, sha, parent)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Unqualified live or unsafe evidence passed")
print("WULL_MOTION_INERT_PUBLISH_CONTRACT_PASS")
