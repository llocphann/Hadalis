#!/usr/bin/env python3
"""Explicit ONE-case original-Wull PNG feasibility; offscreen/owner-local ONLY.

No host screen capture, compositor, Niri, pointer injection, backend, Git
commit or publication. A pass demonstrates only a static TOP scale-1 composite
PNG can be captured and parsed in this private offscreen environment.
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
FIXTURE = "scripts/wull-fixtures/paint-alpha-canary/shell.qml"
MODEL = "scripts/wull-private-painted-alpha-model.py"
PINS = {
    FIXTURE: "d2f3d654440f1ca4b3fc3e173cbf332b4add777b",
    MODEL: "fa9e7c2af87ee830336988fa7060e2720e816ed0",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/looks/AbyssStyle.qml":
        "4cc05dbaf547a3eff366647cb388abe8c31af5d5",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
    "defaults/config.json": "e10d98c0f26d3e47c51cb8452bcd0d2cea735501",
}
ORIGINS = {
    "https://github.com/llocphann/Hadalis.git",
    "https://github.com/llocphann/Hadalis",
}
STAGES = ("BOOT", "CAPTURE_REQUESTED", "PNG_SAVED")
FAILURES = {
    "WINDOW_OR_STAGE_INVALID", "ACTUAL_BODY_NOT_IDENTIFIED",
    "PRIVATE_OUTPUT_NOT_SET", "PNG_SAVE_FAILED", "GRAB_UNAVAILABLE",
    "CAPTURE_TIMEOUT",
}
MAX_LOG = 256 * 1024
FILE_LIMIT = 8 * 1024 * 1024


class Stop(Exception):
    pass


def require(condition, code):
    if not condition:
        raise Stop(code)


def git(*args):
    process = subprocess.run(
        ["git", *args], cwd=ROOT, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, timeout=30)
    require(process.returncode == 0, "GIT_VERIFICATION_FAILED")
    return process.stdout.strip()


def audit_clone():
    scratch = ROOT.parent
    require(ROOT.name == "repo" and
            scratch.name.startswith("wull-paint-canary.") and
            not ROOT.is_symlink() and not scratch.is_symlink() and
            Path.cwd().resolve() == ROOT, "UNTRUSTED_PRIVATE_CLONE")
    for directory in (scratch, ROOT):
        info = directory.stat()
        require(info.st_uid == os.getuid() and
                not stat.S_IMODE(info.st_mode) & 0o077,
                "PRIVATE_CLONE_MODE_INVALID")
    require(git("symbolic-ref", "--short", "HEAD") == "dev" and
            not git("status", "--porcelain=v1", "--untracked-files=all"),
            "DIRTY_OR_WRONG_BRANCH")
    require(git("remote", "get-url", "origin") in ORIGINS and
            git("remote", "get-url", "--push", "origin") in ORIGINS,
            "UNTRUSTED_REMOTE")
    head = git("rev-parse", "HEAD")
    refs = git("ls-remote", "origin", "refs/heads/dev").splitlines()
    require(len(refs) == 1 and refs[0].split()[0] == head,
            "REMOTE_HEAD_CHANGED")
    for name, blob in PINS.items():
        require(git("rev-parse", "HEAD:" + name) == blob,
                "REVIEWED_SOURCE_CHANGED")
    return head


def child_resource_limit():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_LIMIT, FILE_LIMIT))


def private_env(xdg, png):
    environ = dict(os.environ)
    for key in (
        "DISPLAY", "WAYLAND_DISPLAY", "NIRI_SOCKET", "QS_CONFIG_PATH",
        "QS_CONFIG_NAME", "QS_MANIFEST", "INIR_COMPANIOND",
        "QML_IMPORT_PATH", "QML2_IMPORT_PATH", "DBUS_SESSION_BUS_ADDRESS",
        "DBUS_SYSTEM_BUS_ADDRESS", "WULL_CAPTURE_OUTPUT",
    ):
        environ.pop(key, None)
    environ.update({
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_RUNTIME_DIR": str(xdg / "runtime"),
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
        "WULL_CAPTURE_OUTPUT": str(png),
    })
    return environ


def stage_files(private):
    shell = private / "shell"
    shell.mkdir(mode=0o700)
    for name in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        require((ROOT / name).exists(), "PRIVATE_DEPENDENCY_MISSING")
        (shell / name).symlink_to(ROOT / name)
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    xdg = private / "xdg"
    for name in ("runtime", "config", "data", "cache", "state"):
        (xdg / name).mkdir(parents=True, mode=0o700)
    cfg = xdg / "config" / "illogical-impulse"
    cfg.mkdir(mode=0o700)
    shutil.copyfile(ROOT / "defaults/config.json", cfg / "config.json")
    return shell, xdg


def stages_from_log(raw):
    stages = []
    failures = []
    for line in raw.splitlines():
        if "WULL_PAINT_CANARY_STAGE=" in line:
            stage = line.split("WULL_PAINT_CANARY_STAGE=", 1)[1].strip()
            require(stage in STAGES and stage not in stages,
                    "PRIVATE_STAGE_SEQUENCE_INVALID")
            stages.append(stage)
        if "WULL_PAINT_CANARY_FAILURE=" in line:
            failure = line.split("WULL_PAINT_CANARY_FAILURE=", 1)[1].strip()
            require(failure in FAILURES and failure not in failures,
                    "PRIVATE_FAILURE_UNRECOGNIZED")
            failures.append(failure)
    return stages, failures


def verify_png(png):
    info = png.lstat()
    require(stat.S_ISREG(info.st_mode) and
            info.st_uid == os.getuid() and
            not stat.S_IMODE(info.st_mode) & 0o077 and
            0 < info.st_size <= 1024 * 1024,
            "PRIVATE_PNG_MISSING_OR_UNSAFE")
    model = runpy.run_path(str(ROOT / MODEL),
                           run_name="private_paint_canary_png_parser")
    width, height, alpha = model["png_alpha"](png.read_bytes())
    require((width, height) == (320, 300), "PRIVATE_PNG_DIMENSIONS_INVALID")
    margin = model["EDGE_MARGIN"]
    count_inside = count_outside = 0
    for y in range(height):
        for x in range(width):
            if alpha[y * width + x] < model["ALPHA_THRESHOLD"]:
                continue
            require(margin <= x < width - margin and
                    margin <= y < height - margin,
                    "PRIVATE_PNG_CANVAS_CLIPPED")
            if 100 <= x + 0.5 < 212 and 100 <= y + 0.5 < 198:
                count_inside += 1
            else:
                count_outside += 1
    require(count_inside >= model["MIN_INTERIOR_PIXELS"],
            "PRIVATE_PNG_NO_INTERIOR_PAINT")
    return count_outside > 0


def private_run():
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    require(qs is not None and dbus is not None, "LOCAL_QT_DEPENDENCY_MISSING")
    frozen = runpy.run_path(str(
        ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="paint_canary_version_only")
    binary = "qs" if shutil.which("qs") else "quickshell"
    require(frozen["version_of"](binary, "--version") == "0.3.1",
            "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE")

    private = ROOT.parent / "canary"
    private.mkdir(mode=0o700)
    shell, xdg = stage_files(private)
    png = private / "actual-top-scale1.private.png"
    log = private / "capture.private.log"
    timeout = False
    with log.open("wb") as output:
        process = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            env=private_env(xdg, png), cwd=ROOT,
            stdin=subprocess.DEVNULL, stdout=output,
            stderr=subprocess.STDOUT, start_new_session=True,
            preexec_fn=child_resource_limit)
        try:
            try:
                code = process.wait(timeout=13)
            except subprocess.TimeoutExpired:
                timeout = True
                code = None
        finally:
            # The process group is new and private, never the host session.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=3)
            time.sleep(0.15)
            try:
                os.killpg(process.pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise Stop("PRIVATE_CHILD_GROUP_STILL_PRESENT")

    require(not timeout, "BOUNDED_PRIVATE_CAPTURE_TIMEOUT")
    require(log.stat().st_uid == os.getuid() and
            not stat.S_IMODE(log.stat().st_mode) & 0o077 and
            0 < log.stat().st_size <= MAX_LOG,
            "PRIVATE_LOG_MISSING_OR_OVERSIZED")
    stage, failures = stages_from_log(log.read_text(
        encoding="utf-8", errors="replace"))
    require(code == 0, "PRIVATE_QT_CHILD_NONZERO")
    require(not failures and stage == list(STAGES),
            "PRIVATE_CAPTURE_STAGE_INCONCLUSIVE")
    return verify_png(png)


def main():
    require(sys.argv[1:] == ["--acknowledge-private-one-case-capture"],
            "EXPLICIT_PRIVATE_CAPTURE_OPT_IN_REQUIRED")
    os.umask(0o077)
    source = audit_clone()
    outside = private_run()
    require(git("rev-parse", "HEAD") == source and
            not git("status", "--porcelain=v1", "--untracked-files=all"),
            "POSTRUN_SOURCE_IDENTITY_CHANGED")
    print("SOURCE_SHA=" + source)
    print("ACTUAL_UNMODIFIED_COMPANION=YES")
    print("STATIC_TOP_SCALE1_PNG=VALID")
    print("OUTSIDE_HOST_COMPOSITE_ALPHA=" + ("YES" if outside else "NO"))
    print("BODY_SPECIFIC_PAINT_OUTSIDE_HOST=UNPROVEN")
    print("DYNAMIC_WITNESS=NOT_RUN")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_OFFSCREEN_ONE_CASE_CAPTURE_VERIFIED")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, ValueError, TypeError, KeyError,
            subprocess.TimeoutExpired) as ex:
        allowed = {
            "UNTRUSTED_PRIVATE_CLONE", "PRIVATE_CLONE_MODE_INVALID",
            "DIRTY_OR_WRONG_BRANCH", "UNTRUSTED_REMOTE",
            "REMOTE_HEAD_CHANGED", "REVIEWED_SOURCE_CHANGED",
            "PRIVATE_DEPENDENCY_MISSING", "PRIVATE_STAGE_SEQUENCE_INVALID",
            "PRIVATE_FAILURE_UNRECOGNIZED",
            "PRIVATE_PNG_MISSING_OR_UNSAFE", "PRIVATE_PNG_DIMENSIONS_INVALID",
            "PRIVATE_PNG_CANVAS_CLIPPED", "PRIVATE_PNG_NO_INTERIOR_PAINT",
            "LOCAL_QT_DEPENDENCY_MISSING",
            "QUICKSHELL_VERSION_DIFFERS_FROM_REFERENCE",
            "PRIVATE_CHILD_GROUP_STILL_PRESENT",
            "BOUNDED_PRIVATE_CAPTURE_TIMEOUT", "PRIVATE_QT_CHILD_NONZERO",
            "PRIVATE_LOG_MISSING_OR_OVERSIZED",
            "PRIVATE_CAPTURE_STAGE_INCONCLUSIVE",
            "POSTRUN_SOURCE_IDENTITY_CHANGED", "GIT_VERIFICATION_FAILED",
            "EXPLICIT_PRIVATE_CAPTURE_OPT_IN_REQUIRED",
        }
        code = str(ex)
        print("GATE=" + (code if code in allowed else
                         "PRIVATE_CAPTURE_OR_PNG_UNAVAILABLE"))
        raise SystemExit(1)
