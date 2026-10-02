#!/usr/bin/env python3
"""READ-ONLY allowlisted diagnostic for ONE failed private dynamic Qt pilot.

Run ONLY immediately after the old pinned pilot returns its exact ambiguous
stage/motion gate in the SAME clean disposable private clone. Never run Qt,
read PNGs, publish captures/logs, reveal host paths, edit Git or claim PASS.
"""
import os
from pathlib import Path
import runpy
import stat
import sys

ROOT = Path(__file__).resolve().parents[1]
PINNED_RUNNER = "scripts/wull-manual-private-dynamic-paint-pilot.py"
PINNED_BLOB = "fbab844181f308019287ce06f61c106f4e5bf35c"
MAX_LOG = 256 * 1024


class Unqualified(ValueError):
    pass


def require(ok, code):
    if not ok:
        raise Unqualified(code)


def diagnose(raw, expected, allowed_failures):
    # Reject any unreviewed log marker or reordering before reporting
    # only recognized fixed categories and a permitted completed stage.
    require(type(raw) is str and type(expected) is list and
            type(allowed_failures) is frozenset and expected and
            all(type(x) is str for x in expected),
            "DIAGNOSTIC_INPUT_INVALID")
    stages = []
    failures = []
    stage_marker = "WULL_DYNAMIC_PILOT_STAGE="
    fail_marker = "WULL_DYNAMIC_PILOT_FAILURE="
    for line in raw.splitlines():
        stage_present = stage_marker in line
        fail_present = fail_marker in line
        require(not (stage_present and fail_present),
                "DIAGNOSTIC_MARKER_AMBIGUOUS")
        if stage_present:
            token = line.split(stage_marker, 1)[1].strip()
            require(not failures and len(stages) < len(expected)
                    and token == expected[len(stages)],
                    "DIAGNOSTIC_STAGE_SEQUENCE_INVALID")
            stages.append(token)
        if fail_present:
            token = line.split(fail_marker, 1)[1].strip()
            require(token in allowed_failures and not failures,
                    "DIAGNOSTIC_FAILURE_UNRECOGNIZED")
            failures.append(token)
    require(stages, "DIAGNOSTIC_NO_STAGES")
    if failures:
        require(stages != expected, "DIAGNOSTIC_FAILURE_AFTER_DONE")
        outcome = "FIXTURE_FAILURE"
        category = failures[0]
    else:
        require(stages != expected, "DIAGNOSTIC_PREVIOUS_GATE_MISMATCH")
        outcome = "INCOMPLETE_STAGES"
        category = "NONE"
    # Only constant source-reviewed strings; NEVER return raw Qt log,
    # a path, coordinates, captures, Qt error text or numeric pixels.
    return (outcome, category, len(stages), stages[-1])


def main():
    require(sys.argv[1:] == [
        "--acknowledge-read-only-previous-private-qt-failure"],
        "EXPLICIT_LOG_DIAGNOSTIC_OPT_IN_REQUIRED")
    os.umask(0o077)
    runner = runpy.run_path(
        str(ROOT / PINNED_RUNNER), run_name="private_wull_failure_diagnostic")
    # This verifies the fresh owned mode0700 clone, original QML,
    # trusted remote and reviewed old runner fixture through source pins.
    borrowed, audited_source = runner["audit"]()
    require(borrowed["git"]("rev-parse", "HEAD:" + PINNED_RUNNER)
            == PINNED_BLOB, "PINNED_PILOT_RUNNER_CHANGED")
    folder = ROOT.parent / "dynamic-paint-pilot"
    require(folder.parent == ROOT.parent and not folder.is_symlink() and
            folder.exists() and folder.stat().st_uid == os.getuid()
            and not stat.S_IMODE(folder.stat().st_mode) & 0o077,
            "PRIVATE_PILOT_DIRECTORY_UNQUALIFIED")
    log = folder / "dynamic.private.log"
    try:
        st = log.lstat()
        require(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
                and not stat.S_IMODE(st.st_mode) & 0o077
                and 0 < st.st_size <= MAX_LOG,
                "PRIVATE_PILOT_LOG_UNQUALIFIED")
        raw = log.read_text(encoding="utf-8", errors="replace")
    except OSError:
        raise Unqualified("PRIVATE_PILOT_LOG_UNQUALIFIED")
    outcome, category, count, last = diagnose(
        raw, runner["stages"](), runner["FAILURES"])
    require(borrowed["git"]("status", "--porcelain=v1",
                            "--untracked-files=all") == "" and
            borrowed["git"]("rev-parse", "HEAD") == audited_source,
            "PRIVATE_SOURCE_CHANGED")
    print("DIAGNOSTIC_SCOPE=FAILED_PRIVATE_QT_LOG_ONLY")
    print("OBSERVED_STAGE_COUNT=" + str(count))
    print("LAST_REVIEWED_STAGE=" + last)
    if outcome == "FIXTURE_FAILURE":
        print("KNOWN_QML_FAILURE=" + category)
        print("GATE=PRIVATE_DYNAMIC_QML_FAILURE_IDENTIFIED")
    else:
        print("KNOWN_QML_FAILURE=NONE")
        print("GATE=PRIVATE_DYNAMIC_STAGE_INCOMPLETE")
    # A completed diagnostic is NOT a successful original Qt experiment.


if __name__ == "__main__":
    try:
        main()
    except Exception as ex:  # Never let arbitrary Qt/Git details escape stderr.
        safe = {
            "DIAGNOSTIC_INPUT_INVALID", "DIAGNOSTIC_MARKER_AMBIGUOUS",
            "DIAGNOSTIC_STAGE_SEQUENCE_INVALID",
            "DIAGNOSTIC_FAILURE_UNRECOGNIZED", "DIAGNOSTIC_NO_STAGES",
            "DIAGNOSTIC_FAILURE_AFTER_DONE",
            "DIAGNOSTIC_PREVIOUS_GATE_MISMATCH",
            "EXPLICIT_LOG_DIAGNOSTIC_OPT_IN_REQUIRED",
            "PINNED_PILOT_RUNNER_CHANGED",
            "PRIVATE_PILOT_DIRECTORY_UNQUALIFIED",
            "PRIVATE_PILOT_LOG_UNQUALIFIED", "PRIVATE_SOURCE_CHANGED",
        }
        code = str(ex)
        print("GATE=" + (code if code in safe
                         else "PRIVATE_DYNAMIC_DIAGNOSTIC_UNAVAILABLE"))
        raise SystemExit(1)
