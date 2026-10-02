#!/usr/bin/env python3
"""Inert scope/parser tests: never run Niri, access host IPC, or take images."""
import ast
import json
from pathlib import Path
import runpy
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "scripts/wull-nested-isolation-smoke.py"
source = PATH.read_text(encoding="utf-8")
ast.parse(source)
for forbidden in (
    "grabToImage", "saveToFile(", "grim ", "git push", "subprocess.Popen("
    "[\"qs\"", "wlrctl", "wdotool", "shell_deploy", "chmod 777"):
    assert forbidden not in source, forbidden
for required in (
    "start_new_session=True", "os.killpg(proc.pid, signal.SIGTERM)",
    "proc.poll() is not None", "TemporaryDirectory(",
    'NIRI_CONFIG": str(config)', "nested_display != display",
    "nested_ipc != host_ipc", "after != pre",
    "NESTED_SOCKET_UNQUALIFIED", "NESTED_CLEANUP_UNQUALIFIED",
    "HOST_INVENTORY_CHANGED", "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS",
):
    assert required in source, required

m = runpy.run_path(str(PATH), run_name="fake_only_nested_safety")
parse = m["startup_ids"]
assert parse("unrelated logs") is None
assert parse("listening on Wayland socket: wayland-77\n"
             "IPC listening on: /run/user/55/niri.test.sock\n") == (
                 "wayland-77", "/run/user/55/niri.test.sock")
assert parse("other stuff" * 20000) is None
outputs = m["outputs"]
layers = m["layers"]
assert outputs(json.dumps({"Ok": {"Outputs": {
    "A": {"logical": {"x": 0}}, "B": {"logical": None}}}})) == 1
assert outputs(json.dumps({"Outputs": {}})) == 0
assert outputs('{"Outputs": []}') is None
assert outputs("not json") is None
assert layers(json.dumps({"Ok": {"Layers": []}}))
assert not layers(json.dumps({"Ok": {"Layers": {}}}))
assert not layers("not json")
with mock.patch.object(m["os"], "killpg") as signal_fn:
    class Exited:
        pid = 42
        def poll(self): return 0
    assert m["stop_owned"](Exited())
    signal_fn.assert_not_called()
print("WULL_NESTED_ISOLATION_SMOKE_FAKE_ONLY_PASS")
