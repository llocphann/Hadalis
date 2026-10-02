#!/usr/bin/env python3
"""Read-only host-to-nested-Niri PREREQUISITE gate, NOT isolation approval.

Never connect to host Niri socket, spawn Niri, grab pixels, inject input,
read owner settings, access Git remotes, or print host paths or output IDs.
An affirmative result permits further reviewed fixture design ONLY.
"""
import os
from pathlib import Path
import re
import shutil
import stat
import sys

SAFE_DISPLAY = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")


def assess(which, env, runtime_ok, socket_check):
    if not (which("niri") and (which("qs") or which("quickshell"))
            and which("dbus-run-session")):
        return "BINARIES_UNAVAILABLE"
    display = env.get("WAYLAND_DISPLAY", "")
    ipc = env.get("NIRI_SOCKET", "")
    runtime = env.get("XDG_RUNTIME_DIR", "")
    if (not runtime_ok or not isinstance(display, str)
            or not SAFE_DISPLAY.fullmatch(display)
            or not isinstance(ipc, str) or not ipc.startswith("/")):
        return "OWNED_HOST_CONTEXT_UNAVAILABLE"
    root = Path(runtime)
    socket = Path(ipc)
    # Only an exact runtime-local parent is accepted; never follow a
    # malicious path into private material or any other user's directory.
    if socket.parent != root or socket.name in (".", ".."):
        return "HOST_SOCKET_SCOPE_UNQUALIFIED"
    if not socket_check(root / display) or not socket_check(socket):
        return "HOST_SOCKETS_UNAVAILABLE"
    return "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS"


def main():
    if sys.argv[1:] != ["--read-only-preflight"]:
        print("GATE=EXPLICIT_READ_ONLY_MODE_REQUIRED")
        return 1
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    runtime_ok = False
    if runtime.startswith("/"):
        path = Path(runtime)
        try:
            meta = path.lstat()
            runtime_ok = (
                stat.S_ISDIR(meta.st_mode)
                and not stat.S_ISLNK(meta.st_mode)
                and meta.st_uid == os.getuid()
                and not stat.S_IMODE(meta.st_mode) & 0o077
            )
        except OSError:
            pass
    def socket_check(path):
        try:
            st = path.lstat()
            return stat.S_ISSOCK(st.st_mode) and st.st_uid == os.getuid()
        except OSError:
            return False
    code = assess(shutil.which, os.environ, runtime_ok, socket_check)
    print("GATE=" + code)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
