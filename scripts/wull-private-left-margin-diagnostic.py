#!/usr/bin/env python3
"""No-input retrospective classification of ONE observed LEFT margin miss.

Consumes only one exact-source sanitized report and the matching private
previous-run underlay log. Emits categorical deltas, never x/y or log paths.
No compositor, pointer, Git, runtime source or production modifications.
"""
import argparse
import json
import os
from pathlib import Path
import sys

REPORT = "wull-mask-left-20261001T175020Z-5a11aa42-5b72e0e3294c.json"
SOURCE = "5b72e0e3294c32276c306b3c6911fd9fa4e79fb1"
SESSION = "wull-pointer-20261001T175020Z-5a11aa42"
MARKER = "WULL_POINTER_UNDERLAY_PRESS "
MAX_LOG = 1048576
# From source-pinned all_edge_targets(left):
# inside=(body[0], round(y+9)); body=(round(x+49), round(y+56)).
# Both x's are identical. Delta y is -47 with <=1 px possible
# Python round-to-even tie ambiguity.
MARGIN_BELOW_BODY_CENTER = -47
CONTROL_ERROR = 6
ROUNDING_AMBIGUITY = 1

STEPS = (
    ("disabled_center_underlay_control", "pass", "matched"),
    ("enabled_exterior_underlay_control", "pass", "matched"),
    ("enabled_body_actual_bridge_and_rust", "pass", "no_click"),
    ("whole_host_empty_margin_observation", "observed", None),
    ("after_baseline_unmap_exterior_underlay_control", "pass", "matched"),
    ("candidate_exterior_underlay_control", "pass", "matched"),
    ("candidate_body_real_bridge_and_rust", "pass", "no_click"),
    ("candidate_empty_margin_pass_through", "inconclusive", "off_target"),
)


def validate_report(report, filename):
    if filename != REPORT or not isinstance(report, dict):
        raise ValueError("wrong_exact_left_report")
    if (report.get("source_sha") != SOURCE
            or report.get("status") != "inconclusive"
            or report.get("kind")
            != "wull_manual_nested_private_candidate_mask_comparison"
            or report.get("scope")
            != "owned_single_output_nested_niri_left_candidate_mask_A_B"
            or report.get("native_pointer_backend")
            != "forced_wlr_protocols_wdotool"
            or report.get("preflight_reason") is not None):
        raise ValueError("unverified_original_left_pointer_run")
    obs = report.get("observation")
    if (not isinstance(obs, dict)
            or obs.get("child_reason") != "candidate_margin_target_unverified"
            or obs.get("child_result") != "inconclusive"
            or obs.get("nested_verified") is not True
            or obs.get("nested_stopped") is not True
            or obs.get("host_outputs_unchanged") is not True
            or obs.get("owned_private_strays") is not False
            or obs.get("production_unmapped") is not True
            or obs.get("underlay_unmapped") is not True
            or obs.get("private_daemon_stopped") is not True
            or obs.get("whole_host_mask_changed") is not False
            or obs.get("private_candidate_mask_tested") is not True):
        raise ValueError("unverified_original_run_isolation_or_cleanup")
    checks = obs.get("child_checks")
    if not isinstance(checks, list) or len(checks) != len(STEPS):
        raise ValueError("unverified_eight_step_left_sequence")
    for check, (case, status, alignment) in zip(checks, STEPS):
        if not isinstance(check, dict) or (
                check.get("case"), check.get("status")) != (case, status):
            raise ValueError("unverified_eight_step_left_sequence")
        observed = (check.get("underlay_target_alignment")
                    if "body" in case else check.get("target_alignment"))
        if alignment is not None and observed != alignment:
            raise ValueError("unverified_step_alignment")
        if "body" in case and (
                check.get("real_bridge_clicked") is not True
                or check.get("real_rust_reacted") is not True):
            raise ValueError("unverified_real_body_and_rust")
    if (checks[3].get("underlay_received") is not False
            or checks[3].get("unexpected_body_click") is not False
            or checks[-1].get("unexpected_body_click") is not False):
        raise ValueError("unverified_actual_left_margin_observation")
    return True


def parse_clicks(log_text):
    if not isinstance(log_text, str) or len(log_text.encode("utf-8")) > MAX_LOG:
        raise ValueError("oversized_or_invalid_private_log")
    rows = []
    for line in log_text.splitlines():
        if MARKER not in line:
            continue
        try:
            record, _ = json.JSONDecoder().raw_decode(
                line.split(MARKER, 1)[1].strip())
        except (TypeError, ValueError):
            raise ValueError("unparseable_private_click") from None
        if (not isinstance(record, dict)
                or any(type(record.get(field)) is not int
                       for field in ("x", "y", "button"))
                or record["button"] != 1):
            raise ValueError("untrusted_private_click")
        rows.append(record)
    # Disabled body, enabled exterior, after-unmap exterior,
    # candidate exterior, candidate margin: exactly five real hits.
    # Production margin and both activated bodies MUST NOT hit underlay.
    if len(rows) != 5:
        raise ValueError("ambiguous_private_five_witness_sequence")
    for i, j in ((1, 2), (1, 3), (2, 3)):
        if max(abs(rows[i][axis] - rows[j][axis])
               for axis in ("x", "y")) > 2 * CONTROL_ERROR:
            raise ValueError("prior_same_target_exterior_witnesses_disagree")
    return rows


def categorize(rows):
    if not isinstance(rows, list) or len(rows) != 5:
        raise ValueError("unverified_private_witnesses")
    for row in rows:
        if (not isinstance(row, dict)
                or any(type(row.get(field)) is not int
                       for field in ("x", "y", "button"))
                or row["button"] != 1):
            raise ValueError("untrusted_private_click")
    center = rows[0]
    final = rows[4]
    dx = final["x"] - center["x"]
    dy = final["y"] - (center["y"] + MARGIN_BELOW_BODY_CENTER)
    bound = CONTROL_ERROR + ROUNDING_AMBIGUITY
    maximum = max(abs(dx), abs(dy))
    bucket = ("within_prior_witness_uncertainty" if maximum <= bound
              else "eight_to_twenty_three" if maximum <= 23
              else "twenty_four_to_ninety_five" if maximum <= 95
              else "ninety_six_or_more")
    def direction(delta):
        return ("positive" if delta > bound else
                "negative" if delta < -bound else "within_uncertainty")
    return {
        "relative_offset_bucket": bucket,
        "relative_axes": (
            "both" if abs(dx) > bound and abs(dy) > bound
            else "horizontal" if abs(dx) > bound
            else "vertical" if abs(dy) > bound
            else "within_prior_witness_uncertainty"),
        "horizontal_direction": direction(dx),
        "vertical_direction": direction(dy),
        "near_previous_disabled_body_position": (
            abs(final["x"] - center["x"]) <= CONTROL_ERROR
            and abs(final["y"] - center["y"]) <= CONTROL_ERROR),
        "near_previous_candidate_exterior_position": (
            abs(final["x"] - rows[3]["x"]) <= CONTROL_ERROR
            and abs(final["y"] - rows[3]["y"]) <= CONTROL_ERROR),
        "measurement_basis": "same_left_body_x_and_relative_y_minus_47",
        "interpretation": "retrospective_witness_relative_not_cause",
    }


def private_log(state):
    if not isinstance(state, Path):
        raise ValueError("invalid_state_directory")
    session = state / "hadalis" / SESSION
    log = session / "nested/child/underlay/quickshell.private.log"
    if (not session.is_dir() or session.is_symlink()
            or session.stat().st_uid != os.getuid()
            or not log.is_file() or log.is_symlink()
            or log.stat().st_uid != os.getuid()
            or not 0 < log.stat().st_size <= MAX_LOG):
        raise ValueError("verified_private_left_log_unavailable")
    return log.read_text(encoding="utf-8", errors="replace")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--receipt", required=True, type=Path)
    a = p.parse_args()
    if a.receipt.is_symlink():
        raise ValueError("untrusted_public_receipt_symlink")
    receipt = a.receipt.resolve(strict=True)
    if receipt.name != REPORT or not 0 < receipt.stat().st_size <= 65536:
        raise ValueError("not_exact_public_left_receipt")
    content = json.loads(receipt.read_text(encoding="utf-8"))
    validate_report(content, receipt.name)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    result = categorize(parse_clicks(private_log(state)))
    print("WULL_LEFT_RETROSPECTIVE_WITNESS_CLASSIFIED")
    for key, val in result.items():
        print(key.upper() + ":", str(val).lower())
    print("NO_NEW_POINTER_ACTION_NO_RAW_COORDINATES_NO_PRODUCTION_CHANGE")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print("INCONCLUSIVE:", str(e).split(":")[0], file=sys.stderr)
        raise SystemExit(1)
