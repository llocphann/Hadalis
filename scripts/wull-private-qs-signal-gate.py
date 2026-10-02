#!/usr/bin/env python3
"""Explicit private one-fixture QS signal attribution; optional SIGXFSZ control.

Identical synthetic minimal QML and offscreen/verbose/plugin-debug launch
as the prior owner-run probe. No Wull runtime, compositor, pointer, repo
mutation, receipt or production change. Output only fixed categorical fields.
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

ROOT = Path(__file__).resolve().parents[1]
FROZEN = "scripts/wull-manual-offscreen-motion-geometry.py"
FROZEN_PIN = "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
OLD = "scripts/wull-private-minimal-qs-bootstrap.py"
OLD_PIN = "edd28683dc1ce679f24aa460e914cfad5abdc0a6"
LOW_LIMIT = 524288
HIGH_LIMIT = 8388608
QS_VERSION = "0.3.1"
SIGNALS = ("SIGABRT", "SIGSEGV", "SIGBUS", "SIGILL", "SIGTRAP",
           "SIGXFSZ", "SIGTERM", "SIGKILL", "SIGSYS", "SIGPIPE",
           "SIGINT", "SIGQUIT", "OTHER", "NONE")
STATES = ("ZERO", "NONZERO", "SIGNAL", "TIMEOUT", "OSERROR")


def stop(reason):
    if reason not in {
        "OPT_IN_REQUIRED", "SOURCE_CHANGED", "GUARD_FAILED",
        "DEPENDENCY_MISSING", "QS_VERSION_CHANGED",
        "PRIVATE_SETUP_FAILED", "CHILD_CLEANUP_UNVERIFIED",
        "PRIVATE_CLONE_DIRTY", "NO_EXACT_CHILD_RECEIPT"}:
        reason = "GUARD_FAILED"
    print("STOP=" + reason, flush=True)
    raise SystemExit(1)


def classify_return(code):
    """Exact signal name, without a stack trace, Qt log or raw value."""
    if code is None:
        return "TIMEOUT", "NONE"
    if code == 0:
        return "ZERO", "NONE"
    if code > 0:
        return "NONZERO", "NONE"
    try:
        name = signal.Signals(-code).name
    except ValueError:
        name = "OTHER"
    return "SIGNAL", name if name in SIGNALS else "OTHER"


def receipt_read(file):
    if not file.is_file() or file.is_symlink() or file.stat().st_uid != os.getuid():
        return None
    raw = file.read_text(encoding="ascii")
    match = re.fullmatch(
        r"STATE=(ZERO|NONZERO|SIGNAL|TIMEOUT|OSERROR)\n"
        r"QS_SIGNAL=(SIGABRT|SIGSEGV|SIGBUS|SIGILL|SIGTRAP|SIGXFSZ|SIGTERM|SIGKILL|SIGSYS|SIGPIPE|SIGINT|SIGQUIT|OTHER|NONE)\n",
        raw)
    if not match:
        return None
    state, sig = match.groups()
    if (state == "SIGNAL") != (sig != "NONE"):
        return None
    return state, sig


def child_main(argv):
    if len(argv) != 3 or os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        raise SystemExit(3)
    qs, shell, receipt = argv
    try:
        cp = subprocess.run(
            [qs, "--verbose", "--path", shell],
            stdin=subprocess.DEVNULL, timeout=7)
        state, sig = classify_return(cp.returncode)
    except subprocess.TimeoutExpired:
        state, sig = "TIMEOUT", "NONE"
    except OSError:
        state, sig = "OSERROR", "NONE"
    Path(receipt).write_text(
        "STATE=" + state + "\nQS_SIGNAL=" + sig + "\n",
        encoding="ascii")
    raise SystemExit(0 if state == "ZERO" else 1)


def private_limit(max_bytes):
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (max_bytes, max_bytes))


def launch(work, label, limit, qs, dbus, qml, cleanup):
    folder = work / label
    folder.mkdir(mode=0o700)
    shell = folder / "shell"
    shell.mkdir(mode=0o700)
    (shell / "shell.qml").write_text(qml, encoding="utf-8")
    xdg = folder / "xdg"
    for name in ("config", "data", "cache", "state"):
        (xdg / name).mkdir(mode=0o700, parents=True)
    env = dict(os.environ)
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                "WAYLAND_DISPLAY", "NIRI_SOCKET", "DISPLAY",
                "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        env.pop(key, None)
    env.update({
        "QT_QPA_PLATFORM": "offscreen",
        "QT_DEBUG_PLUGINS": "1",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    receipt = folder / "child-receipt.private.txt"
    log = folder / "qt.private.log"
    argv = [dbus, "--", sys.executable, str(ROOT / "scripts" /
            "wull-private-qs-signal-gate.py"), "--child", qs,
            str(shell / "shell.qml"), str(receipt)]
    wrapper = None
    with log.open("wb") as out:
        proc = subprocess.Popen(
            argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
            preexec_fn=lambda: private_limit(limit))
        try:
            try:
                wrapper = proc.wait(timeout=11)
            except subprocess.TimeoutExpired:
                wrapper = None
        finally:
            cleaned = cleanup(proc.pid)
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
                stop("CHILD_CLEANUP_UNVERIFIED")
    exact = receipt_read(receipt)
    if not exact:
        stop("NO_EXACT_CHILD_RECEIPT")
    state, sig = exact
    print(label.upper() + "_WRAPPER=" +
          ("ZERO" if wrapper == 0 else "NONZERO" if wrapper is not None else "TIMEOUT"),
          flush=True)
    print(label.upper() + "_QS_STATE=" + state, flush=True)
    print(label.upper() + "_QS_SIGNAL=" + sig, flush=True)
    print(label.upper() + "_QML_MARKER=" +
          ("ONE" if log.is_file() and
           log.stat().st_size <= limit and
           log.read_bytes().count(b"WULL_MINIMAL_QML_COMPONENT_LOADED") == 1
           else "NONE_OR_UNVERIFIED"), flush=True)
    print(label.upper() + "_LOG_AT_LIMIT=" +
          ("YES" if log.is_file() and log.stat().st_size >= limit - 4096
           else "NO"), flush=True)
    return state, sig


def main():
    if sys.argv[1:] != ["--acknowledge-private-qs-signal"]:
        stop("OPT_IN_REQUIRED")
    os.umask(0o077)
    borrowed = runpy.run_path(
        str(ROOT / FROZEN), run_name="wull_qs_signal_reviewed_guard")
    previous = runpy.run_path(
        str(ROOT / OLD), run_name="wull_qs_signal_original_fixture")
    statevar = os.environ.get("XDG_STATE_HOME")
    if not statevar:
        stop("GUARD_FAILED")
    state = Path(statevar).expanduser().resolve()
    borrowed["guard"](state)
    source = borrowed["git"]("rev-parse", "HEAD")
    for path, pin in ((FROZEN, FROZEN_PIN), (OLD, OLD_PIN)):
        if borrowed["git"]("rev-parse", source + ":" + path) != pin:
            stop("SOURCE_CHANGED")
    borrowed["audit"](source)
    if (previous["MAX_LOG"] != LOW_LIMIT or
            previous["QML"].count("WULL_MINIMAL_QML_COMPONENT_LOADED") != 1):
        stop("SOURCE_CHANGED")
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    if not qs or not dbus:
        stop("DEPENDENCY_MISSING")
    version = borrowed["version_of"](
        "qs" if shutil.which("qs") else "quickshell", "--version")
    if version != QS_VERSION:
        stop("QS_VERSION_CHANGED")
    work = ROOT.parent / "private-qs-signal"
    if work.exists():
        stop("PRIVATE_SETUP_FAILED")
    work.mkdir(mode=0o700)
    print("SOURCE_SHA=" + source, flush=True)
    print("SCOPE=PRIVATE_MINIMAL_OFFSCREEN_NO_COMPOSITOR", flush=True)
    outcome = launch(work, "baseline", LOW_LIMIT, qs, dbus,
                     previous["QML"], previous["owned_cleanup"])
    # Second launch ONLY if this exact process hit the file-size signal:
    # checks one tested and bounded alternative without speculative sweeps.
    if outcome == ("SIGNAL", "SIGXFSZ"):
        print("CONDITIONAL_CONTROL=RAISED_FILE_LIMIT", flush=True)
        launch(work, "raised_limit", HIGH_LIMIT, qs, dbus,
               previous["QML"], previous["owned_cleanup"])
    else:
        print("CONDITIONAL_CONTROL=NOT_TRIGGERED", flush=True)
    if (borrowed["git"]("rev-parse", "HEAD") != source or
            not borrowed["clean"]()):
        stop("PRIVATE_CLONE_DIRTY")
    print("GATE=PRIVATE_EXACT_QS_SIGNAL_OBSERVED", flush=True)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--child"]:
        child_main(sys.argv[2:])
    else:
        try:
            main()
        except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired):
            stop("GUARD_FAILED")
