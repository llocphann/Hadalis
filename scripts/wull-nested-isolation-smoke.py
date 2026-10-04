#!/usr/bin/env python3
"""Bounded owned Niri-in-Niri ISOLATION smoke; never start Wull or capture.

The only host interaction is the pre- and post-check of Niri output state.
The only mutable resources are one short-lived owned nested Niri process
and its 0700/0600 temp files. All log JSON and socket names remain private.
Exit 0 is NOT real shader, screenshot, input, or design acceptance.
"""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from importlib.machinery import SourceFileLoader

CAPABILITY = SourceFileLoader(
    "wull_nested_capability",
    str(ROOT / "scripts/wull-nested-render-capability.py")).load_module()
MAX_CAPTURE = 128 * 1024
WAYLAND = re.compile(r"(?m)listening on Wayland socket:\s*(wayland-[0-9]+)")
IPC = re.compile(r"(?m)IPC listening on:\s*(/\S+?\.sock)(?:\s|$)")
GOOD = "NESTED_SOCKET_DISTINCT_HOST_INVARIANT_CLEAN"
CODES = frozenset((
    "EXPLICIT_MODE_REQUIRED", "PRECONDITIONS_UNAVAILABLE",
    "HOST_INVENTORY_UNAVAILABLE", "NESTED_LAUNCH_UNAVAILABLE",
    "NESTED_SOCKET_UNQUALIFIED", "NESTED_OUTPUT_UNQUALIFIED",
    "NESTED_LAYERS_UNQUALIFIED", "HOST_INVENTORY_CHANGED",
    "NESTED_CLEANUP_UNQUALIFIED", "ISOLATION_INCONCLUSIVE",
    GOOD,
))


class Unqualified(Exception):
    pass


def require(ok, reason):
    if not ok:
        raise Unqualified(reason)


def startup_ids(text):
    if type(text) is not str or len(text) > MAX_CAPTURE:
        return None
    a, b = WAYLAND.findall(text), IPC.findall(text)
    return (a[-1], b[-1]) if a and b else None


def unpack_niri(text, key):
    if not isinstance(text, str) or len(text) > MAX_CAPTURE:
        return None
    try:
        o = json.loads(text)
        if isinstance(o, dict) and "Ok" in o:
            o = o["Ok"]
        if isinstance(o, dict) and key in o:
            o = o[key]
        return o
    except (ValueError, TypeError):
        return None


def outputs(text):
    o = unpack_niri(text, "Outputs")
    if not isinstance(o, dict) or len(o) > 32:
        return None
    return sum(isinstance(v, dict) and v.get("logical") is not None
               for v in o.values())


def layers(text):
    o = unpack_niri(text, "Layers")
    if isinstance(o, dict):
        o = o.get("layers")
    return isinstance(o, list)


def command(argv, environment, timeout=4):
    # Never print raw IPC responses. The nested subprocess has a private log.
    run = subprocess.run(argv, env=environment, cwd=ROOT, timeout=timeout,
                         stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, check=False)
    if run.returncode or len(run.stdout) > MAX_CAPTURE:
        return None
    return run.stdout.decode("utf-8", errors="replace")


def stop_owned(proc):
    if proc is None:
        return True
    # Never signal a process group after its leader exited: its PID could
    # have been reused by an unrelated process.
    if proc.poll() is not None:
        return True
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return True
    try:
        proc.wait(timeout=4)
        return True
    except subprocess.TimeoutExpired:
        if proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                return True
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            return False
    return proc.poll() is not None


def socket_owned(path, runtime):
    try:
        p = Path(path)
        m = p.lstat()
        return p.parent == runtime and stat.S_ISSOCK(m.st_mode) \
            and m.st_uid == os.getuid() and not stat.S_ISLNK(m.st_mode)
    except OSError:
        return False


def smoke():
    os.umask(0o077)
    niri = shutil.which("niri")
    require(niri is not None, "PRECONDITIONS_UNAVAILABLE")
    env = os.environ.copy()
    display, host_ipc = env.get("WAYLAND_DISPLAY", ""), env.get("NIRI_SOCKET", "")
    runtime_text = env.get("XDG_RUNTIME_DIR", "")
    require(runtime_text.startswith("/"), "PRECONDITIONS_UNAVAILABLE")
    runtime = Path(runtime_text)
    metadata = runtime.lstat()
    require(stat.S_ISDIR(metadata.st_mode) and metadata.st_uid == os.getuid()
            and not stat.S_IMODE(metadata.st_mode) & 0o077,
            "PRECONDITIONS_UNAVAILABLE")
    require(CAPABILITY.assess(shutil.which, env, True,
                             lambda p: socket_owned(p, runtime))
            == "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS",
            "PRECONDITIONS_UNAVAILABLE")
    # Snapshot complete original stdout bytes in memory; no host identity,
    # filename, display name or output detail escapes into Git/worker logs.
    pre = command([niri, "msg", "-j", "outputs"],
                  dict(env, NIRI_SOCKET=host_ipc))
    require(pre is not None and outputs(pre) is not None,
            "HOST_INVENTORY_UNAVAILABLE")
    private_root = runtime / "hadalis-wull-isolation"
    private_root.mkdir(mode=0o700, exist_ok=True)
    root_meta = private_root.lstat()
    require(stat.S_ISDIR(root_meta.st_mode)
            and root_meta.st_uid == os.getuid()
            and not stat.S_IMODE(root_meta.st_mode) & 0o077,
            "PRECONDITIONS_UNAVAILABLE")
    proc = None
    result = "ISOLATION_INCONCLUSIVE"
    cleaned = False
    try:
        with tempfile.TemporaryDirectory(
                prefix="wull-nested-", dir=private_root) as name:
            directory = Path(name)
            paths = {}
            for part in ("config", "data", "cache", "state"):
                paths[part] = directory / part
                paths[part].mkdir(mode=0o700)
            config, logfile = directory / "nested.kdl", directory / "nested.private.log"
            config.write_text(
                'layout {\n    background-color "#000000"\n}\n'
                'overview {\n    backdrop-color "#000000"\n}\n',
                encoding="utf-8")
            nested_env = env.copy()
            nested_env.pop("NIRI_SOCKET", None)
            nested_env.update({
                "NIRI_CONFIG": str(config),
                "WAYLAND_DISPLAY": display,
                **{"XDG_" + key.upper() + "_HOME": str(value)
                   for key, value in paths.items()},
            })
            with logfile.open("xb") as log:
                proc = subprocess.Popen([niri], env=nested_env, cwd=ROOT,
                                        stdin=subprocess.DEVNULL,
                                        stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True)
            deadline = time.monotonic() + 14
            nested = None
            while time.monotonic() < deadline:
                if proc.poll() is not None:
                    result = "NESTED_LAUNCH_UNAVAILABLE"
                    break
                meta = logfile.lstat()
                require(stat.S_ISREG(meta.st_mode)
                        and meta.st_uid == os.getuid()
                        and not stat.S_IMODE(meta.st_mode) & 0o077
                        and meta.st_size <= MAX_CAPTURE,
                        "NESTED_LAUNCH_UNAVAILABLE")
                identity = startup_ids(logfile.read_text(
                    encoding="utf-8", errors="replace"))
                if identity is not None:
                    nested_display, nested_ipc = identity
                    if (nested_display != display and nested_ipc != host_ipc
                            and socket_owned(nested_ipc, runtime)
                            and socket_owned(runtime / nested_display, runtime)):
                        check_env = dict(env, NIRI_SOCKET=nested_ipc,
                                         WAYLAND_DISPLAY=nested_display)
                        current = command([niri, "msg", "-j", "outputs"],
                                          check_env)
                        if current is not None and outputs(current) == 1:
                            layer_json = command([niri, "msg", "-j", "layers"],
                                                 check_env)
                            if layer_json is not None and layers(layer_json):
                                nested = True
                                result = GOOD
                                break
                            result = "NESTED_LAYERS_UNQUALIFIED"
                        else:
                            result = "NESTED_OUTPUT_UNQUALIFIED"
                    else:
                        result = "NESTED_SOCKET_UNQUALIFIED"
                time.sleep(0.35)
            if not nested and result == "ISOLATION_INCONCLUSIVE":
                result = "NESTED_LAUNCH_UNAVAILABLE"
            cleaned = stop_owned(proc)
            proc = None if cleaned else proc
    finally:
        # Never leave the owned compositor running, including when a bounded
        # IPC operation or private-log assertion fails.
        if proc is not None:
            cleaned = stop_owned(proc)
        after = command([niri, "msg", "-j", "outputs"],
                        dict(env, NIRI_SOCKET=host_ipc))
        if after is None or after != pre:
            result = "HOST_INVENTORY_CHANGED"
        elif not cleaned:
            result = "NESTED_CLEANUP_UNQUALIFIED"
    return result


def main():
    if sys.argv[1:] != ["--isolation-only"]:
        print("GATE=EXPLICIT_MODE_REQUIRED")
        return 1
    try:
        outcome = smoke()
    except (OSError, ValueError, subprocess.TimeoutExpired, Unqualified) as exc:
        outcome = str(exc) if isinstance(exc, Unqualified) \
            and str(exc) in CODES else "ISOLATION_INCONCLUSIVE"
    print("GATE=" + outcome)
    return 0 if outcome == GOOD else 1


if __name__ == "__main__":
    raise SystemExit(main())
