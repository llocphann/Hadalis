#!/usr/bin/env python3
"""Pure/no-Git/no-compositor synthetic left margin retrospective checks."""
import ast
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
script = ROOT / "scripts/wull-private-left-margin-diagnostic.py"
source = script.read_text(encoding="utf-8")
ast.parse(source)
for forbidden in ("subprocess", "wdotool", "os.kill", "socket", "requests"):
    assert forbidden not in source
m = runpy.run_path(str(script), run_name="wull_left_inert_import")
report = {
    "source_sha": m["SOURCE"],
    "status": "inconclusive",
    "kind": "wull_manual_nested_private_candidate_mask_comparison",
    "scope": "owned_single_output_nested_niri_left_candidate_mask_A_B",
    "native_pointer_backend": "forced_wlr_protocols_wdotool",
    "preflight_reason": None,
    "observation": {
        "child_result": "inconclusive",
        "child_reason": "candidate_margin_target_unverified",
        "nested_verified": True,
        "nested_stopped": True,
        "host_outputs_unchanged": True,
        "owned_private_strays": False,
        "production_unmapped": True,
        "underlay_unmapped": True,
        "private_daemon_stopped": True,
        "whole_host_mask_changed": False,
        "private_candidate_mask_tested": True,
        "child_checks": [
            {"case":"disabled_center_underlay_control","status":"pass",
             "target_alignment":"matched"},
            {"case":"enabled_exterior_underlay_control","status":"pass",
             "target_alignment":"matched"},
            {"case":"enabled_body_actual_bridge_and_rust","status":"pass",
             "underlay_target_alignment":"no_click",
             "real_bridge_clicked":True,"real_rust_reacted":True},
            {"case":"whole_host_empty_margin_observation","status":"observed",
             "underlay_received":False,"unexpected_body_click":False},
            {"case":"after_baseline_unmap_exterior_underlay_control",
             "status":"pass","target_alignment":"matched"},
            {"case":"candidate_exterior_underlay_control","status":"pass",
             "target_alignment":"matched"},
            {"case":"candidate_body_real_bridge_and_rust","status":"pass",
             "underlay_target_alignment":"no_click",
             "real_bridge_clicked":True,"real_rust_reacted":True},
            {"case":"candidate_empty_margin_pass_through",
             "status":"inconclusive","target_alignment":"off_target",
             "unexpected_body_click":False},
        ],
    },
}
assert m["validate_report"](report, m["REPORT"])
rows = [
    {"x": 60, "y": 518, "button": 1},
    {"x": 60, "y": 382, "button": 1},
    {"x": 61, "y": 381, "button": 1},
    {"x": 60, "y": 381, "button": 1},
    {"x": 85, "y": 500, "button": 1},
]
marker = m["MARKER"]
log = "PRIVATE READY\n" + "".join(
    marker + __import__("json").dumps(item) + "\n" for item in rows)
assert m["parse_clicks"](log) == rows
found = m["categorize"](rows)
assert found == {
    "relative_offset_bucket": "twenty_four_to_ninety_five",
    "relative_axes": "both",
    "horizontal_direction": "positive",
    "vertical_direction": "positive",
    "near_previous_disabled_body_position": False,
    "near_previous_candidate_exterior_position": False,
    "measurement_basis": "same_left_body_x_and_relative_y_minus_47",
    "interpretation": "retrospective_witness_relative_not_cause",
}
center_stale = [*rows[:4], rows[0]]
assert m["categorize"](center_stale)[
    "near_previous_disabled_body_position"] is True
external_stale = [*rows[:4], rows[3]]
assert m["categorize"](external_stale)[
    "near_previous_candidate_exterior_position"] is True
uncertain = [*rows[:4], {"x": 60, "y": 471, "button": 1}]
assert m["categorize"](uncertain)[
    "relative_offset_bucket"] == "within_prior_witness_uncertainty"

for bad_report,bad_name in (
    (report,"wrong.json"),
    ({**report,"status":"pass"},m["REPORT"]),
    ({**report,"source_sha":"wrong"},m["REPORT"]),
    ({**report,"observation":{**report["observation"],
                             "child_checks":report["observation"]["child_checks"][:-1]}},
     m["REPORT"]),
    ({**report,"observation":{**report["observation"],
                             "child_checks":[*report["observation"]["child_checks"][:-1],
                              {"case":"candidate_empty_margin_pass_through",
                               "status":"pass","target_alignment":"matched",
                               "unexpected_body_click":False}]}},m["REPORT"]),
):
    try:
        m["validate_report"](bad_report,bad_name)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid original left evidence accepted")
for bad_log in (
    log+marker+'{"x":1,"y":2,"button":1}'+"\n",
    log.replace('"button": 1','"button": 2',1),
    log.replace('"x": 60','"x": "60"',1),
    log.replace('"x": 61','"x": 161',1),
):
    try:
        m["parse_clicks"](bad_log)
    except ValueError:
        pass
    else:
        raise AssertionError("Ambiguous private log accepted")
try:
    m["categorize"]([*rows[:4],{"x": True,"y": 471,"button": 1}])
except ValueError:
    pass
else:
    raise AssertionError("Boolean-coordinate record accepted")
print("WULL_LEFT_PRIVATE_MARGIN_RETROSPECTIVE_INERT_PASS")
