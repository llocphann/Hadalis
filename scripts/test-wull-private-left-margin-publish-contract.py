#!/usr/bin/env python3
"""Inert redaction, origin/identity, retry guards; never execute live Git."""
import ast
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
script = ROOT / "scripts/wull-private-left-margin-publish.py"
source = script.read_text(encoding="utf-8")
ast.parse(source)
m = runpy.run_path(str(script), run_name="wull_left_publish_inert_only")
assert m["REPORT_SOURCE"] == "5b72e0e3294c32276c306b3c6911fd9fa4e79fb1"
assert m["REPORT_BLOB"] == "6abfcef1fae0d360dad5a55ddf46351b87634507"
assert m["DIAG_BLOB"] == "b0c34ea4abd2977ddd3b5568e38050e1b1e40308"
assert m["ORIGINAL_CHILD_BLOB"] == "c099fc6a1a62b06218d69dd3ec526df18de701db"
assert m["ORIGINAL_TARGETS_BLOB"] == "527ebecd01e2fc51d497e0de73a0f3bcd83305ac"
assert m["DEST"].startswith("docs/wull-pointer-left-margin-drift-")
assert m["DEST"] != m["REPORT"]
categories = {
    "relative_offset_bucket": "twenty_four_to_ninety_five",
    "relative_axes": "horizontal",
    "horizontal_direction": "negative",
    "vertical_direction": "within_uncertainty",
    "near_previous_disabled_body_position": False,
    "near_previous_candidate_exterior_position": False,
    "measurement_basis": "same_left_body_x_and_relative_y_minus_47",
    "interpretation": "retrospective_witness_relative_not_cause",
}
result = m["public_payload"](categories, "a" * 40, "b" * 40)
assert result == {
    "kind": "wull_retrospective_left_margin_pointer_drift",
    "source_sha": "a" * 40,
    "original_source_sha": m["REPORT_SOURCE"],
    "original_sanitized_report": m["REPORT"],
    "status": "categorized_from_private_prior_log",
    "diagnostic": categories,
    "input_backend_of_original_run": "forced_wlr_protocols_wdotool",
    "raw_pointer_coordinates": "private_local_only",
    "new_pointer_input": False,
    "real_niri_retest": "not_run",
    "production_mask_changed": False,
    "host_user_config_changed": False,
    "publication_parent_sha": "b" * 40,
}
for forbidden in ('"x"', '"y"', "quickshell.private", "wayland-", "nested/child"):
    assert forbidden not in json.dumps(result), forbidden
for bad, s, p in (
    ({**categories, "relative_axes": "oblique"}, "a" * 40, "b" * 40),
    ({**categories, "near_previous_disabled_body_position": 1},
     "a" * 40, "b" * 40),
    ({**categories, "raw": {"x": 60}}, "a" * 40, "b" * 40),
    (categories, "tiny", "b" * 40),
    (categories, "a" * 40, "invalid"),
):
    try:
        m["public_payload"](bad, s, p)
    except RuntimeError:
        pass
    else:
        raise AssertionError("unsafe private pointer detail permitted")

for required in (
    '"--publish-existing-left-margin-off-target"',
    'owned_clean_temporary_dev_clone_required',
    'original_sanitized_left_report_changed',
    'reviewed_left_diagnostic_blob_changed',
    'original_left_geometry_source_unverified',
    'remote_history_diverged_private_report_kept',
    '"git", "push", "origin", "HEAD:refs/heads/dev"',
    '"rebase", "--onto", newer, old_parent',
    'unreviewed_unpublished_left_report_commit',
    '"new_pointer_input": False',
):
    assert required in source, required
for forbidden in (
    '"reset"', '"--force"', '"--force-with-lease"',
    '"ydotool"', '"/dev/uinput"', 'subprocess.Popen(',
):
    assert forbidden not in source, forbidden
print("WULL_LEFT_PRIVATE_MARGIN_PUBLISH_INERT_PASS")
