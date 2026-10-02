#!/usr/bin/env python3
"""Explicit private static 4-edge x 3-scale ONE-session full/core alpha matrix.

Each case captures the ACTUAL full original companion first, then only its
source-original core ShapePath with four sibling visual children hidden on the
SAME fixed-pose instance. Second state is intentionally altered, not an exact
production render. No dynamic, compositor, pointer, Rust, Git publication.
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
BASE = "scripts/wull-manual-private-paint-paired.py"
BASE_BLOB = "c30279f99fbb05ff6e67d30c690b091851dfc4e5"
FIXTURE = "scripts/wull-fixtures/paint-static-matrix/shell.qml"
FIXTURE_BLOB = "064a4b59d686be74295b655dc8d4f4043efe4cc9"
MODEL = "scripts/wull-private-static-paired-matrix-model.py"
MODEL_BLOB = "b8870420db8d1e6cc08f1f5b0f792c4ab186be61"
ALPHA = "scripts/wull-private-painted-alpha-model.py"
MAX_LOG = 256 * 1024
FILE_LIMIT = 8 * 1024 * 1024
MAX_IMAGE_BYTES = 1024 * 1024
CAPTURE_TIMEOUT = 75
FAILURES = frozenset((
    "PAIR_POSE_DRIFT", "CORE_IDENTITY_CHANGED",
    "CORE_ISOLATION_FAILED", "CORE_FRAME_POSE_DRIFT",
    "PRIVATE_OUTPUT_INVALID", "CORE_GRAB_OR_SAVE_FAILED",
    "CORE_GRAB_UNAVAILABLE", "CASE_INDEX_INVALID",
    "CASE_HOST_OR_BODY_INVALID", "CASE_SOURCE_POSE_OR_VISUALS_INVALID",
    "CASE_MAPPED_GEOMETRY_INVALID", "FULL_GRAB_OR_SAVE_FAILED",
    "FULL_GRAB_UNAVAILABLE", "MATRIX_TIMEOUT",
))
EDGES = ("top", "right", "bottom", "left")
SCALES = (0.65, 1.0, 1.5)


class Stop(Exception):
    pass


def need(valid, category):
    if not valid:
        raise Stop(category)


def checked_sources():
    borrowed = runpy.run_path(
        str(ROOT / BASE), run_name="wull_matrix_paired_borrow_source")
    # This helper recursively checks the old paired/core guards, the exact
    # original actual QML blobs, trusted current dev and private ownership.
    core, source = borrowed["checked_base"]()
    git = core["git"]
    need(git("rev-parse", "HEAD:" + BASE) == BASE_BLOB,
         "PAIRED_BASE_DRIFT")
    need(git("rev-parse", "HEAD:" + FIXTURE) == FIXTURE_BLOB,
         "MATRIX_FIXTURE_DRIFT")
    need(git("rev-parse", "HEAD:" + MODEL) == MODEL_BLOB,
         "MATRIX_MODEL_DRIFT")
    need(git("rev-parse", "HEAD:" + ALPHA) ==
         "fa9e7c2af87ee830336988fa7060e2720e816ed0",
         "ALPHA_SOURCE_DRIFT")
    return core, source


def expected_stages():
    steps = ["BOOT"]
    for n in range(12):
        steps += [
            "CASE_" + str(n) + "_STARTED",
            "CASE_" + str(n) + "_FULL_REQUESTED",
            "CASE_" + str(n) + "_FULL_SAVED",
            "CASE_" + str(n) + "_CORE_REQUESTED",
            "CASE_" + str(n) + "_CORE_SAVED",
        ]
    steps.append("DONE")
    return steps


def classify_private_stages(raw):
    steps, failures = [], []
    allowed = set(expected_stages())
    for line in raw.splitlines():
        if "WULL_STATIC_MATRIX_STAGE=" in line:
            token = line.split("WULL_STATIC_MATRIX_STAGE=", 1)[1].strip()
            need(token in allowed and token not in steps,
                 "MATRIX_STAGE_INVALID")
            steps.append(token)
        if "WULL_STATIC_MATRIX_FAILURE=" in line:
            token = line.split("WULL_STATIC_MATRIX_FAILURE=", 1)[1].strip()
            need(token in FAILURES and token not in failures,
                 "MATRIX_FAILURE_UNRECOGNIZED")
            failures.append(token)
    return steps, failures


def file_bytes(path):
    # Exact expected file, owned regular file with no symlink, mode 0600,
    # bounded bytes. Never serialize original file paths or PNG payloads.
    try:
        st = path.lstat()
        need(stat.S_ISREG(st.st_mode)
             and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_IMAGE_BYTES,
             "UNSAFE_OR_INCOMPLETE_PNG")
        return path.read_bytes()
    except OSError:
        raise Stop("UNSAFE_OR_INCOMPLETE_PNG")


def private_classify(directory):
    matrix = runpy.run_path(
        str(ROOT / MODEL), run_name="wull_private_static_matrix_parser")
    alpha = runpy.run_path(
        str(ROOT / ALPHA), run_name="wull_private_static_matrix_png")
    names = {"full-" + str(i) + ".private.png" for i in range(12)}
    names |= {"core-" + str(i) + ".private.png" for i in range(12)}
    # No unchecked/unqualified duplicate image or unexpected capture slot.
    actual = {p.name for p in directory.glob("*.private.png")}
    need(actual == names, "CAPTURE_MATRIX_FILES_INCOMPLETE")
    rows = []
    for i in range(12):
        full = file_bytes(directory / ("full-" + str(i) + ".private.png"))
        core = file_bytes(directory / ("core-" + str(i) + ".private.png"))
        try:
            rows.append(matrix["classify"](i, full, core, alpha))
        except (ValueError, TypeError):
            raise Stop("CAPTURE_MATRIX_ALPHA_INCONCLUSIVE")
    try:
        return matrix["summarize"](rows)
    except (ValueError, TypeError):
        raise Stop("CAPTURE_MATRIX_RESULTS_INCONCLUSIVE")


def child_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_LIMIT, FILE_LIMIT))


def private_run(core):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    need(qs is not None and dbus is not None,
         "LOCAL_QT_DEPENDENCY_MISSING")
    frozen = runpy.run_path(str(
        ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="wull_static_matrix_version_only")
    binary = "qs" if shutil.which("qs") else "quickshell"
    need(frozen["version_of"](binary, "--version") == "0.3.1",
         "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE")
    directory = ROOT.parent / "static-matrix"
    directory.mkdir(mode=0o700)
    try:
        shell, xdg = core["stage_files"](directory)
    except core["Stop"]:
        raise Stop("PRIVATE_DEPENDENCIES_MISSING")
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    env = core["private_env"](
        xdg, directory / "unused-never-captured.private.png")
    env.pop("WULL_CAPTURE_OUTPUT", None)
    env.pop("WULL_CAPTURE_FULL", None)
    env.pop("WULL_CAPTURE_CORE", None)
    env["WULL_MATRIX_CAPTURE_DIR"] = str(directory)
    log = directory / "matrix.private.log"
    timed_out, code = False, None
    with log.open("xb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=child_limits)
        try:
            try:
                code = proc.wait(timeout=CAPTURE_TIMEOUT)
            except subprocess.TimeoutExpired:
                timed_out = True
        finally:
            # Dedicated newly created private process group ONLY.
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
                raise Stop("PRIVATE_MATRIX_CHILD_GROUP_REMAINING")
    need(not timed_out, "PRIVATE_MATRIX_QT_TIMEOUT")
    try:
        st = log.lstat()
        need(stat.S_ISREG(st.st_mode)
             and st.st_uid == os.getuid()
             and not stat.S_IMODE(st.st_mode) & 0o077
             and 0 < st.st_size <= MAX_LOG,
             "PRIVATE_MATRIX_LOG_UNSAFE")
        stages, failures = classify_private_stages(
            log.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        raise Stop("PRIVATE_MATRIX_LOG_UNSAFE")
    need(code == 0, "PRIVATE_MATRIX_QT_NONZERO")
    need(not failures and stages == expected_stages(),
         "PRIVATE_MATRIX_STAGES_INCOMPLETE")
    return private_classify(directory)


def main():
    need(sys.argv[1:] == ["--acknowledge-private-static-paired-matrix"],
         "EXPLICIT_MATRIX_CAPTURE_OPT_IN_REQUIRED")
    os.umask(0o077)
    core, source = checked_sources()
    report = private_run(core)
    need(core["git"]("rev-parse", "HEAD") == source
         and not core["git"]("status", "--porcelain=v1",
                             "--untracked-files=all"),
         "POSTRUN_SOURCE_IDENTITY_CHANGED")
    need(report["qualified_case_count"] == 12,
         "CAPTURE_MATRIX_RESULTS_INCONCLUSIVE")
    print("SOURCE_SHA=" + source)
    print("ORIGINAL_COMPANION=SOURCE_PINNED")
    print("PAIRED_STATIC_HOST_CASES=12")
    print("SAME_QT_SESSION=YES")
    print("SAME_POSE_WITHIN_EACH_PAIR=YES")
    print("SEQUENTIAL_ALTERED_CORE_SCENE=YES")
    for i, row in enumerate(report["cases"]):
        label = ("CASE_" + str(i).zfill(2) + "_" +
                 row["edge"].upper() + "_S" +
                 str(round(row["scale"] * 100)).zfill(3))
        result = ("F" + str(int(row["composite_outside_host"])) +
                  "C" + str(int(row["source_core_outside_host"])) +
                  "O" + str(int(row["same_pixel_exterior_overlap"])))
        print(label + "=" + result)
    print("DYNAMIC_PAINT=NOT_TESTED")
    print("COMPOSITOR_CLIP_AND_INPUT=NOT_TESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_STATIC_PAIRED_MATRIX_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, ValueError, TypeError, KeyError,
            subprocess.TimeoutExpired) as exc:
        allowed = {
            "PAIRED_BASE_DRIFT", "MATRIX_FIXTURE_DRIFT",
            "MATRIX_MODEL_DRIFT", "ALPHA_SOURCE_DRIFT",
            "MATRIX_STAGE_INVALID", "MATRIX_FAILURE_UNRECOGNIZED",
            "UNSAFE_OR_INCOMPLETE_PNG",
            "CAPTURE_MATRIX_FILES_INCOMPLETE",
            "CAPTURE_MATRIX_ALPHA_INCONCLUSIVE",
            "CAPTURE_MATRIX_RESULTS_INCONCLUSIVE",
            "LOCAL_QT_DEPENDENCY_MISSING",
            "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE",
            "PRIVATE_DEPENDENCIES_MISSING",
            "PRIVATE_MATRIX_CHILD_GROUP_REMAINING",
            "PRIVATE_MATRIX_QT_TIMEOUT", "PRIVATE_MATRIX_LOG_UNSAFE",
            "PRIVATE_MATRIX_QT_NONZERO", "PRIVATE_MATRIX_STAGES_INCOMPLETE",
            "EXPLICIT_MATRIX_CAPTURE_OPT_IN_REQUIRED",
            "POSTRUN_SOURCE_IDENTITY_CHANGED",
        }
        category = str(exc)
        print("GATE=" + (category if category in allowed
                         else "PRIVATE_MATRIX_UNAVAILABLE"))
        raise SystemExit(1)
