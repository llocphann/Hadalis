#!/usr/bin/env python3
"""Owner-only one-instance BOTTOM×1.5 frozen source-layer classification.

FULL, original Bézier/stroke CORE, four internal BODY DETAILS combined and
original external CRADLE: one actual original component, same mapped pose,
four deliberately altered sequential private Qt captures, NOT simultaneity,
production paint causality, native Wayland clipping or clickable input.
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
BASE = "scripts/wull-manual-private-paired-static-matrix.py"
BASE_BLOB = "fee5944e8fe9fb40a38da24edd104ef78ef32496"
FIXTURE = "scripts/wull-fixtures/paint-bottom-source/shell.qml"
FIXTURE_BLOB = "3838ac82c70263324fa50185d75a60478363f7c1"
MODEL = "scripts/wull-private-bottom-static-source-model.py"
MODEL_BLOB = "3eb60d0b7222c12f6d07a772f3bbf94e0cadb3f3"
ALPHA = "scripts/wull-private-painted-alpha-model.py"
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
VARIANTS = ("full", "core", "details", "cradle")
MAX_LOG = 256 * 1024
MAX_PNG = 1024 * 1024
CHILD_FILE_LIMIT = 8 * 1024 * 1024
PROCESS_TIMEOUT = 34
FAILURES = frozenset((
    "FINAL_ORIGINAL_SCENE_RESTORE_FAILED",
    "SOURCE_VISIBILITY_OR_POSE_CHANGED",
    "PRE_CAPTURE_SCENE_DRIFT",
    "PRIVATE_OUTPUT_UNAVAILABLE",
    "SCENE_GRAB_OR_SAVE_FAILED",
    "SCENE_GRAB_UNAVAILABLE",
    "ORIGINAL_SOURCE_TOPOLOGY_INVALID",
    "FROZEN_SOURCE_STATE_INVALID",
    "SOURCE_IDENTITY_OR_MAPPED_POSE_INVALID",
    "BOTTOM_SOURCE_TIMEOUT",
))


class Stop(Exception):
    pass


class ReviewedQmlFailure(Exception):
    def __init__(self, name, stage):
        self.name, self.stage = name, stage


def need(value, code):
    if not value:
        raise Stop(code)


def checked_sources():
    base = runpy.run_path(
        str(ROOT / BASE), run_name="bottom_source_borrow_pinned_static_matrix")
    # Recursively pin the earlier owner-PASSED 12-case source, original
    # production QML, private sandbox and exact current clean dev HEAD.
    core, source = base["checked_sources"]()
    git = core["git"]
    for path, blob in (
        (BASE, BASE_BLOB), (FIXTURE, FIXTURE_BLOB),
        (MODEL, MODEL_BLOB), (ALPHA, ALPHA_BLOB),
    ):
        need(git("rev-parse", "HEAD:" + path) == blob,
             "BOTTOM_SOURCE_PIN_INVALID")
    return core, source


def expected_stages():
    result = ["BOOT", "PREPARED"]
    for name in VARIANTS:
        result.extend((name.upper() + "_REQUESTED",
                       name.upper() + "_SAVED"))
    result.append("DONE")
    return result


def private_stages(log):
    observed, failures = [], []
    expected = expected_stages()
    for line in log.splitlines():
        if "WULL_BOTTOM_SOURCE_STAGE=" in line:
            token = line.split("WULL_BOTTOM_SOURCE_STAGE=", 1)[1].strip()
            need(not failures and len(observed) < len(expected)
                 and token == expected[len(observed)],
                 "BOTTOM_SOURCE_STAGE_INVALID")
            observed.append(token)
        if "WULL_BOTTOM_SOURCE_FAILURE=" in line:
            token = line.split("WULL_BOTTOM_SOURCE_FAILURE=", 1)[1].strip()
            need(token in FAILURES and not failures,
                 "BOTTOM_SOURCE_FAILURE_UNRECOGNIZED")
            failures.append(token)
    return observed, failures


def secure_png(path):
    try:
        st = path.lstat()
        need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_PNG,
             "BOTTOM_SOURCE_PNG_UNSAFE")
        return path.read_bytes()
    except OSError:
        raise Stop("BOTTOM_SOURCE_PNG_UNSAFE")


def private_classify(directory):
    expected = {name + ".private.png" for name in VARIANTS}
    seen = {p.name for p in directory.glob("*.private.png")}
    need(seen == expected, "BOTTOM_SOURCE_PNG_SET_INCOMPLETE")
    images = {
        name: secure_png(directory / (name + ".private.png"))
        for name in VARIANTS
    }
    model = runpy.run_path(
        str(ROOT / MODEL), run_name="bottom_source_pure_png_model")
    png = runpy.run_path(
        str(ROOT / ALPHA), run_name="bottom_source_pinned_rgba8")
    try:
        return model["classify"](images, png)
    except (ValueError, TypeError, KeyError):
        raise Stop("BOTTOM_SOURCE_ALPHA_INCONCLUSIVE")


def child_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE,
                       (CHILD_FILE_LIMIT, CHILD_FILE_LIMIT))


def private_run(core):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    need(bool(qs and dbus), "LOCAL_PRIVATE_QT_MISSING")
    frozen = runpy.run_path(
        str(ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="bottom_source_qs_version_only")
    binary = "qs" if shutil.which("qs") else "quickshell"
    need(frozen["version_of"](binary, "--version") == "0.3.1",
         "PRIVATE_QS_VERSION_UNQUALIFIED")
    directory = ROOT.parent / "bottom-source"
    directory.mkdir(mode=0o700)
    try:
        shell, xdg = core["stage_files"](directory)
    except core["Stop"]:
        raise Stop("PRIVATE_FIXTURE_DEPENDENCIES_MISSING")
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    env = core["private_env"](
        xdg, directory / "unused.not-a-capture")
    for token in ("WULL_CAPTURE_OUTPUT", "WULL_CAPTURE_FULL",
                  "WULL_CAPTURE_CORE", "WULL_MATRIX_CAPTURE_DIR",
                  "WULL_DYNAMIC_PILOT_DIR", "WULL_DYNAMIC_CORE_DIR"):
        env.pop(token, None)
    env["WULL_BOTTOM_SOURCE_DIR"] = str(directory)
    log = directory / "bottom-source.private.log"
    code, expired = None, False
    with log.open("xb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=child_limits)
        try:
            try:
                code = proc.wait(timeout=PROCESS_TIMEOUT)
            except subprocess.TimeoutExpired:
                expired = True
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
                raise Stop("PRIVATE_QT_PROCESS_GROUP_UNREAPED")
    need(not expired, "BOTTOM_SOURCE_PRIVATE_QT_TIMEOUT")
    try:
        st = log.lstat()
        need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_LOG,
             "BOTTOM_SOURCE_PRIVATE_QT_LOG_UNSAFE")
        stages, failures = private_stages(
            log.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        raise Stop("BOTTOM_SOURCE_PRIVATE_QT_LOG_UNSAFE")
    need(code == 0, "BOTTOM_SOURCE_PRIVATE_QT_NONZERO")
    if failures:
        need(stages and stages == expected_stages()[:len(stages)]
             and len(stages) < len(expected_stages()),
             "BOTTOM_SOURCE_STAGE_INCONCLUSIVE")
        raise ReviewedQmlFailure(failures[0], stages[-1])
    need(stages == expected_stages(), "BOTTOM_SOURCE_STAGE_INCONCLUSIVE")
    return private_classify(directory)


def main():
    need(sys.argv[1:] == ["--acknowledge-private-bottom-original-source"],
         "BOTTOM_SOURCE_EXPLICIT_OPT_IN_REQUIRED")
    os.umask(0o077)
    core, source = checked_sources()
    results = private_run(core)
    need(core["git"]("rev-parse", "HEAD") == source and
         not core["git"]("status", "--porcelain=v1",
                         "--untracked-files=all"),
         "POSTRUN_SOURCE_IDENTITY_CHANGED")
    need(set(results["outside"]) == set(VARIANTS)
         and set(results["full_exterior_same_pixel_overlap"])
         == set(VARIANTS) - {"full"},
         "BOTTOM_SOURCE_REPORT_INCONCLUSIVE")
    print("SOURCE_SHA=" + source)
    print("BOTTOM_SCALE=150")
    print("ORIGINAL_COMPANION=SOURCE_PINNED")
    print("ONE_QT_INSTANCE_AND_FIXED_POSE=YES")
    print("FOUR_SEQUENTIAL_PRIVATE_CAPTURES=YES")
    for name in VARIANTS:
        print(name.upper() + "_EXTERIOR=" +
              ("YES" if results["outside"][name] else "NO"))
    for name in VARIANTS[1:]:
        print(name.upper() + "_SAME_EXTERIOR_PIXEL_AS_FULL=" +
              ("YES" if results["full_exterior_same_pixel_overlap"][name]
               else "NO"))
    print("SOURCE_PIXEL_CAUSALITY=NOT_PROVEN")
    print("DYNAMIC_MOTION=NOT_TESTED")
    print("COMPOSITOR_AND_POINTER=NOT_TESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_BOTTOM_STATIC_SOURCE_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except ReviewedQmlFailure as ex:
        if ex.name in FAILURES and ex.stage in expected_stages():
            print("KNOWN_QML_FAILURE=" + ex.name)
            print("LAST_REVIEWED_STAGE=" + ex.stage)
            print("GATE=PRIVATE_BOTTOM_SOURCE_QML_FAILURE")
        else:
            print("GATE=PRIVATE_BOTTOM_SOURCE_FAILURE_UNVERIFIED")
        raise SystemExit(1)
    except Exception as ex:
        safe = {
            "BOTTOM_SOURCE_PIN_INVALID", "BOTTOM_SOURCE_STAGE_INVALID",
            "BOTTOM_SOURCE_FAILURE_UNRECOGNIZED",
            "BOTTOM_SOURCE_PNG_UNSAFE", "BOTTOM_SOURCE_PNG_SET_INCOMPLETE",
            "BOTTOM_SOURCE_ALPHA_INCONCLUSIVE",
            "LOCAL_PRIVATE_QT_MISSING",
            "PRIVATE_QS_VERSION_UNQUALIFIED",
            "PRIVATE_FIXTURE_DEPENDENCIES_MISSING",
            "PRIVATE_QT_PROCESS_GROUP_UNREAPED",
            "BOTTOM_SOURCE_PRIVATE_QT_TIMEOUT",
            "BOTTOM_SOURCE_PRIVATE_QT_LOG_UNSAFE",
            "BOTTOM_SOURCE_PRIVATE_QT_NONZERO",
            "BOTTOM_SOURCE_STAGE_INCONCLUSIVE",
            "BOTTOM_SOURCE_EXPLICIT_OPT_IN_REQUIRED",
            "POSTRUN_SOURCE_IDENTITY_CHANGED",
            "BOTTOM_SOURCE_REPORT_INCONCLUSIVE",
        }
        code = str(ex)
        print("GATE=" + (code if code in safe else
                         "PRIVATE_BOTTOM_SOURCE_UNAVAILABLE"))
        raise SystemExit(1)
