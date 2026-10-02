#!/usr/bin/env python3
"""Explicit, nonpublishing, private OFFSCREEN Quickshell boot controls.

Distinguish a common Quickshell boot failure from a Wull dynamic-fixture-only
failure. Launch only a tiny synthetic ShellRoot and the *previously qualified*
frozen Wull fixture; NEVER open Wayland/Niri, input devices or production UI.
Private raw logs stay in the owned scratch; stdout contains categories ONLY.
"""
import os
from pathlib import Path
import resource
import runpy
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
FROZEN_PATH = "scripts/wull-manual-offscreen-motion-geometry.py"
FROZEN_FIXTURE = "scripts/wull-fixtures/motion-geometry/shell.qml"
DYNAMIC_FIXTURE = "scripts/wull-fixtures/motion-envelope/shell.qml"
FROZEN_PIN = "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
FROZEN_FIXTURE_PIN = "11df91496a8bb9b18d79498e86d1f734d78dc574"
DYNAMIC_FIXTURE_PIN = "6e3b5402d32d263868c1ec688925adba0fd7250b"
EXPECTED_QS = "0.3.1"
FROZEN_MARKER = "WULL_OFFSCREEN_MOTION_GEOMETRY "
MINIMAL_MARKER = "WULL_PRIVATE_BOOT_CONTROL_OK"
MAX_LOG = 262144
MINIMAL_QML = """import QtQuick
import Quickshell
ShellRoot {
    Timer {
        interval: 650
        running: true
        repeat: false
        onTriggered: {
            console.log("WULL_PRIVATE_BOOT_CONTROL_OK")
            Qt.quit()
        }
    }
    Timer {
        interval: 4500
        running: true
        repeat: false
        onTriggered: Qt.quit()
    }
}
"""
TESTS = (
    ("MINIMAL_DYNAMIC_ENV", "minimal", True, MINIMAL_MARKER),
    ("FROZEN_DYNAMIC_ENV", "frozen", True, FROZEN_MARKER),
    ("FROZEN_HISTORICAL_ENV", "frozen", False, FROZEN_MARKER),
)
frozen = runpy.run_path(str(ROOT / FROZEN_PATH),
                        run_name="wull_boot_controls_reuse_reviewed_guards")


def stop(label):
    if label not in {
            "OPT_IN_REQUIRED", "DEPENDENCIES_MISSING", "QS_VERSION_CHANGED",
            "SOURCE_PIN_CHANGED", "NOT_CLEAN_AFTER_PROBE",
            "PROCESS_CLEANUP_UNVERIFIED", "PRIVATE_SETUP_FAILED"}:
        label = "PRIVATE_SETUP_FAILED"
    print("STOP=" + label, flush=True)
    raise SystemExit(1)


def owned_sources(commit):
    frozen["audit"](commit)
    pins = {FROZEN_PATH: FROZEN_PIN,
            FROZEN_FIXTURE: FROZEN_FIXTURE_PIN,
            DYNAMIC_FIXTURE: DYNAMIC_FIXTURE_PIN}
    for path, pin in pins.items():
        if frozen["git"]("rev-parse", commit + ":" + path) != pin:
            stop("SOURCE_PIN_CHANGED")


def private_shell(private, source):
    shell = private / "shell"
    shell.mkdir(mode=0o700)
    for name in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        link_target = ROOT / name
        if not link_target.exists():
            stop("PRIVATE_SETUP_FAILED")
        (shell / name).symlink_to(link_target)
    if source == "frozen":
        shutil.copyfile(ROOT / FROZEN_FIXTURE, shell / "shell.qml")
    elif source == "minimal":
        (shell / "shell.qml").write_text(MINIMAL_QML, encoding="utf-8")
    else:
        stop("PRIVATE_SETUP_FAILED")
    return shell / "shell.qml"


def classify_exit(code):
    if code is None:
        return "TIMEOUT"
    if code < 0:
        return "SIGNAL"
    if code > 0:
        return "NONZERO"
    return "ZERO"


def classify_log(log, marker):
    raw = log.read_text(encoding="utf-8", errors="replace")
    hits = sum(marker in line for line in raw.splitlines())
    if marker == FROZEN_MARKER:
        abort = ("WULL_OFFSCREEN_MOTION_INVALID" in raw
                 or "WULL_OFFSCREEN_MOTION_TIMEOUT" in raw)
    else:
        abort = False
    return ("ONE" if hits == 1 else
            "NONE" if hits == 0 else "MULTIPLE",
            "YES" if abort else "NO",
            "YES" if "Quickshell" in raw or "quickshell" in raw else "NO")


def run_control(work, entry, qs, dbus):
    label, source, scrub_import, marker = entry
    private = work / label.lower()
    private.mkdir(mode=0o700)
    config_path = private_shell(private, source)
    xdg = private / "xdg"
    for name in ("config", "data", "cache", "state"):
        (xdg / name).mkdir(parents=True, mode=0o700)
    config = xdg / "config" / "illogical-impulse"
    config.mkdir(mode=0o700)
    shutil.copyfile(ROOT / "defaults/config.json", config / "config.json")
    env = dict(os.environ)
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                "INIR_COMPANIOND", "WAYLAND_DISPLAY", "NIRI_SOCKET",
                "DISPLAY"):
        env.pop(key, None)
    if scrub_import:
        for key in ("QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
            env.pop(key, None)
    env.update({
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    log = private / "control.private.log"
    code = None
    cleaned = True

    def restrict_child_file_size():
        resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_LOG, MAX_LOG))

    with log.open("wb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(config_path)],
            env=env, cwd=ROOT, stdin=subprocess.DEVNULL,
            stdout=output, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=restrict_child_file_size)
        try:
            try:
                code = proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                code = None
        finally:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait(timeout=2)
            time.sleep(.20)
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                pass
            else:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                time.sleep(.10)
                try:
                    os.killpg(proc.pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    cleaned = False
    if not cleaned:
        stop("PROCESS_CLEANUP_UNVERIFIED")
    if not log.is_file() or not 0 < log.stat().st_size <= MAX_LOG:
        print("CONTROL_" + label + "=LOG_MISSING_OR_OVERSIZED", flush=True)
        return False
    hits, abort, qs_mention = classify_log(log, marker)
    result = "PASS" if code == 0 and hits == "ONE" and abort == "NO" else "INCONCLUSIVE"
    print("CONTROL_" + label + "=" + result, flush=True)
    print("CONTROL_" + label + "_EXIT=" + classify_exit(code), flush=True)
    print("CONTROL_" + label + "_MARKER=" + hits, flush=True)
    print("CONTROL_" + label + "_FIXTURE_ABORT=" + abort, flush=True)
    print("CONTROL_" + label + "_QS_MENTION=" + qs_mention, flush=True)
    return result == "PASS"


def main():
    if sys.argv[1:] != ["--acknowledge-private-boot-controls"]:
        stop("OPT_IN_REQUIRED")
    os.umask(0o077)
    state = Path(os.environ.get("XDG_STATE_HOME", "")).expanduser().resolve()
    frozen["guard"](state)
    source = frozen["git"]("rev-parse", "HEAD")
    owned_sources(source)
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    if not qs or not dbus:
        stop("DEPENDENCIES_MISSING")
    if frozen["version_of"]("qs" if shutil.which("qs") else "quickshell", "--version") != EXPECTED_QS:
        stop("QS_VERSION_CHANGED")
    work = ROOT.parent / "boot-controls"
    if work.exists():
        stop("PRIVATE_SETUP_FAILED")
    work.mkdir(mode=0o700)
    print("SOURCE_SHA=" + source, flush=True)
    print("CONTROL_SCOPE=PRIVATE_OFFSCREEN_NO_COMPOSITOR_NO_INPUT", flush=True)
    # Always run all three controls for meaningful isolation; never publish.
    results = [run_control(work, entry, qs, dbus) for entry in TESTS]
    if not frozen["clean"]() or frozen["git"]("rev-parse", "HEAD") != source:
        stop("NOT_CLEAN_AFTER_PROBE")
    print("CONTROL_VERDICT=" + (
        "ALL_CONTROLS_PASS" if all(results) else "STARTUP_ISOLATION_INCONCLUSIVE"),
        flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired):
        print("STOP=PRIVATE_SETUP_FAILED", flush=True)
        raise SystemExit(1)
