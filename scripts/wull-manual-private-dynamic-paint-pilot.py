#!/usr/bin/env python3
"""ONE private source-pinned actual-QML dynamic FULL-composite painted alpha pilot.

TWO original companion instances: TOP x1 and BOTTOM x1.5. Samples 8 REAL
Qt grabs per each original authored spring stretch/release phase on each
isolated 320x300 private canvas. Original ShapePath-specific causal attribution
and real compositor clip/click still NOT tested. No Git publishing.
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
FIXTURE = "scripts/wull-fixtures/paint-dynamic-pilot/shell.qml"
FIXTURE_BLOB = "1f840534e93ff46deb401e52a3eb56cda09a807c"
MODEL = "scripts/wull-private-dynamic-paint-pilot-model.py"
MODEL_BLOB = "9ecde49a0d2f77e8fcb6f2d9309978945ef33d8c"
ORIGINAL_PNG = "scripts/wull-private-painted-alpha-model.py"
MAX_LOG = 256 * 1024
FILE_LIMIT = 8 * 1024 * 1024
MAX_PNG = 1024 * 1024
TIMEOUT = 48
CASES = ("top", "bottom")
PHASES = ("stretch", "release")
SAMPLES = 8
FAILURES = frozenset((
    "ACTIVE_SAMPLE_GEOMETRY_INVALID", "PRIVATE_CAPTURE_PATH_INVALID",
    "SAMPLE_SAVE_OR_MOTION_FAILED", "SAMPLE_GRAB_UNAVAILABLE",
    "SAMPLED_MAPPED_MOTION_NOT_OBSERVED", "BODY_MISSING",
    "STRETCH_TARGET_NOT_OBSERVED", "RELEASE_TARGET_NOT_OBSERVED",
    "PRIVATE_WINDOWS_NOT_READY", "PRIVATE_NEUTRAL_STATE_UNVERIFIED",
    "PILOT_TIMEOUT",
))


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
    result = ["BOOT", "NEUTRAL_READY", "STRETCH_START"]
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
        if "WULL_DYNAMIC_PILOT_STAGE=" in line:
            token = line.split("WULL_DYNAMIC_PILOT_STAGE=", 1)[1].strip()
            require(token in safe and token not in observed,
                    "DYNAMIC_STAGE_INVALID")
            observed.append(token)
        if "WULL_DYNAMIC_PILOT_FAILURE=" in line:
            token = line.split("WULL_DYNAMIC_PILOT_FAILURE=", 1)[1].strip()
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
        name = phase + "-" + case + "-" + str(i) + ".private.png"
        raw = secure_png(directory / name)
        key = "top_100" if case == "top_100" else "bottom_150"
        stem = "top" if key == "top_100" else "bottom"
        name = phase + "-" + stem + "-" + str(i) + ".private.png"
        raw = secure_png(directory / name)
        try:
            rows.append(model["classify"](key, phase, i, raw, alpha))
        except (ValueError, TypeError, KeyError):
            raise Stop("DYNAMIC_PAINT_ALPHA_INCONCLUSIVE")
    witness = {
        name: True for name in (
            "active_stretch", "active_release",
            "mapped_change_top_stretch", "mapped_change_bottom_stretch",
            "mapped_change_top_release", "mapped_change_bottom_release",
            "stretch_target_reached", "release_target_reached",
        )
    }
    try:
        return model["summarize"](rows, witness)
    except (ValueError, TypeError, KeyError):
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

    directory = ROOT.parent / "dynamic-paint-pilot"
    directory.mkdir(mode=0o700)
    try:
        shell, xdg = base["stage_files"](directory)
    except base["Stop"]:
        raise Stop("PRIVATE_DEPENDENCIES_UNAVAILABLE")
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    env = base["private_env"](
        xdg, directory / "unused.capture.not-created")
    env.pop("WULL_CAPTURE_OUTPUT", None)
    env["WULL_DYNAMIC_PILOT_DIR"] = str(directory)
    log = directory / "dynamic.private.log"
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
    require(not failures and found == stages(),
            "PRIVATE_QT_STAGE_OR_MOTION_INCONCLUSIVE")
    return private_classify(directory)


def main():
    require(sys.argv[1:] == [
        "--acknowledge-private-actual-dynamic-composite-pilot"],
        "PRIVATE_DYNAMIC_OPT_IN_REQUIRED")
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
    print("ORIGINAL_COMPOSITE=SOURCE_PINNED")
    print("QT_DYNAMIC_FRAMES=32")
    print("PHASE_AND_MAPPED_MOTION_WITNESSES=YES")
    for row in report["cases"]:
        label = row["case"].upper()
        print(label + "_STRETCH_OUTSIDE_HOST=" +
              ("YES" if row["stretch_exterior_alpha_observed"] else "NO"))
        print(label + "_RELEASE_OUTSIDE_HOST=" +
              ("YES" if row["release_exterior_alpha_observed"] else "NO"))
    print("BODY_CORE_ATTRIBUTION=UNTESTED")
    print("COMPOSITOR_AND_POINTER=UNTESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_DYNAMIC_COMPOSITE_PILOT_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, ValueError, KeyError,
            TypeError, subprocess.TimeoutExpired) as exc:
        allowed = {
            "BORROWED_GUARD_CHANGED", "TRUSTED_CLONE_UNVERIFIED",
            "DYNAMIC_PILOT_SOURCES_CHANGED",
            "DYNAMIC_STAGE_INVALID", "DYNAMIC_FAILURE_UNRECOGNIZED",
            "DYNAMIC_PNG_UNSAFE", "DYNAMIC_PNG_SET_INCOMPLETE",
            "DYNAMIC_PAINT_ALPHA_INCONCLUSIVE",
            "DYNAMIC_PAINT_SUMMARY_INCONCLUSIVE",
            "LOCAL_QT_DEPENDENCY_MISSING", "QUICKSHELL_VERSION_MISMATCH",
            "PRIVATE_DEPENDENCIES_UNAVAILABLE",
            "PRIVATE_QT_CHILD_GROUP_STILL_PRESENT",
            "PRIVATE_DYNAMIC_QT_TIMEOUT", "PRIVATE_QT_LOG_UNSAFE",
            "PRIVATE_QT_NONZERO", "PRIVATE_QT_STAGE_OR_MOTION_INCONCLUSIVE",
            "PRIVATE_DYNAMIC_OPT_IN_REQUIRED", "POSTRUN_SOURCE_CHANGED",
        }
        code = str(exc)
        print("GATE=" + (code if code in allowed
                         else "PRIVATE_DYNAMIC_PILOT_UNAVAILABLE"))
        raise SystemExit(1)
