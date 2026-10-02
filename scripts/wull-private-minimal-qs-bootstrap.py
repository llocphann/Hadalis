#!/usr/bin/env python3
"""Explicit NON-PUBLISHING private Quickshell-only offscreen boot isolation.

Three synthetic minimal configurations: offscreen FILE, offscreen DIRECTORY,
and Qt minimal FILE. Every child has a separate private D-Bus session, private
XDG directories, no compositor/display socket, bounded process group and log.
Only fixed diagnostic categories are printed; raw output remains private.
Does not load Wull code, access pointer devices, edit user config or push.
"""
import os
from pathlib import Path
import re
import resource
import runpy
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
FROZEN = "scripts/wull-manual-offscreen-motion-geometry.py"
FROZEN_PIN = "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
QS_VERSION = "0.3.1"
QML_MARKER = "WULL_MINIMAL_QML_COMPONENT_LOADED"
CHILD_MARKER = "WULL_MINIMAL_CHILD_EXIT="
MAX_LOG = 524288
PROBES = (
    ("OFFSCREEN_FILE", "offscreen", "file"),
    ("OFFSCREEN_DIRECTORY", "offscreen", "directory"),
    ("MINIMAL_FILE", "minimal", "file"),
)
QML = """import QtQuick
import Quickshell
ShellRoot {
    Component.onCompleted: console.log("WULL_MINIMAL_QML_COMPONENT_LOADED")
    Timer {
        interval: 450
        running: true
        repeat: false
        onTriggered: Qt.quit()
    }
    Timer {
        interval: 4500
        running: true
        repeat: false
        onTriggered: Qt.quit()
    }
}
"""
# These are FIXED per-line categories, never excerpts from user-local logs.
ERROR_PATTERNS = (
    ("QT_PLATFORM_OR_PLUGIN", r"platform plugin|qt[.]qpa|qt[.]core[.]plugin|could not load.*plugin"),
    ("DYNAMIC_LINK_OR_LIBRARY", r"shared librar|undefined symbol|symbol lookup|cannot load library"),
    ("QML_IMPORT_OR_LOAD", r"failed to load configuration|not installed|could not load|failed to instantiate|referenceerror|syntaxerror|typeerror"),
    ("CONFIG_OR_PATH", r"config.*(?:missing|not found|unrecognized)|not a directory|no such file|permission denied"),
    ("SESSION_BUS", r"dbus|d-bus|session bus"),
    ("ABORT_OR_SIGNAL", r"segmentation|assert|fatal|aborted|signal|crash"),
    ("GENERAL_ERROR", r"\berror\b|\bfailed\b"),
    ("WARNING", r"\bwarn(?:ing)?\b"),
)


def stop(reason):
    if reason not in {
            "OPT_IN_REQUIRED", "GUARD_FAILED", "SOURCE_CHANGED",
            "MISSING_DEPENDENCY", "QS_VERSION_CHANGED",
            "CLI_HELP_UNQUALIFIED", "SCRATCH_ALREADY_PRESENT",
            "PRIVATE_CHILD_CLEANUP_FAILED", "PRIVATE_CLONE_DIRTY"}:
        reason = "GUARD_FAILED"
    print("STOP=" + reason, flush=True)
    raise SystemExit(1)


def categorized_log(raw):
    if type(raw) is not str or len(raw) > MAX_LOG:
        raise ValueError("invalid_private_debug_log")
    observed = []
    for label, pattern in ERROR_PATTERNS:
        if re.search(pattern, raw, re.IGNORECASE):
            observed.append(label)
    return observed or ["NO_RECOGNIZED_ERROR"]


def child_exit_status(code):
    if code is None:
        return "TIMEOUT"
    if code < 0:
        return "SIGNAL"
    if code > 0:
        return "NONZERO"
    return "ZERO"


def interpret_log(raw):
    # All printed values belong to a closed categorical vocabulary.
    loaded = sum(QML_MARKER in line for line in raw.splitlines())
    child = re.findall(r"(?m)^" + re.escape(CHILD_MARKER)
                       + r"(ZERO|NONZERO|SIGNAL|TIMEOUT)$", raw)
    return {
        "QML_MARKER": "ONE" if loaded == 1 else
                      "NONE" if loaded == 0 else "MULTIPLE",
        "QS_CHILD_EXIT": child[0] if len(child) == 1 else "UNKNOWN",
        "ERROR_CLASSES": ",".join(categorized_log(raw)),
    }


def owned_cleanup(pid):
    try:
        os.killpg(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    # Delay to permit private group exit; proc.wait() is handled by caller.
    time.sleep(.20)
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return True
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    time.sleep(.12)
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return True
    return False


def child_main(argv):
    # Entered solely as a child within the new dbus-run-session; never called
    # from the maintainer's top-level session.
    if len(argv) != 2:
        raise SystemExit(3)
    qs, path = argv
    try:
        cp = subprocess.run(
            [qs, "--verbose", "--path", path],
            stdin=subprocess.DEVNULL, timeout=7)
        state = child_exit_status(cp.returncode)
    except subprocess.TimeoutExpired:
        state = "TIMEOUT"
    except OSError:
        state = "NONZERO"
    print(CHILD_MARKER + state, flush=True)
    if state != "ZERO":
        raise SystemExit(1)


def run_probe(work, label, qpa, method, qs, dbus):
    folder = work / label.lower()
    folder.mkdir(mode=0o700)
    shell = folder / "shell"
    shell.mkdir(mode=0o700)
    (shell / "shell.qml").write_text(QML, encoding="utf-8")
    xdg = folder / "xdg"
    for kind in ("config", "data", "cache", "state"):
        (xdg / kind).mkdir(mode=0o700, parents=True)
    env = dict(os.environ)
    for name in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                 "WAYLAND_DISPLAY", "NIRI_SOCKET", "DISPLAY",
                 "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        env.pop(name, None)
    env.update({
        "QT_QPA_PLATFORM": qpa,
        "QT_DEBUG_PLUGINS": "1",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    log = folder / "minimal.private.log"
    # Child must be the only actual Quickshell starter and reports the *QS*
    # return class, independently of dbus-run-session wrapper's return code.
    child_argv = [dbus, "--", sys.executable, str(ROOT / "scripts" /
                  "wull-private-minimal-qs-bootstrap.py"), "--child", qs,
                  str(shell / "shell.qml" if method == "file" else shell)]
    code = None
    def private_file_limit():
        resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_LOG, MAX_LOG))
    with log.open("wb") as out:
        proc = subprocess.Popen(
            child_argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
            preexec_fn=private_file_limit)
        try:
            try:
                code = proc.wait(timeout=11)
            except subprocess.TimeoutExpired:
                code = None
        finally:
            cleaned = owned_cleanup(proc.pid)
            if proc.poll() is None:
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    proc.wait(timeout=2)
            if not cleaned:
                stop("PRIVATE_CHILD_CLEANUP_FAILED")
    if not log.is_file() or not 0 < log.stat().st_size <= MAX_LOG:
        print(label + "_LOG=UNAVAILABLE", flush=True)
        return
    observed = interpret_log(log.read_text(encoding="utf-8", errors="replace"))
    print(label + "_WRAPPER=" + child_exit_status(code), flush=True)
    for key, val in observed.items():
        print(label + "_" + key + "=" + val, flush=True)


def main():
    if sys.argv[1:] != ["--acknowledge-private-minimal-bootstrap"]:
        stop("OPT_IN_REQUIRED")
    os.umask(0o077)
    borrowed = runpy.run_path(str(ROOT / FROZEN),
                              run_name="wull_minimal_boot_reviewed_guards")
    state_raw = os.environ.get("XDG_STATE_HOME")
    if not state_raw:
        stop("GUARD_FAILED")
    state = Path(state_raw).expanduser().resolve()
    borrowed["guard"](state)
    source = borrowed["git"]("rev-parse", "HEAD")
    if borrowed["git"]("rev-parse", source + ":" + FROZEN) != FROZEN_PIN:
        stop("SOURCE_CHANGED")
    borrowed["audit"](source)
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    if not qs or not dbus:
        stop("MISSING_DEPENDENCY")
    if borrowed["version_of"](
            "qs" if shutil.which("qs") else "quickshell",
            "--version") != QS_VERSION:
        stop("QS_VERSION_CHANGED")
    helpcheck = subprocess.run(
        [qs, "--help"], capture_output=True, text=True, timeout=5)
    if (helpcheck.returncode != 0 or
            "--verbose" not in helpcheck.stdout + helpcheck.stderr or
            "--path" not in helpcheck.stdout + helpcheck.stderr):
        stop("CLI_HELP_UNQUALIFIED")
    work = ROOT.parent / "minimal-qs-bootstrap"
    if work.exists():
        stop("SCRATCH_ALREADY_PRESENT")
    work.mkdir(mode=0o700)
    print("SOURCE_SHA=" + source, flush=True)
    print("SCOPE=PRIVATE_MINIMAL_QML_NO_WULL_NO_COMPOSITOR", flush=True)
    for args in PROBES:
        run_probe(work, *args, qs, dbus)
    if borrowed["git"]("rev-parse", "HEAD") != source or not borrowed["clean"]():
        stop("PRIVATE_CLONE_DIRTY")
    print("GATE=PRIVATE_MINIMAL_QS_BOOTSTRAP_CLASSIFIED", flush=True)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--child"]:
        child_main(sys.argv[2:])
    else:
        try:
            main()
        except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired):
            stop("GUARD_FAILED")
