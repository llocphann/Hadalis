#!/usr/bin/env python3
"""Own offscreen Quickshell REAL-QML synthetic visual-matrix capture.

Never accesses host Wayland, Niri or desktop. Retains PNG and verbose Qt
output privately under XDG_STATE_HOME; Git worker publishes metadata only.
Passing alpha/pixel gates is NOT aesthetic or reference-image approval.
"""
import hashlib
import os
from pathlib import Path
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "scripts/wull-fixtures/visual-matrix/shell.qml"
MODEL = ROOT / "scripts/wull-private-painted-alpha-model.py"
ELEMENTS = ("modules", "services", "GlobalStates.qml", "qmldir",
            "assets", "scripts", "defaults", "translations")
STAGES = ("BOOT", "FOUR_HOSTS_FROZEN", "SYNTHETIC_SHEET_SAVED")
FAILURES = frozenset(("WINDOW_UNAVAILABLE", "HOST_GEOMETRY_INVALID",
                      "BODY_NOT_VISIBLE", "PRIVATE_PATH_UNSET",
                      "PRIVATE_SAVE_FAILED", "PRIVATE_GRAB_UNAVAILABLE",
                      "PRIVATE_QT_TIMEOUT"))
ROI = ((75, 80, 240, 235), (290, 80, 480, 235),
       (75, 310, 240, 485), (290, 310, 480, 485))


class NotQualified(Exception):
    pass


def need(condition, reason):
    if not condition:
        raise NotQualified(reason)


def source_sha():
    run = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                         capture_output=True, text=True, timeout=8)
    need(run.returncode == 0 and len(run.stdout.strip()) == 40,
         "SOURCE_UNVERIFIED")
    return run.stdout.strip()


def preflight():
    need(Path.cwd().resolve() == ROOT, "WORKSPACE_UNVERIFIED")
    need(FIXTURE.is_file() and MODEL.is_file()
         and all((ROOT / p).exists() for p in ELEMENTS),
         "SOURCE_UNAVAILABLE")
    tools = (shutil.which("qs") or shutil.which("quickshell"),
             shutil.which("dbus-run-session"))
    need(all(tools), "QT_DEPENDENCY_UNAVAILABLE")
    return tools


def staged(root):
    shell = root / "shell"
    shell.mkdir(mode=0o700)
    for name in ELEMENTS:
        (shell / name).symlink_to(ROOT / name)
    shutil.copyfile(FIXTURE, shell / "shell.qml")
    xdg = root / "xdg"
    for name in ("runtime", "config", "data", "cache", "state"):
        (xdg / name).mkdir(parents=True, mode=0o700)
    config = xdg / "config" / "illogical-impulse"
    config.mkdir(mode=0o700)
    shutil.copyfile(ROOT / "defaults/config.json", config / "config.json")
    return shell, xdg


def private_env(xdg, output):
    env = dict(os.environ)
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "NIRI_SOCKET",
                "QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                "INIR_COMPANIOND", "DBUS_SESSION_BUS_ADDRESS",
                "DBUS_SYSTEM_BUS_ADDRESS", "QML_IMPORT_PATH",
                "QML2_IMPORT_PATH", "WULL_CAPTURE_OUTPUT"):
        env.pop(key, None)
    env.update({"QT_QPA_PLATFORM": "offscreen",
                "XDG_RUNTIME_DIR": str(xdg / "runtime"),
                "XDG_CONFIG_HOME": str(xdg / "config"),
                "XDG_CACHE_HOME": str(xdg / "cache"),
                "XDG_DATA_HOME": str(xdg / "data"),
                "XDG_STATE_HOME": str(xdg / "state"),
                "WULL_VISUAL_MATRIX_PRIVATE_FILE": str(output),
                "QS_NO_RELOAD_POPUP": "1"})
    return env


def run_qt(private, executables):
    shell, xdg = staged(private)
    png, log = private / "four-pose.private.png", private / "qt.private.log"
    with log.open("xb") as stream:
        proc = subprocess.Popen(
            [executables[1], "--", executables[0],
             "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=private_env(xdg, png), stdin=subprocess.DEVNULL,
            stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            try:
                code = proc.wait(timeout=19)
            except subprocess.TimeoutExpired:
                code, timed_out = None, True
        finally:
            if proc.poll() is None:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=3)
    need(not timed_out and code == 0, "QT_RUN_UNQUALIFIED")
    info = log.lstat()
    need(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
         and not stat.S_IMODE(info.st_mode) & 0o077
         and 0 < info.st_size <= 128 * 1024,
         "PRIVATE_LOG_UNQUALIFIED")
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    stages, failures = [], []
    for line in lines:
        if "WULL_VISUAL_MATRIX_STAGE=" in line:
            stages.append(line.split("WULL_VISUAL_MATRIX_STAGE=", 1)[1].strip())
        if "WULL_VISUAL_MATRIX_FAIL=" in line:
            failures.append(line.split("WULL_VISUAL_MATRIX_FAIL=", 1)[1].strip())
    need(not failures and stages == list(STAGES), "QT_STAGE_UNQUALIFIED")
    return png


def classify(png):
    entry = png.lstat()
    need(stat.S_ISREG(entry.st_mode) and entry.st_uid == os.getuid()
         and not stat.S_IMODE(entry.st_mode) & 0o077
         and 0 < entry.st_size <= 1024 * 1024,
         "PRIVATE_PNG_UNQUALIFIED")
    raw = png.read_bytes()
    decode = runpy.run_path(str(MODEL), run_name="wull_matrix_png_safe_decoder")
    try:
        width, height, alpha = decode["png_alpha"](raw)
    except ValueError:
        raise NotQualified("PRIVATE_PNG_FORMAT_UNQUALIFIED")
    need((width, height) == (512, 512), "PRIVATE_PNG_DIMENSIONS_INVALID")
    for x0, y0, x1, y1 in ROI:
        count = sum(alpha[y * width + x] >= 24 for y in range(y0, y1)
                    for x in range(x0, x1))
        need(count >= 400, "PRIVATE_CELL_PAINT_UNQUALIFIED")
    return hashlib.sha256(raw).hexdigest()


def main():
    need(sys.argv[1:] in (["--preflight"], ["--capture"]),
         "EXPLICIT_MODE_REQUIRED")
    os.umask(0o077)
    sha = source_sha()
    executables = preflight()
    if sys.argv[1:] == ["--preflight"]:
        print("WULL_VISUAL_MATRIX_PREFLIGHT_PASS")
        return
    state = Path(os.environ.get("XDG_STATE_HOME",
                 str(Path.home() / ".local/state"))).expanduser().resolve()
    owned = state / "hadalis-wull-visual-private"
    owned.mkdir(mode=0o700, parents=True, exist_ok=True)
    need(owned.stat().st_uid == os.getuid()
         and not stat.S_IMODE(owned.stat().st_mode) & 0o077,
         "PRIVATE_STATE_UNSAFE")
    private = Path(tempfile.mkdtemp(prefix="matrix-" + sha[:12] + "-",
                                    dir=owned))
    # A successful run intentionally retains ONE privately owned image/log.
    try:
        digest = classify(run_qt(private, executables))
        need(source_sha() == sha, "SOURCE_CHANGED_DURING_CAPTURE")
    except Exception:
        shutil.rmtree(private, ignore_errors=True)
        raise
    print("SOURCE_SHA=" + sha)
    print("SYNTHETIC_REAL_QML_CONTACT_SHEET=PRIVATE_VALIDATED")
    print("SHEET_SHA256=" + digest)
    print("FOUR_ALPHA_CELL_WITNESSES=YES")
    print("REFERENCE_SIMILARITY=UNREVIEWED")
    print("REAL_PANEL_OR_POINTER=NOT_TESTED")
    print("GATE=SYNTHETIC_QML_MATRIX_PRIVATE_READY")


if __name__ == "__main__":
    try:
        main()
    except (NotQualified, OSError, subprocess.TimeoutExpired,
            ValueError) as error:
        allowed = {"EXPLICIT_MODE_REQUIRED", "SOURCE_UNVERIFIED",
                   "WORKSPACE_UNVERIFIED", "SOURCE_UNAVAILABLE",
                   "QT_DEPENDENCY_UNAVAILABLE", "QT_RUN_UNQUALIFIED",
                   "PRIVATE_LOG_UNQUALIFIED", "QT_STAGE_UNQUALIFIED",
                   "PRIVATE_PNG_UNQUALIFIED", "PRIVATE_PNG_FORMAT_UNQUALIFIED",
                   "PRIVATE_PNG_DIMENSIONS_INVALID",
                   "PRIVATE_CELL_PAINT_UNQUALIFIED", "PRIVATE_STATE_UNSAFE",
                   "SOURCE_CHANGED_DURING_CAPTURE"}
        label = str(error)
        print("GATE=" + (label if label in allowed else "MATRIX_UNQUALIFIED"))
        raise SystemExit(1)
