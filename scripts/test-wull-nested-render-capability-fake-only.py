#!/usr/bin/env python3
"""No host sockets/Qt/Niri used: pure fake preflight branch coverage."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "scripts/wull-nested-render-capability.py").read_text()
for forbidden in ("subprocess.Popen", "subprocess.run", "niri msg",
                  "grabToImage", "grim ", "git push", "shell=True"):
    assert forbidden not in SOURCE, forbidden
assert "NOT_ISOLATION_PASS" in SOURCE
assert 'stat.S_ISSOCK(st.st_mode)' in SOURCE
mod = runpy.run_path(str(ROOT / "scripts/wull-nested-render-capability.py"),
                     run_name="fake_only_nested_capability")
assess = mod["assess"]
runtime = "/run/user/1234"
env = {"WAYLAND_DISPLAY": "wayland-55", "NIRI_SOCKET": runtime + "/niri.sock",
       "XDG_RUNTIME_DIR": runtime}
binaries = {"niri", "qs", "dbus-run-session"}
all_sockets = {runtime + "/wayland-55", runtime + "/niri.sock"}
which = lambda name: name if name in binaries else None
socket = lambda path: str(path) in all_sockets
assert assess(which, env, True, socket) == (
    "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS")
assert assess(lambda x: None, env, True, socket) == "BINARIES_UNAVAILABLE"
assert assess(which, env, False, socket) == "OWNED_HOST_CONTEXT_UNAVAILABLE"
assert assess(which, {**env, "WAYLAND_DISPLAY": "../unsafe"}, True,
              socket) == "OWNED_HOST_CONTEXT_UNAVAILABLE"
assert assess(which, {**env, "NIRI_SOCKET": "/tmp/other.sock"}, True,
              socket) == "HOST_SOCKET_SCOPE_UNQUALIFIED"
assert assess(which, env, True, lambda path: False) == (
    "HOST_SOCKETS_UNAVAILABLE")
print("WULL_NESTED_RENDER_PREFLIGHT_FAKE_ONLY_PASS")
