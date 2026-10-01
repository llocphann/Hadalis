#!/usr/bin/env python3
"""Inert source + sanitizer test for publishing ONE old private Wull log.

No Git command, Wayland compositor, input process or push is executed.
"""
import ast
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "scripts/wull-private-pointer-drift-publish.py"
source = path.read_text(encoding="utf-8")
ast.parse(source)
publish = runpy.run_path(str(path), run_name="wull_drift_inert_only")
assert publish["REPORT"] == (
    "wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json")
assert publish["REPORT_SOURCE"] == (
    "1518db798d1012592cdbceb29115cceb72cffd9b")
assert publish["REPORT_BLOB"] == (
    "973ffcccab705359fdbe1bdc12976cb1e04e2db5")
assert publish["DIAGNOSTIC_BLOB"] == (
    "91c2207e7d96aa8852f6d6f8df0ea1cb28d647d2")
assert publish["TARGET"].startswith("docs/wull-pointer-drift-")
assert publish["TARGET"] != "docs/" + publish["REPORT"]

sanitizer = publish["payload"]
categories = {
    "offset_bucket": "twenty_four_to_ninety_five",
    "offset_axes": "horizontal",
    "horizontal_direction": "negative",
    "vertical_direction": "near",
    "candidate_near_previous_disabled_center": False,
}
sha = "a" * 40
result = sanitizer(categories, sha, "b" * 40)
assert result == {
    "kind": "wull_retrospective_top_private_pointer_drift",
    "source_sha": sha,
    "original_source_sha": publish["REPORT_SOURCE"],
    "original_sanitized_report": "docs/" + publish["REPORT"],
    "status": "categorized_from_private_prior_log",
    "diagnostic": categories,
    "injection_backend_at_original_run": "forced_wlr_protocols_wdotool",
    "raw_log_coordinates": "private_local_only",
    "new_pointer_input": False,
    "real_native_retest": "not_run",
    "production_mask_changed": False,
    "host_user_config_changed": False,
    "publication_parent_sha": "b" * 40,
}
serialized = __import__("json").dumps(result)
for forbidden in ('"x":', '"y":', "hostname", "home_dir", "username"):
    assert forbidden not in serialized, forbidden

for altered, source_rev, parent in (
    ({**categories, "offset_axes": "diagonal"}, sha, "b" * 40),
    ({**categories, "candidate_near_previous_disabled_center": 1},
     sha, "b" * 40),
    ({**categories, "x": 42}, sha, "b" * 40),
    (categories, sha[:12], "b" * 40),
    (categories, sha, "x"),
):
    try:
        sanitizer(altered, source_rev, parent)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Unsafe public payload passed")

for fragment in (
    '"--publish-existing-top-off-target"',
    'isolated_clean_private_dev_clone_required',
    'origin not in SAFE_REMOTES',
    'diagnostic_source_changed_after_review',
    'sanitized_original_report_changed_after_review',
    'remote_diverged_isolated_receipt_kept_local',
    '"git", "push", "origin", "HEAD:refs/heads/dev"',
    '"rebase", "--onto", remote, parent',
    'not_an_exclusive_unpublished_drift_receipt',
    'private_prior_run_log_unavailable',
    '"new_pointer_input": False',
):
    assert fragment in source, fragment
for forbidden in (
    '"reset"', '"push", "--force"', '"--force-with-lease"',
    '"ydotool"', '"/dev/uinput"',
):
    assert forbidden not in source, forbidden

print("WULL_PRIVATE_POINTER_DRIFT_PUBLISH_INERT_CONTRACT_PASS")
