#!/usr/bin/env python3
"""Private one-original-component BOTTOM×1.5 cradle margin feasibility.

Four ORIGINAL full-composite frozen sequential offscreen Qt frames on the
SAME instance and body pose. ONLY private original cradle bottomMargin
varies (0,1,2,3 logical px). Not production patch/dynamic/Wayland clip.
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
BASE = "scripts/wull-manual-private-bottom-source.py"
BASE_BLOB = "5130e0dcf14e987291f828fc4ce6baaf8429af2f"
FIXTURE = "scripts/wull-fixtures/paint-bottom-inset/shell.qml"
FIXTURE_BLOB = "45fc03e743d08a996c763c491e0d2b42d22f75ba"
MODEL = "scripts/wull-private-bottom-cradle-inset-model.py"
MODEL_BLOB = "77c89bd49771992b2618ba656768840592aaa594"
ALPHA = "scripts/wull-private-painted-alpha-model.py"
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
MARGINS = (0, 1, 2, 3)
VARIANTS = ("m0", "m1", "m2", "m3")
MAX_LOG = 256 * 1024
MAX_PNG = 1024 * 1024
CHILD_FILE_LIMIT = 8 * 1024 * 1024
PROCESS_TIMEOUT = 34
FAILURES = frozenset((
    "ORIGINAL_MARGIN_RESTORE_FAILED", "ORIGINAL_SOURCE_OR_POSE_DRIFT",
    "INSET_GEOMETRY_OR_SOURCE_INVALID", "PRIVATE_CAPTURE_PATH_INVALID",
    "MARGIN_GRAB_OR_SAVE_FAILED", "MARGIN_GRAB_UNAVAILABLE",
    "ORIGINAL_SOURCE_TOPOLOGY_INVALID", "ORIGINAL_FROZEN_RENDERER_INVALID",
    "ORIGINAL_ZERO_MARGIN_POSE_INVALID", "BOTTOM_INSET_TIMEOUT",
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
        str(ROOT / BASE), run_name="bottom_inset_borrow_pinned_source_session")
    # Recursively pin the earlier owner-PASSED 12-case source, original
    # production QML, private sandbox and exact current clean dev HEAD.
    core, source = base["checked_sources"]()
    git = core["git"]
    for path, blob in (
        (BASE, BASE_BLOB), (FIXTURE, FIXTURE_BLOB),
        (MODEL, MODEL_BLOB), (ALPHA, ALPHA_BLOB),
    ):
        need(git("rev-parse", "HEAD:" + path) == blob,
             "BOTTOM_INSET_PIN_INVALID")
    return core, source


def expected_stages():
    result = ["BOOT", "PREPARED"]
    for margin in MARGINS:
        result.extend(("M" + str(margin) + "_REQUESTED",
                       "M" + str(margin) + "_SAVED"))
    result.append("DONE")
    return result


def private_stages(log):
    observed, failures = [], []
    expected = expected_stages()
    for line in log.splitlines():
        if "WULL_BOTTOM_INSET_STAGE=" in line:
            token = line.split("WULL_BOTTOM_INSET_STAGE=", 1)[1].strip()
            need(not failures and len(observed) < len(expected)
                 and token == expected[len(observed)],
                 "BOTTOM_INSET_STAGE_INVALID")
            observed.append(token)
        if "WULL_BOTTOM_INSET_FAILURE=" in line:
            token = line.split("WULL_BOTTOM_INSET_FAILURE=", 1)[1].strip()
            need(token in FAILURES and not failures,
                 "BOTTOM_INSET_FAILURE_UNRECOGNIZED")
            failures.append(token)
    return observed, failures


def secure_png(path):
    try:
        st = path.lstat()
        need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_PNG,
             "BOTTOM_INSET_PNG_UNSAFE")
        return path.read_bytes()
    except OSError:
        raise Stop("BOTTOM_INSET_PNG_UNSAFE")


def private_classify(directory):
    expected = {"m" + str(margin) + ".private.png" for margin in MARGINS}
    observed = {p.name for p in directory.glob("*.private.png")}
    need(observed == expected, "BOTTOM_INSET_PNG_SET_INCOMPLETE")
    images = {
        margin: secure_png(directory / ("m" + str(margin) + ".private.png"))
        for margin in MARGINS
    }
    model = runpy.run_path(
        str(ROOT / MODEL), run_name="bottom_inset_pure_rgba8_model")
    alpha = runpy.run_path(
        str(ROOT / ALPHA), run_name="bottom_inset_pinned_alpha_decoder")
    try:
        return model["classify"](images, alpha)
    except (ValueError, KeyError, TypeError):
        raise Stop("BOTTOM_INSET_ALPHA_INCONCLUSIVE")


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
    directory = ROOT.parent / "bottom-inset"
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
                  "WULL_DYNAMIC_PILOT_DIR", "WULL_DYNAMIC_CORE_DIR",
                  "WULL_BOTTOM_INSET_DIR"):
        env.pop(token, None)
    env["WULL_BOTTOM_INSET_DIR"] = str(directory)
    log = directory / "bottom-inset.private.log"
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
    need(not expired, "BOTTOM_INSET_PRIVATE_QT_TIMEOUT")
    try:
        st = log.lstat()
        need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_LOG,
             "BOTTOM_INSET_PRIVATE_QT_LOG_UNSAFE")
        stages, failures = private_stages(
            log.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        raise Stop("BOTTOM_INSET_PRIVATE_QT_LOG_UNSAFE")
    need(code == 0, "BOTTOM_INSET_PRIVATE_QT_NONZERO")
    if failures:
        need(stages and stages == expected_stages()[:len(stages)]
             and len(stages) < len(expected_stages()),
             "BOTTOM_INSET_STAGE_INCONCLUSIVE")
        raise ReviewedQmlFailure(failures[0], stages[-1])
    need(stages == expected_stages(), "BOTTOM_INSET_STAGE_INCONCLUSIVE")
    return private_classify(directory)


def main():
    need(sys.argv[1:] == ["--acknowledge-private-bottom-cradle-inset"],
         "BOTTOM_INSET_EXPLICIT_OPT_IN_REQUIRED")
    os.umask(0o077)
    core, source = checked_sources()
    report = private_run(core)
    need(core["git"]("rev-parse", "HEAD") == source and
         not core["git"]("status", "--porcelain=v1",
                         "--untracked-files=all"),
         "POSTRUN_SOURCE_IDENTITY_CHANGED")
    need(tuple(report["sampled_margin_values"]) == MARGINS and
         report["four_frames"] == 4 and
         set(report["exterior_by_margin"]) == set(MARGINS) and
         report["original_zero_margin_exterior"] is True,
         "BOTTOM_INSET_REPORT_INCONCLUSIVE")
    print("SOURCE_SHA=" + source)
    print("BOTTOM_SCALE=150")
    print("ORIGINAL_FULL_COMPOSITE=SOURCE_PINNED")
    print("ONE_QT_INSTANCE_AND_FIXED_BODY_POSE=YES")
    print("FOUR_SEQUENTIAL_PRIVATE_MARGINS=0,1,2,3")
    print("BASELINE_M0_OUTSIDE_HOST=YES")
    for margin in MARGINS[1:]:
        print("M" + str(margin) + "_OUTSIDE_HOST=" +
              ("YES" if report["exterior_by_margin"][margin] else "NO"))
    minimum = report["smallest_tested_zero_exterior_margin"]
    print("SMALLEST_TESTED_NO_EXTERIOR_MARGIN=" +
          ("NONE" if minimum is None else str(minimum)))
    print("DYNAMIC_MOTION=NOT_TESTED")
    print("COMPOSITOR_AND_POINTER=NOT_TESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_BOTTOM_INSET_CANDIDATE_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except ReviewedQmlFailure as exc:
        if exc.name in FAILURES and exc.stage in expected_stages():
            print("KNOWN_QML_FAILURE=" + exc.name)
            print("LAST_REVIEWED_STAGE=" + exc.stage)
            print("GATE=PRIVATE_BOTTOM_INSET_QML_FAILURE")
        else:
            print("GATE=PRIVATE_BOTTOM_INSET_QML_FAILURE_UNVERIFIED")
        raise SystemExit(1)
    except Exception as exc:
        allowed = {
            "BOTTOM_INSET_PIN_INVALID",
            "BOTTOM_INSET_STAGE_INVALID",
            "BOTTOM_INSET_FAILURE_UNRECOGNIZED",
            "BOTTOM_INSET_PNG_UNSAFE",
            "BOTTOM_INSET_PNG_SET_INCOMPLETE",
            "BOTTOM_INSET_ALPHA_INCONCLUSIVE",
            "LOCAL_PRIVATE_QT_MISSING",
            "PRIVATE_QS_VERSION_UNQUALIFIED",
            "PRIVATE_FIXTURE_DEPENDENCIES_MISSING",
            "PRIVATE_QT_PROCESS_GROUP_UNREAPED",
            "BOTTOM_INSET_PRIVATE_QT_TIMEOUT",
            "BOTTOM_INSET_PRIVATE_QT_LOG_UNSAFE",
            "BOTTOM_INSET_PRIVATE_QT_NONZERO",
            "BOTTOM_INSET_STAGE_INCONCLUSIVE",
            "BOTTOM_INSET_EXPLICIT_OPT_IN_REQUIRED",
            "POSTRUN_SOURCE_IDENTITY_CHANGED",
            "BOTTOM_INSET_REPORT_INCONCLUSIVE",
        }
        code = str(exc)
        print("GATE=" + (code if code in allowed else
                         "PRIVATE_BOTTOM_INSET_UNAVAILABLE"))
        raise SystemExit(1)
