#!/usr/bin/env python3
"""ONE private two-BOTTOM original full-companion margin0/1 motion A/B canary.

TWO original BOTTOM×1.5 companions in one private Qt process; only
second ORIGINAL cradle private margin=1. First margin=0 positive control
MUST have sampled exterior alpha in BOTH actual spring phases. Each case
has independently witnessed real spring and body motion at 40ms. Two
independent windows grabbed SEQUENTIALLY, never same-time pixel pairs.
No production QML/Region edit, live Wayland screenshot or publishing.
"""
import os
from pathlib import Path
import resource
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
BORROW = "scripts/wull-manual-private-paint-core.py"
BORROW_BLOB = "1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c"
FIXTURE = "scripts/wull-fixtures/paint-moving-bottom-inset/shell.qml"
FIXTURE_BLOB = "26133a295433f7f61ce64f94a2ece3d14015a57b"
MODEL = "scripts/wull-private-dynamic-bottom-inset-model.py"
MODEL_BLOB = "834dc0e861bf2b06821a3f4399833201841e7d0e"
ORIGINAL_PNG = "scripts/wull-private-painted-alpha-model.py"
MAX_LOG = 256 * 1024
FILE_LIMIT = 8 * 1024 * 1024
MAX_PNG = 1024 * 1024
TIMEOUT = 48
CASES = ("m0", "m1")
PHASES = ("stretch", "release")
SAMPLES = 8
FAILURES = frozenset((
    "ACTIVE_SAMPLE_GEOMETRY_INVALID", "PRIVATE_CAPTURE_PATH_INVALID",
    "SAMPLE_SAVE_OR_MOTION_FAILED", "SAMPLE_GRAB_UNAVAILABLE",
    "BODY_MISSING", "OBSERVER_MAPPED_GEOMETRY_INVALID",
    "STRETCH_BASELINE_INVALID", "RELEASE_BASELINE_INVALID",
    "STRETCH_TARGET_NOT_OBSERVED", "RELEASE_TARGET_NOT_OBSERVED",
    "PRIVATE_WINDOWS_NOT_READY", "PRIVATE_NEUTRAL_STATE_UNVERIFIED",
    "PILOT_TIMEOUT",
    "ORIGINAL_MARGINS_OR_SOURCE_INVALID",
    "PRIVATE_INSET_GEOMETRY_INVALID",
)) | frozenset(
    "MOTION_" + case + "_" + phase + "_" + reason
    for case in ("M0", "M1")
    for phase in ("STRETCH", "RELEASE")
    for reason in (
        "OBSERVER_INSUFFICIENT",
        "SPRING_UNOBSERVED",
        "TRANSITION_UNOBSERVED",
        "MAPPED_UNOBSERVED",
    )
)


class ObservedQmlFailure(Exception):
    """Only fixed known names and stages, no raw Qt content."""

    def __init__(self, category, last_stage):
        self.category = category
        self.last_stage = last_stage


class Stop(Exception):
    pass


def require(value, code):
    if not value:
        raise Stop(code)


def audit():
    base = runpy.run_path(str(ROOT / BORROW),
                          run_name="wull_dynamic_paint_reviewed_guard")
    git = base["git"]
    require(git("rev-parse", "HEAD:" + BORROW) == BORROW_BLOB,
            "BORROWED_GUARD_CHANGED")
    try:
        source = base["audit_clone"]()
    except base["Stop"]:
        raise Stop("TRUSTED_CLONE_UNVERIFIED")
    for path, blob in (
        (FIXTURE, FIXTURE_BLOB), (MODEL, MODEL_BLOB),
        (ORIGINAL_PNG, "fa9e7c2af87ee830336988fa7060e2720e816ed0"),
    ):
        require(git("rev-parse", "HEAD:" + path) == blob,
                "DYNAMIC_PILOT_SOURCES_CHANGED")
    return base, source


def stages():
    result = ["BOOT", "CRADLE_MARGIN_PAIR_VERIFIED", "NEUTRAL_READY", "STRETCH_START"]
    for phase in PHASES:
        if phase == "release":
            result.append("RELEASE_START")
        for i in range(SAMPLES):
            for case in CASES:
                result.append(phase.upper() + "_" + str(i) +
                              "_" + case.upper())
    result.extend(("WITNESS_COMPLETE", "DONE"))
    return result


def private_stages(raw):
    observed, failure = [], []
    safe = set(stages())
    for line in raw.splitlines():
        if "WULL_MOVING_INSET_STAGE=" in line:
            token = line.split("WULL_MOVING_INSET_STAGE=", 1)[1].strip()
            require(token in safe and token not in observed,
                    "DYNAMIC_STAGE_INVALID")
            observed.append(token)
        if "WULL_MOVING_INSET_FAILURE=" in line:
            token = line.split("WULL_MOVING_INSET_FAILURE=", 1)[1].strip()
            require(token in FAILURES and token not in failure,
                    "DYNAMIC_FAILURE_UNRECOGNIZED")
            failure.append(token)
    return observed, failure


def secure_png(path):
    try:
        entry = path.lstat()
        require(stat.S_ISREG(entry.st_mode) and
                entry.st_uid == os.getuid() and
                not stat.S_IMODE(entry.st_mode) & 0o077 and
                0 < entry.st_size <= MAX_PNG, "DYNAMIC_PNG_UNSAFE")
        return path.read_bytes()
    except OSError:
        raise Stop("DYNAMIC_PNG_UNSAFE")


def private_classify(directory):
    expected_files = {
        phase + "-" + case + "-" + str(i) + ".private.png"
        for phase in PHASES for i in range(SAMPLES) for case in CASES
    }
    files = {p.name for p in directory.glob("*.private.png")}
    require(files == expected_files, "DYNAMIC_PNG_SET_INCOMPLETE")
    model = runpy.run_path(str(ROOT / MODEL),
                           run_name="wull_dynamic_paint_inert_classifier")
    alpha = runpy.run_path(str(ROOT / ORIGINAL_PNG),
                           run_name="wull_dynamic_paint_bounded_png_decoder")
    rows = []
    for phase, i, case in model["expected"]():
        stem = {"m0_150": "m0", "m1_150": "m1"}.get(case)
        require(stem is not None, "DYNAMIC_PAINT_ALPHA_INCONCLUSIVE")
        name = phase + "-" + stem + "-" + str(i) + ".private.png"
        raw = secure_png(directory / name)
        try:
            rows.append(model["classify"](case, phase, i, raw, alpha))
        except (ValueError, TypeError, KeyError):
            raise Stop("DYNAMIC_PAINT_ALPHA_INCONCLUSIVE")
    witness = {
        name: True for name in (
            "active_stretch", "active_release",
            "mapped_change_m0_stretch", "mapped_change_m1_stretch",
            "mapped_change_m0_release", "mapped_change_m1_release",
            "stretch_target_reached", "release_target_reached",
        )
    }
    try:
        return model["summarize"](rows, witness)
    except ValueError as exc:
        # Preserve the reviewed baseline failure as a fixed category.
        # Never publish private per-frame PNGs, paths or raw trace data.
        if str(exc) == "ORIGINAL_DYNAMIC_BASELINE_NOT_REPRODUCED":
            raise Stop("MOVING_BASELINE_NOT_REPRODUCED")
        raise Stop("DYNAMIC_PAINT_SUMMARY_INCONCLUSIVE")
    except (TypeError, KeyError):
        raise Stop("DYNAMIC_PAINT_SUMMARY_INCONCLUSIVE")


def resource_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_LIMIT, FILE_LIMIT))


def private_run(base):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    require(qs is not None and dbus is not None,
            "LOCAL_QT_DEPENDENCY_MISSING")
    frozen = runpy.run_path(
        str(ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="wull_dynamic_paint_qs_version_only")
    name = "qs" if shutil.which("qs") else "quickshell"
    require(frozen["version_of"](name, "--version") == "0.3.1",
            "QUICKSHELL_VERSION_MISMATCH")

    directory = ROOT.parent / "moving-bottom-inset"
    directory.mkdir(mode=0o700)
    try:
        shell, xdg = base["stage_files"](directory)
    except base["Stop"]:
        raise Stop("PRIVATE_DEPENDENCIES_UNAVAILABLE")
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    env = base["private_env"](
        xdg, directory / "unused.capture.not-created")
    env.pop("WULL_CAPTURE_OUTPUT", None)
    env.pop("WULL_DYNAMIC_PILOT_DIR", None)
    env.pop("WULL_DYNAMIC_CORE_DIR", None)
    env["WULL_MOVING_INSET_DIR"] = str(directory)
    log = directory / "moving-inset.private.log"
    timeout, code = False, None
    with log.open("xb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=resource_limits)
        try:
            try:
                code = proc.wait(timeout=TIMEOUT)
            except subprocess.TimeoutExpired:
                timeout = True
        finally:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait(timeout=3)
            time.sleep(.15)
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise Stop("PRIVATE_QT_CHILD_GROUP_STILL_PRESENT")
    require(not timeout, "PRIVATE_DYNAMIC_QT_TIMEOUT")
    try:
        st = log.lstat()
        require(stat.S_ISREG(st.st_mode) and
                st.st_uid == os.getuid() and
                not stat.S_IMODE(st.st_mode) & 0o077 and
                0 < st.st_size <= MAX_LOG, "PRIVATE_QT_LOG_UNSAFE")
        found, failures = private_stages(
            log.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        raise Stop("PRIVATE_QT_LOG_UNSAFE")
    require(code == 0, "PRIVATE_QT_NONZERO")
    if failures:
        # A specific fixture error MUST remain an error, even when many PNG
        # files exist. Permit only one allowlisted label after a valid prefix.
        require(len(failures) == 1 and found and
                found == stages()[:len(found)] and
                len(found) < len(stages()),
                "PRIVATE_QT_STAGE_OR_MOTION_INCONCLUSIVE")
        raise ObservedQmlFailure(failures[0], found[-1])
    require(found == stages(), "PRIVATE_QT_STAGE_OR_MOTION_INCONCLUSIVE")
    return private_classify(directory)


def main():
    require(sys.argv[1:] == [
        "--acknowledge-private-moving-bottom-cradle-inset"],
        "PRIVATE_MOVING_INSET_OPT_IN_REQUIRED")
    os.umask(0o077)
    base, source = audit()
    report = private_run(base)
    require(base["git"]("rev-parse", "HEAD") == source and
            not base["git"]("status", "--porcelain=v1",
                            "--untracked-files=all"),
            "POSTRUN_SOURCE_CHANGED")
    require(report["sampled_frames"] == 32 and len(report["cases"]) == 2,
            "DYNAMIC_PAINT_SUMMARY_INCONCLUSIVE")
    print("SOURCE_SHA=" + source)
    print("TWO_ORIGINAL_BOTTOM_FULL_COMPOSITES=SOURCE_PINNED")
    print("QT_DYNAMIC_INSET_FRAMES=32")
    print("INDEPENDENT_40MS_QT_MOTION_WITNESSES=YES")
    print("TWO_INDEPENDENT_SPRINGS_SEQUENTIALLY_CAPTURED=YES")
    print("MARGIN0_POSITIVE_BOTH_PHASES=YES")
    for row in report["cases"]:
        label = row["case"].upper()
        print(label + "_STRETCH_OUTSIDE_HOST=" +
              ("YES" if row["stretch_exterior_alpha_observed"] else "NO"))
        print(label + "_RELEASE_OUTSIDE_HOST=" +
              ("YES" if row["release_exterior_alpha_observed"] else "NO"))
    print("SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED")
    print("COMPOSITOR_AND_POINTER=UNTESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_MOVING_INSET_CANDIDATE_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except ObservedQmlFailure as ex:
        # Values originate ONLY from the source-reviewed strict fixture
        # failure set and successful ordered prefix. This is never PASS.
        if ex.category not in FAILURES or ex.last_stage not in stages():
            print("GATE=PRIVATE_OBSERVED_QML_FAILURE_INVALID")
        else:
            print("KNOWN_QML_FAILURE=" + ex.category)
            print("LAST_REVIEWED_STAGE=" + ex.last_stage)
            print("GATE=PRIVATE_MOVING_INSET_QML_FAILURE_IDENTIFIED")
        raise SystemExit(1)
    except (Stop, OSError, ValueError, KeyError,
            TypeError, subprocess.TimeoutExpired) as exc:
        allowed = {
            "BORROWED_GUARD_CHANGED", "TRUSTED_CLONE_UNVERIFIED",
            "DYNAMIC_PILOT_SOURCES_CHANGED",
            "DYNAMIC_STAGE_INVALID", "DYNAMIC_FAILURE_UNRECOGNIZED",
            "DYNAMIC_PNG_UNSAFE", "DYNAMIC_PNG_SET_INCOMPLETE",
            "DYNAMIC_PAINT_ALPHA_INCONCLUSIVE",
            "DYNAMIC_PAINT_SUMMARY_INCONCLUSIVE",
            "MOVING_BASELINE_NOT_REPRODUCED",
            "LOCAL_QT_DEPENDENCY_MISSING", "QUICKSHELL_VERSION_MISMATCH",
            "PRIVATE_DEPENDENCIES_UNAVAILABLE",
            "PRIVATE_QT_CHILD_GROUP_STILL_PRESENT",
            "PRIVATE_DYNAMIC_QT_TIMEOUT", "PRIVATE_QT_LOG_UNSAFE",
            "PRIVATE_QT_NONZERO", "PRIVATE_QT_STAGE_OR_MOTION_INCONCLUSIVE",
            "PRIVATE_MOVING_INSET_OPT_IN_REQUIRED", "POSTRUN_SOURCE_CHANGED",
        }
        code = str(exc)
        print("GATE=" + (code if code in allowed
                         else "PRIVATE_DYNAMIC_PILOT_UNAVAILABLE"))
        raise SystemExit(1)
