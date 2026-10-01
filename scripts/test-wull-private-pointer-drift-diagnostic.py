#!/usr/bin/env python3
"""Purely inert safety and parser cases for existing private Wull log analysis."""
import ast
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / "scripts/wull-private-pointer-drift-diagnostic.py").read_text()
ast.parse(text)
assert "subprocess" not in text
assert "os.kill" not in text
assert "print(" in text
assert "NO_INPUT_INJECTED_NO_GIT_CHANGES_NO_RAW_COORDINATES" in text
module = runpy.run_path(
    str(ROOT / "scripts/wull-private-pointer-drift-diagnostic.py"),
    run_name="wull_private_drift_test_only")
diag = module["diagnostic"]
classify = module["classify"]
base = {"x": 450, "y": 70, "button": 1}
disabled = {"x": 800, "y": 80, "button": 1}
near = diag(base, {"x": 455, "y": 64, "button": 1}, disabled)
assert near["offset_bucket"] == "within_six"
assert near["offset_axes"] == "within_tolerance"
assert diag(base, {"x": 420, "y": 70, "button": 1}, disabled) == {
    "offset_bucket": "twenty_four_to_ninety_five",
    "offset_axes": "horizontal",
    "horizontal_direction": "negative",
    "vertical_direction": "near",
    "candidate_near_previous_disabled_center": False,
}
assert diag(base, {"x": 545, "y": 250, "button": 1}, disabled)[
    "offset_bucket"] == "ninety_six_or_more"
assert diag(base, {"x": 450, "y": 78, "button": 1}, disabled)[
    "offset_bucket"] == "seven_to_twenty_three"
assert diag(base, {"x": 800, "y": 80, "button": 1}, disabled)[
    "candidate_near_previous_disabled_center"]
for invalid in ({"x": True, "y": 40, "button": 1},
                {"x": 40, "y": 40, "button": 3},
                {"x": "40", "y": 40, "button": 1}):
    try:
        diag(base, invalid, disabled)
    except ValueError as e:
        assert str(e) == "unverified_private_pointer_witness"
    else:
        raise AssertionError("Untrusted witness accepted")

source = "1518db798d1012592cdbceb29115cceb72cffd9b"
name = "wull-mask-candidate-20261001T170950Z-105fd7a8-" + source[:12] + ".json"
receipt = {
    "kind": "wull_manual_nested_private_candidate_mask_comparison",
    "source_sha": source,
    "status": "inconclusive",
    "scope": "owned_single_output_nested_niri_top_candidate_mask_A_B",
    "native_pointer_backend": "forced_wlr_protocols_wdotool",
    "observation": {"child_checks": [
        {"case": "disabled_center_underlay_control", "status": "pass",
         "target_alignment": "matched"},
        {"case": "enabled_exterior_underlay_control", "status": "pass",
         "target_alignment": "matched"},
        {"case": "enabled_body_actual_bridge_and_rust", "status": "pass"},
        {"case": "whole_host_empty_margin_observation",
         "status": "observed", "underlay_received": False},
        {"case": "candidate_exterior_underlay_control",
         "status": "inconclusive", "target_alignment": "off_target"},
    ]}
}
prefix = "WULL_POINTER_UNDERLAY_PRESS "
log = ("PRIVATE READY\n" +
       prefix + '{"x":800,"y":80,"button":1}\n' +
       prefix + '{"x":450,"y":70,"button":1}\n' +
       prefix + '{"x":420,"y":70,"button":1}\n')
summary = classify(receipt, name, log)
assert summary["offset_axes"] == "horizontal"
assert summary["offset_bucket"] == "twenty_four_to_ninety_five"
assert set(summary) == {
    "offset_bucket", "offset_axes",
    "horizontal_direction", "vertical_direction",
    "candidate_near_previous_disabled_center",
}
for bad_receipt, bad_name, bad_log in (
    (receipt, "unknown.json", log),
    (receipt, name, log + prefix + '{"x":400,"y":70,"button":1}\n'),
    ({**receipt, "status": "pass"}, name, log),
    ({**receipt, "source_sha": "abc"}, name, log),
    ({**receipt, "observation": {"child_checks": []}}, name, log),
):
    try:
        classify(bad_receipt, bad_name, bad_log)
    except ValueError:
        pass
    else:
        raise AssertionError("Unverified diagnostic unexpectedly classified")

print("WULL_PRIVATE_POINTER_DRIFT_INERT_CONTRACT_PASS")
