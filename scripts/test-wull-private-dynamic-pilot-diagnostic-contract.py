#!/usr/bin/env python3
"""FAKE-ONLY bounded diagnostic parsing for failed private Wull dynamic Qt.

No Qt execution, filesystem discovery, host display access, raw log printing,
capture reading, Git mutation or network access.
"""
import ast
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
DIAG = ROOT / "scripts/wull-private-dynamic-pilot-diagnose.py"
RUNNER = ROOT / "scripts/wull-manual-private-dynamic-paint-pilot.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-dynamic-pilot/shell.qml"


def blob(path):
    contents = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(contents)).encode() + b"\0" + contents).hexdigest()


assert blob(DIAG) == "e62e2a9df17af75168b5f26f0bd77f47e1035b37"
assert blob(RUNNER) == "fbab844181f308019287ce06f61c106f4e5bf35c"
assert blob(FIXTURE) == "1f840534e93ff46deb401e52a3eb56cda09a807c"

source = DIAG.read_text(encoding="utf-8")
ast.parse(source)
diag = runpy.run_path(str(DIAG), run_name="inert_wull_diagnostic_contract")
runner = runpy.run_path(str(RUNNER), run_name="inert_wull_pilot_source")
assert diag["PINNED_BLOB"] == blob(RUNNER)
assert diag["MAX_LOG"] <= 256 * 1024
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
for name in ("PINNED_PILOT_RUNNER_CHANGED", "PRIVATE_PILOT_LOG_UNQUALIFIED",
             "DIAGNOSTIC_STAGE_SEQUENCE_INVALID",
             "PRIVATE_SOURCE_CHANGED",
             "GATE=PRIVATE_DYNAMIC_QML_FAILURE_IDENTIFIED",
             "GATE=PRIVATE_DYNAMIC_STAGE_INCOMPLETE"):
    assert name in source
for forbidden in (
    "subprocess.Popen", "QtQuick", "dbus-run-session", "grabToImage(",
    "print(raw)", "print(log.read_text", "print(folder)", "print(log)",
    '"git", "push"', '"git", "commit"', '"git", "reset"',
    "os.killpg", "png_alpha(", "glob(", "rglob(",
):
    assert forbidden not in source, forbidden

expected = runner["stages"]()
failures = runner["FAILURES"]
assert len(expected) == 38
assert expected[0:3] == ["BOOT", "NEUTRAL_READY", "STRETCH_START"]
assert expected[-2:] == ["WITNESS_COMPLETE", "DONE"]


def check_fail(code, raw, stages=expected, allowed=failures):
    try:
        diag["diagnose"](raw, stages, allowed)
    except diag["Unqualified"] as ex:
        assert str(ex) == code, (str(ex), code)
    else:
        raise AssertionError("Dangerous fake log accepted: " + code)


def log_prefix(n):
    return "\n".join(
        "reviewed WULL_DYNAMIC_PILOT_STAGE=" + stage
        for stage in expected[:n])


assert diag["diagnose"](
    log_prefix(3) + "\nreviewed WULL_DYNAMIC_PILOT_FAILURE="
    + "ACTIVE_SAMPLE_GEOMETRY_INVALID", expected, failures) == (
        "FIXTURE_FAILURE", "ACTIVE_SAMPLE_GEOMETRY_INVALID",
        3, "STRETCH_START")
assert diag["diagnose"](log_prefix(3), expected, failures) == (
    "INCOMPLETE_STAGES", "NONE", 3, "STRETCH_START")
assert diag["diagnose"](
    log_prefix(37) + "\nreviewed WULL_DYNAMIC_PILOT_FAILURE="
    + "SAMPLED_MAPPED_MOTION_NOT_OBSERVED", expected, failures) == (
        "FIXTURE_FAILURE", "SAMPLED_MAPPED_MOTION_NOT_OBSERVED",
        37, "WITNESS_COMPLETE")

check_fail("DIAGNOSTIC_NO_STAGES", "Qt arbitrary private paths and data")
check_fail("DIAGNOSTIC_STAGE_SEQUENCE_INVALID",
           log_prefix(3) + "\nWULL_DYNAMIC_PILOT_STAGE=BOOT")
check_fail("DIAGNOSTIC_STAGE_SEQUENCE_INVALID",
           "WULL_DYNAMIC_PILOT_STAGE=STRETCH_START")
check_fail("DIAGNOSTIC_FAILURE_UNRECOGNIZED",
           log_prefix(1) + "\nWULL_DYNAMIC_PILOT_FAILURE=/host/secret")
check_fail("DIAGNOSTIC_MARKER_AMBIGUOUS",
           log_prefix(1) + "\nWULL_DYNAMIC_PILOT_STAGE=NEUTRAL_READY"
           + " WULL_DYNAMIC_PILOT_FAILURE=BODY_MISSING")
check_fail("DIAGNOSTIC_STAGE_SEQUENCE_INVALID",
           log_prefix(1) + "\nWULL_DYNAMIC_PILOT_FAILURE=BODY_MISSING"
           + "\nWULL_DYNAMIC_PILOT_STAGE=NEUTRAL_READY")
check_fail("DIAGNOSTIC_PREVIOUS_GATE_MISMATCH", log_prefix(38))
check_fail("DIAGNOSTIC_FAILURE_AFTER_DONE",
           log_prefix(38) + "\nWULL_DYNAMIC_PILOT_FAILURE=BODY_MISSING")
check_fail("DIAGNOSTIC_INPUT_INVALID", log_prefix(1), [], failures)

print("WULL_PRIVATE_DYNAMIC_PILOT_DIAGNOSTIC_INERT_PASS")
