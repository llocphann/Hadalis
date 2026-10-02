#!/usr/bin/env python3
"""Source-guarded, private SAME-Qt-session full vs original ShapePath alpha probe.

One owned TOP scale=1 frozen-pose offscreen Quickshell process. A is original
whole AbyssCompanion; B is the SAME companion instance after hiding four
non-core WaterDropletBody visual siblings in the fixture. No Qt screenshots
outside our stage, no compositor test, no dynamic frames, no Git writes.
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
BASE = "scripts/wull-manual-private-paint-core.py"
BASE_BLOB = "1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c"
FIXTURE = "scripts/wull-fixtures/paint-alpha-paired/shell.qml"
FIXTURE_BLOB = "83326999c8363420fabb5bbb5022d100ab1a64c6"
MODEL = "scripts/wull-private-painted-alpha-model.py"
STAGES = (
    "BOOT", "SETUP_VERIFIED", "COMPOSITE_REQUESTED", "COMPOSITE_SAVED",
    "CORE_ISOLATED", "CORE_REQUESTED", "CORE_SAVED", "FINISHED",
)
FAILURES = frozenset((
    "PAIRED_POSE_DRIFT", "CORE_ISOLATION_UNVERIFIED",
    "CORE_POSE_OR_ISOLATION_DRIFT", "CORE_PNG_OR_POSE_FAILURE",
    "CORE_GRAB_UNAVAILABLE", "HOST_OR_BODY_UNVERIFIED",
    "PRIVATE_POSE_OR_VISUALS_INVALID", "PRIVATE_POSE_GEOMETRY_INVALID",
    "PRIVATE_OUTPUTS_INVALID", "PRE_FULL_POSE_DRIFT",
    "COMPOSITE_PNG_OR_POSE_FAILURE", "COMPOSITE_GRAB_UNAVAILABLE",
    "CAPTURE_TIMEOUT",
))
MAX_LOG = 256 * 1024
FILE_LIMIT = 8 * 1024 * 1024
THRESHOLD = 24
HOST = (100, 100, 112, 98)


class Stop(Exception):
    pass


def need(ok, code):
    if not ok:
        raise Stop(code)


def checked_base():
    base = runpy.run_path(str(ROOT / BASE),
                          run_name="wull_paired_borrow_reviewed_safety")
    git = base["git"]
    need(git("rev-parse", "HEAD:" + BASE) == BASE_BLOB,
         "PINNED_CORE_RUNNER_CHANGED")
    need(git("rev-parse", "HEAD:" + FIXTURE) == FIXTURE_BLOB,
         "PAIRED_FIXTURE_CHANGED")
    try:
        source = base["audit_clone"]()
    except base["Stop"]:
        raise Stop("REVIEWED_PRIVATE_CLONE_AUDIT_FAILED")
    return base, source


def stages_from_log(raw):
    names, failures = [], []
    for line in raw.splitlines():
        if "WULL_PAIRED_CORE_STAGE=" in line:
            name = line.split("WULL_PAIRED_CORE_STAGE=", 1)[1].strip()
            need(name in STAGES and name not in names,
                 "PAIRED_STAGE_INVALID")
            names.append(name)
        if "WULL_PAIRED_CORE_FAILURE=" in line:
            name = line.split("WULL_PAIRED_CORE_FAILURE=", 1)[1].strip()
            need(name in FAILURES and name not in failures,
                 "PAIRED_FAILURE_UNRECOGNIZED")
            failures.append(name)
    return names, failures


def child_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_LIMIT, FILE_LIMIT))


def classify_private_images(base, full, core):
    # Independently verify PNG ownership, RGBA8, expected full canvas,
    # painted interior and transparent edge bounds for BOTH captures.
    try:
        full_outside = base["verify_png"](full)
        core_outside = base["verify_png"](core)
        model = runpy.run_path(str(ROOT / MODEL),
                               run_name="wull_paired_inert_alpha_model")
        fw, fh, full_alpha = model["png_alpha"](full.read_bytes())
        cw, ch, core_alpha = model["png_alpha"](core.read_bytes())
    except (base["Stop"], OSError, TypeError, ValueError):
        raise Stop("PAIRED_PRIVATE_IMAGE_INVALID")
    need((fw, fh, cw, ch) == (320, 300, 320, 300),
         "PAIRED_CANVAS_MISMATCH")
    margin = model["EDGE_MARGIN"]
    threshold = model["ALPHA_THRESHOLD"]
    need(threshold == THRESHOLD, "PAIRED_ALPHA_MODEL_CHANGED")
    x0, y0, w, h = HOST
    both_exterior = 0
    core_exterior = 0
    composite_exterior = 0
    for y in range(margin, fh - margin):
        for x in range(margin, fw - margin):
            if x0 <= x + .5 < x0 + w and y0 <= y + .5 < y0 + h:
                continue
            idx = y * fw + x
            a = full_alpha[idx] >= threshold
            b = core_alpha[idx] >= threshold
            composite_exterior += bool(a)
            core_exterior += bool(b)
            both_exterior += bool(a and b)
    need((composite_exterior > 0) == full_outside and
         (core_exterior > 0) == core_outside,
         "PAIRED_ALPHA_CLASSIFICATION_MISMATCH")
    return full_outside, core_outside, both_exterior > 0


def private_run(base):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    need(qs is not None and dbus is not None,
         "LOCAL_QT_DEPENDENCY_MISSING")
    frozen = runpy.run_path(
        str(ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="wull_paired_version_only")
    binary = "qs" if shutil.which("qs") else "quickshell"
    need(frozen["version_of"](binary, "--version") == "0.3.1",
         "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE")

    private = ROOT.parent / "paired"
    private.mkdir(mode=0o700)
    try:
        shell, xdg = base["stage_files"](private)
    except base["Stop"]:
        raise Stop("PRIVATE_DEPENDENCY_MISSING")
    # Change only disposable private shell.qml, never repository source.
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    full = private / "full.private.png"
    core = private / "core.private.png"
    log = private / "paired.private.log"
    env = base["private_env"](xdg, full)
    env.pop("WULL_CAPTURE_OUTPUT", None)
    env["WULL_CAPTURE_FULL"] = str(full)
    env["WULL_CAPTURE_CORE"] = str(core)
    timeout = False
    code = None
    with log.open("xb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=child_limits)
        try:
            try:
                code = proc.wait(timeout=14)
            except subprocess.TimeoutExpired:
                timeout = True
        finally:
            # NEVER signal a process outside this NEW owned session group.
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
                raise Stop("PRIVATE_PAIRED_CHILD_GROUP_STILL_PRESENT")
    need(not timeout, "PAIRED_QT_TIMEOUT")
    st = log.lstat()
    need(stat.S_ISREG(st.st_mode) and
         st.st_uid == os.getuid() and
         not stat.S_IMODE(st.st_mode) & 0o077 and
         0 < st.st_size <= MAX_LOG, "PAIRED_PRIVATE_LOG_UNSAFE")
    stages, failures = stages_from_log(
        log.read_text(encoding="utf-8", errors="replace"))
    need(code == 0, "PAIRED_QT_EXIT_NONZERO")
    need(not failures and stages == list(STAGES),
         "PAIRED_STAGE_SEQUENCE_INCONCLUSIVE")
    return classify_private_images(base, full, core)


def main():
    need(sys.argv[1:] == ["--acknowledge-private-paired-static-core"],
         "EXPLICIT_PAIRED_PRIVATE_OPT_IN_REQUIRED")
    os.umask(0o077)
    base, source = checked_base()
    full, core, overlap = private_run(base)
    need(base["git"]("rev-parse", "HEAD") == source and
         not base["git"]("status", "--porcelain=v1",
                         "--untracked-files=all"),
         "POSTRUN_SOURCE_CHANGED")
    print("SOURCE_SHA=" + source)
    print("ACTUAL_UNMODIFIED_COMPANION=YES")
    print("SAME_QT_SESSION=YES")
    print("FIXED_MAPPED_POSE=YES")
    print("PRIVATE_CORE_CHILDREN_HIDDEN=YES")
    print("COMPOSITE_OUTSIDE_HOST_ALPHA=" + ("YES" if full else "NO"))
    print("CORE_OUTSIDE_HOST_ALPHA=" + ("YES" if core else "NO"))
    print("SAME_PIXEL_EXTERIOR_OVERLAP=" + ("YES" if overlap else "NO"))
    print("EXACT_PRODUCTION_PAINT_AND_CLICK=NOT_PROVEN")
    print("DYNAMIC_WITNESS=NOT_RUN")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_PAIRED_STATIC_CORE_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, TypeError, ValueError, KeyError,
            subprocess.TimeoutExpired) as exc:
        allowed = {
            "PINNED_CORE_RUNNER_CHANGED", "PAIRED_FIXTURE_CHANGED",
            "REVIEWED_PRIVATE_CLONE_AUDIT_FAILED",
            "PAIRED_STAGE_INVALID", "PAIRED_FAILURE_UNRECOGNIZED",
            "PAIRED_PRIVATE_IMAGE_INVALID", "PAIRED_CANVAS_MISMATCH",
            "PAIRED_ALPHA_MODEL_CHANGED",
            "PAIRED_ALPHA_CLASSIFICATION_MISMATCH",
            "LOCAL_QT_DEPENDENCY_MISSING",
            "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE",
            "PRIVATE_DEPENDENCY_MISSING",
            "PRIVATE_PAIRED_CHILD_GROUP_STILL_PRESENT", "PAIRED_QT_TIMEOUT",
            "PAIRED_PRIVATE_LOG_UNSAFE", "PAIRED_QT_EXIT_NONZERO",
            "PAIRED_STAGE_SEQUENCE_INCONCLUSIVE",
            "EXPLICIT_PAIRED_PRIVATE_OPT_IN_REQUIRED",
            "POSTRUN_SOURCE_CHANGED",
        }
        code = str(exc)
        print("GATE=" + (code if code in allowed
                         else "PAIRED_PRIVATE_CAPTURE_UNAVAILABLE"))
        raise SystemExit(1)
