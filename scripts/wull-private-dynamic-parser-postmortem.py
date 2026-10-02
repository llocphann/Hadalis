#!/usr/bin/env python3
"""Read-only old private Wull dynamic log parser triage; NEVER launch Qt.

Source-pinned owner-owned discarded clone only. Prints fixed error enums and
allowlisted shape counts, NEVER raw QML/geometry, file contents or log paths.
"""
import argparse
import json
import os
from pathlib import Path
import re
import runpy
import stat
import subprocess

SOURCE = "4caccd2058f1b3089ec398a131241f800eaae890"
RUNNER = "scripts/wull-manual-offscreen-dynamic-geometry.py"
RUNNER_BLOB = "fe1c828e7c2f0e4fdc4bb7340242062085db3118"
FIXTURE = "scripts/wull-fixtures/motion-envelope/shell.qml"
FIXTURE_BLOB = "6e3b5402d32d263868c1ec688925adba0fd7250b"
LOG_BYTES_CAP = 524288
SAFE_ORIGINS = {
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
# Only actual authored parser and known-frozen ValueError codes are printable.
SAFE_VALUE_ERRORS = {
    "invalid_dynamic_host_count", "unreviewed_frozen_reference",
    "unreviewed_dynamic_host_fields", "duplicate_or_unreviewed_dynamic_host",
    "fabricated_neutral_witness", "unreviewed_frozen_flags",
    "missing_scale_frozen_reference", "invalid_frozen_edge_reference",
    "unreviewed_dynamic_phase_fields", "invalid_dynamic_frame_count",
    "fabricated_dynamic_boolean_witness", "missing_dynamic_edge_scale",
    "unqualified_frozen_reference", "incomplete_frozen_scale_reference",
}
FLAGS = ("samples", "active", "stretch_witness", "transition_witness",
         "target_reached_witness", "mapped_frame_change_witness",
         "bob_witness", "sway_witness", "bbox_outside_static",
         "bbox_outside_host", "tip_outside_static", "tip_outside_host",
         "bbox_beyond_frozen")


def git(repo, *args):
    p = subprocess.run(["git", "-C", str(repo), *args],
                       stdin=subprocess.DEVNULL, capture_output=True,
                       text=True, timeout=8)
    if p.returncode:
        raise ValueError("unverified_original_clone")
    return p.stdout.strip()


def owner_guard(scratch):
    parents = (scratch, scratch.parent, scratch.parent.parent)
    if (scratch.name[:15] != "wull-qt-motion."
            or scratch.parent.name != "hadalis"
            or not scratch.parent.parent.name.startswith("wull-qt-state.")
            or any(p.is_symlink() or not p.is_dir() for p in parents)):
        raise ValueError("untrusted_private_scratch")
    for p in parents:
        st = p.stat()
        if st.st_uid != os.getuid() or stat.S_IMODE(st.st_mode) & 0o077:
            raise ValueError("private_owner_or_mode_mismatch")
    repo = scratch / "repo"
    log = scratch / "dynamic-qml" / "dynamic.private.log"
    if repo.is_symlink() or not repo.is_dir():
        raise ValueError("missing_pinned_original_clone")
    if (log.is_symlink() or not log.is_file()
            or log.stat().st_uid != os.getuid()
            or not 0 < log.stat().st_size <= LOG_BYTES_CAP):
        raise ValueError("unreviewed_private_log")
    if (git(repo, "rev-parse", "HEAD") != SOURCE
            or git(repo, "rev-parse", "HEAD:" + RUNNER) != RUNNER_BLOB
            or git(repo, "rev-parse", "HEAD:" + FIXTURE) != FIXTURE_BLOB
            or git(repo, "remote", "get-url", "origin") not in SAFE_ORIGINS):
        raise ValueError("original_source_pin_mismatch")
    return repo, log


def value_error_code(exc):
    # Do not echo arbitrary ValueError messages or filename/coordinate text.
    code = str(exc)
    return code if code in SAFE_VALUE_ERRORS else "OTHER_VALUE_ERROR"


def payload_shape(rows):
    if type(rows) is not list:
        return "NOT_LIST", "NOT_APPLICABLE", "NOT_APPLICABLE"
    if len(rows) != 12:
        return "WRONG_HOST_COUNT", "NOT_APPLICABLE", "NOT_APPLICABLE"
    fields = {"edge", "requested_scale", "neutral_verified",
              "frozen", "stretch", "release"}
    if any(type(row) is not dict or set(row) != fields for row in rows):
        return "TWELVE_HOSTS", "HOST_FIELDS_MISMATCH", "NOT_APPLICABLE"
    phase_ok = all(
        type(row.get(phase)) is dict and set(row[phase]) == set(FLAGS)
        for row in rows for phase in ("stretch", "release"))
    return ("TWELVE_HOSTS", "HOST_FIELDS_MATCH",
            "PHASE_FIELDS_MATCH" if phase_ok else "PHASE_FIELDS_MISMATCH")


def diagnose(raw, runner):
    marker = runner["MARKER"]
    stages = runner["private_stage_summary"](raw)
    lines = [line.split(marker, 1)[1] for line in raw.splitlines()
             if marker in line]
    print("STAGES=" +
          ("INVALID" if stages is None else str(len(stages))))
    print("EXPECTED_STAGE_ORDER=" +
          ("YES" if stages == list(runner["EXPECTED_STAGES"]) else "NO"))
    print("GEOMETRY_MARKER_COUNT=" + str(min(2, len(lines))))
    if len(lines) != 1:
        print("PARSER_STAGE=MARKER_COUNT")
        return
    candidate = lines[0]
    print("PAYLOAD_CHAR_COUNT=" + str(len(candidate)))
    print("PAYLOAD_STARTS_ARRAY=" +
          ("YES" if candidate.lstrip().startswith("[") else "NO"))
    print("PAYLOAD_ENDS_ARRAY=" +
          ("YES" if candidate.rstrip().endswith("]") else "NO"))
    try:
        rows = json.loads(candidate)
    except json.JSONDecodeError:
        print("PARSER_STAGE=JSON_DECODE_ERROR")
        return
    print("PARSER_STAGE=JSON_DECODE_OK")
    hosts, names, phases = payload_shape(rows)
    print("JSON_HOST_SHAPE=" + hosts)
    print("JSON_HOST_FIELDS=" + names)
    print("JSON_PHASE_FIELDS=" + phases)
    try:
        baseline = runner["known_frozen"]()
    except (KeyError, TypeError, ValueError, OSError, json.JSONDecodeError) as ex:
        print("PARSER_STAGE=FROZEN_REFERENCE_ERROR")
        print("FROZEN_REFERENCE_CATEGORY=" +
              (value_error_code(ex) if isinstance(ex, ValueError)
               and not isinstance(ex, json.JSONDecodeError) else
               "STRUCTURE_OR_READ_ERROR"))
        return
    print("FROZEN_REFERENCE=VALID")
    try:
        summary = runner["model_summary"](rows, baseline)
    except (KeyError, TypeError, ValueError) as ex:
        print("PARSER_STAGE=MODEL_VALIDATION_ERROR")
        print("MODEL_CATEGORY=" +
              (value_error_code(ex) if isinstance(ex, ValueError)
               else "STRUCTURE_TYPE_OR_KEY_ERROR"))
        return
    # Parsing success does NOT imply witness PASS or production acceptance.
    print("PARSER_STAGE=MODEL_VALIDATED")
    print("MODEL_STATUS=" +
          (summary["status"] if summary["status"] in
           ("pass", "inconclusive") else "UNEXPECTED_STATUS"))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--scratch", required=True, type=Path)
    args = p.parse_args()
    try:
        repo, log = owner_guard(args.scratch.absolute())
        model = runpy.run_path(
            str(repo / RUNNER), run_name="wull_private_dynamic_parser_postmortem")
        print("SOURCE_SHA=" + SOURCE)
        diagnose(log.read_text(encoding="utf-8", errors="replace"), model)
        print("GATE=READ_ONLY_PRIVATE_DYNAMIC_PARSER_DIAGNOSIS")
    except (ValueError, OSError, subprocess.TimeoutExpired):
        print("GATE=PRIVATE_DYNAMIC_PARSER_DIAGNOSIS_UNAVAILABLE")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
