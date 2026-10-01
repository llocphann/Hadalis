#!/usr/bin/env python3
"""READ-ONLY, private-log-only diagnosis of one existing Wull pointer receipt.

Does not start a compositor, inject input, change Git or print absolute
coordinates. Only understands the exact single-output top A/B witness
sequence where a candidate exterior click was reported off_target.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys

NAME = re.compile(
    r"wull-mask-candidate-(\d{8}T\d{6}Z)-([0-9a-f]{8})-([0-9a-f]{12})\.json\Z"
)
PREFIX = "WULL_POINTER_UNDERLAY_PRESS "
MAX_LOG = 1048576


def diagnostic(baseline, candidate, disabled):
    """Pure categorical comparison, never return actual pointer positions."""
    for item in (baseline, candidate, disabled):
        if (not isinstance(item, dict)
                or any(type(item.get(key)) is not int
                       for key in ("x", "y", "button"))
                or item["button"] != 1):
            raise ValueError("unverified_private_pointer_witness")
    dx = candidate["x"] - baseline["x"]
    dy = candidate["y"] - baseline["y"]
    amount = max(abs(dx), abs(dy))
    bucket = ("within_six" if amount <= 6 else
              "seven_to_twenty_three" if amount <= 23 else
              "twenty_four_to_ninety_five" if amount <= 95 else
              "ninety_six_or_more")
    axis = ("both" if abs(dx) > 6 and abs(dy) > 6 else
            "horizontal" if abs(dx) > 6 else
            "vertical" if abs(dy) > 6 else "within_tolerance")
    direction = (
        ("positive" if dx > 6 else "negative" if dx < -6 else "near",
         "positive" if dy > 6 else "negative" if dy < -6 else "near")
    )
    same_as_disabled = (
        abs(candidate["x"] - disabled["x"]) <= 6
        and abs(candidate["y"] - disabled["y"]) <= 6
    )
    return {
        "offset_bucket": bucket,
        "offset_axes": axis,
        "horizontal_direction": direction[0],
        "vertical_direction": direction[1],
        "candidate_near_previous_disabled_center": same_as_disabled,
    }


def classify(receipt, receipt_name, log_text):
    match = NAME.fullmatch(receipt_name)
    if match is None:
        raise ValueError("receipt_name_not_allowlisted")
    source = receipt.get("source_sha")
    if not isinstance(source, str) or source[:12] != match.group(3):
        raise ValueError("receipt_source_identity_mismatch")
    if (receipt.get("kind")
            != "wull_manual_nested_private_candidate_mask_comparison"
            or receipt.get("scope")
            != "owned_single_output_nested_niri_top_candidate_mask_A_B"
            or receipt.get("status") != "inconclusive"
            or receipt.get("native_pointer_backend")
            != "forced_wlr_protocols_wdotool"):
        raise ValueError("not_the_supported_real_native_top_probe")
    observation = receipt.get("observation")
    if not isinstance(observation, dict):
        raise ValueError("missing_private_probe_observation")
    checks = observation.get("child_checks")
    expected = (
        ("disabled_center_underlay_control", "pass"),
        ("enabled_exterior_underlay_control", "pass"),
        ("enabled_body_actual_bridge_and_rust", "pass"),
        ("whole_host_empty_margin_observation", "observed"),
        ("candidate_exterior_underlay_control", "inconclusive"),
    )
    if (not isinstance(checks, list) or len(checks) != len(expected)
            or any(not isinstance(row, dict)
                   or row.get("case") != case
                   or row.get("status") != status
                   for row, (case, status) in zip(checks, expected))
            or checks[0].get("target_alignment") != "matched"
            or checks[1].get("target_alignment") != "matched"
            or checks[4].get("target_alignment") != "off_target"
            or checks[3].get("underlay_received") is not False):
        raise ValueError("unexpected_existing_report_sequence")
    rows = []
    for line in log_text.splitlines():
        if PREFIX not in line:
            continue
        try:
            record, _ = json.JSONDecoder().raw_decode(
                line.split(PREFIX, 1)[1].strip())
        except (ValueError, TypeError):
            raise ValueError("private_witness_record_unparseable") from None
        rows.append(record)
    # Body was intercepted and full-host margin blocked; exactly 3 expected
    # independent underlay clicks (disabled, enabled exterior, candidate
    # exterior). More/less means the mapping is not unambiguous.
    if len(rows) != 3:
        raise ValueError("private_witness_sequence_ambiguous")
    return diagnostic(rows[1], rows[2], rows[0])


def main():
    parser = argparse.ArgumentParser(
        description="Classify existing Wull private pointer drift WITHOUT "
                    "printing raw click coordinates or rerunning input.")
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    if args.receipt.is_symlink():
        raise ValueError("untrusted_or_oversized_receipt")
    receipt_path = args.receipt.resolve(strict=True)
    if (receipt_path.stat().st_size > 65536
            or receipt_path.stat().st_size <= 0):
        raise ValueError("untrusted_or_oversized_receipt")
    match = NAME.fullmatch(receipt_path.name)
    if match is None:
        raise ValueError("receipt_name_not_allowlisted")
    home_state = Path(
        os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
    ).expanduser().resolve()
    session = home_state / "hadalis" / (
        "wull-pointer-" + match.group(1) + "-" + match.group(2))
    log = session / "nested/child/underlay/quickshell.private.log"
    if (not session.is_dir() or session.is_symlink()
            or session.stat().st_uid != os.getuid()
            or not log.is_file() or log.is_symlink()
            or log.stat().st_uid != os.getuid()
            or not 0 < log.stat().st_size <= MAX_LOG
            or session.resolve() == receipt_path.parent):
        raise ValueError("verified_private_witness_log_unavailable")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    result = classify(
        receipt, receipt_path.name,
        log.read_text(encoding="utf-8", errors="replace"))
    print("WULL_EXISTING_PRIVATE_WITNESS_CLASSIFICATION")
    for key, value in result.items():
        print(key.upper() + ":", str(value).lower())
    print("NO_INPUT_INJECTED_NO_GIT_CHANGES_NO_RAW_COORDINATES")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as e:
        print("INCONCLUSIVE:", str(e).split(":")[0], file=sys.stderr)
        raise SystemExit(1)
