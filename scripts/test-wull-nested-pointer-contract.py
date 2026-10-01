#!/usr/bin/env python3
"""INERT safety/geometry/parser tests for nested REAL Wull pointer probe.

No compositor is spawned, no input is injected, no repo/report is changed.
"""
import ast
import json
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
parent_text = (ROOT / "scripts/wull-manual-nested-pointer.py").read_text()
child_text = (ROOT / "scripts/wull-manual-pointer-child.py").read_text()
relay_text = (ROOT / "scripts/wull-fixtures/pointer-underlay/companion-relay.py").read_text()
for source in (parent_text, child_text, relay_text):
    ast.parse(source)

for marker in (
    'sys.argv[1:] != ["--acknowledge-nested-pointer"]',
    "BASE = ",
    "REVIEWED = ",
    'git("merge", "--ff-only", remote)',
    "if origin not in SAFE_REMOTES",
    'Path(runtime) / desktop',
    'candidate.parent != runtime',
    'candidate_display != host_display',
    'candidate_ipc != host_ipc',
    "native_layers(niri, ipc)",
    'WULL_PRIVATE_POINTER_CHILD": "owned-nested"',
    'WULL_PRIVATE_POINTER_ROOT": str(private / "child")',
    "stop_owned(nested)",
    "stop_private_strays(child_dir, force=True)",
    "private_strays(private / \"child\")",
    'git("rebase", "--onto", remote, parent)',
    '"production_mask_changed": False',
    '"raw_coordinates_screenshots_logs": "private_local_only"',
):
    assert marker in parent_text, marker
for marker in (
    'sys.argv[1:] != ["--nested-child"]',
    'env.get("WULL_PRIVATE_POINTER_CHILD") != "owned-nested"',
    'nested != env.get("WULL_PRIVATE_POINTER_NESTED_SOCKET")',
    'nested_path.parent != runtime',
    'outputs[0][1].get("x") != 0',
    'outputs[0][1].get("y") != 0',
    'no_keyboard_focus',
    '/ os.environ["WAYLAND_DISPLAY"]).is_socket()',
    'namespaced(niri_json(niri, "layers"), "hadalis:abyss-perimeter")',
    '"NIRI_SOCKET"',
    '"WAYLAND_DISPLAY"',
    'shutil.which("wdotool")',
    '"--backend", "wlr-protocols", "mousemove"',
    '"--backend", "wlr-protocols", "click", "1"',
    '"WULL_PRIVATE_POINTER_SESSION": "isolated-nested-only"',
    '"WULL_PRIVATE_POINTER_CHECKOUT": str(ROOT)',
    'companion',
    'rust_present',
    'real_bridge_click_received',
    'rust_happy_pulse_ack',
    'underlay_count() == before + 1',
    'report["production_unmapped"]',
    'report["underlay_unmapped"]',
    'report["private_daemon_stopped"]',
):
    # A nonessential word may be present outside a strict literal marker.
    assert marker in child_text, marker
for forbidden in ('"ydotool"', '"/dev/uinput"', '"uinput"'):
    assert forbidden not in parent_text + child_text, forbidden
assert "real_bridge_click_received" in relay_text
assert "rust_happy_pulse_ack" in relay_text
assert "rust_present" in relay_text
assert '"WULL_PRIVATE_POINTER_CHECKOUT"' in relay_text

parent = runpy.run_path(str(ROOT / "scripts/wull-manual-nested-pointer.py"),
                        run_name="wull_pointer_inert_parent")
child = runpy.run_path(str(ROOT / "scripts/wull-manual-pointer-child.py"),
                       run_name="wull_pointer_inert_child")
assert parent["REVIEWED"]["scripts/wull-manual-pointer-child.py"] == (
    "bfed36f31cd9f34fd3f180581eb90377dce7ce16")
assert parent["REVIEWED"]["scripts/wull-fixtures/pointer-underlay/companion-relay.py"] == (
    "7e450db1db23e3c250859b0271a655d6325f0bc8")

# Bounded early-exit cleanup never signals a potentially recycled group.
stop_group = parent["stop_owned_child_group"]
class ExitedChild:
    pid = 123456
    def poll(self):
        return 0
with mock.patch("os.killpg") as group_signal:
    stop_group(ExitedChild())
    assert not group_signal.called

# Owned, still-running child: terminate its entire private session, so a
# blocked private Cargo/wdotool child cannot survive a coordinator timeout.
class HungChild:
    pid = 123456
    def __init__(self):
        self.waits = 0
    def poll(self):
        return None
    def wait(self, timeout):
        self.waits += 1
        if self.waits == 1:
            raise subprocess.TimeoutExpired("owned-private-child", timeout)
        return -9
with mock.patch("os.killpg") as group_signal:
    stop_group(HungChild())
    assert group_signal.call_args_list == [
        mock.call(123456, signal.SIGTERM),
        mock.call(123456, signal.SIGKILL)
    ]

# Parent's Niri parser is the already-reviewed one from the standalone proof.
parse = parent["startup_identity"]
sample = ("2026 INFO listening on Wayland socket: wayland-5\n"
          "2026 INFO IPC listening on: /run/user/1000/niri.wayland-5.2.sock\n")
assert parse(sample) == (
    "wayland-5", "/run/user/1000/niri.wayland-5.2.sock")
assert parse("no compositor was started") == (None, None)

# A simulated nested/host identity collision must fail without running Niri.
with mock.patch.dict(child["verify_isolation"].__globals__["os"].environ, {
    "WULL_PRIVATE_POINTER_CHILD": "owned-nested",
    "WULL_PRIVATE_POINTER_NESTED_SOCKET": "/private/same.sock",
    "NIRI_SOCKET": "/private/same.sock",
    "WULL_PARENT_NIRI_SOCKET": "/private/same.sock",
    "WAYLAND_DISPLAY": "wayland-3",
    "WULL_PARENT_WAYLAND_DISPLAY": "wayland-3",
}, clear=True):
    with mock.patch.dict(child["verify_isolation"].__globals__,
                         {"niri_json": lambda *_: (_ for _ in ()).throw(
                             AssertionError("Unexpected Niri call"))}):
        try:
            child["verify_isolation"]("/unused/niri")
        except RuntimeError as error:
            assert str(error) == "nested_identity_unverified"
        else:
            raise AssertionError("Host/socket collision not refused")

# Deterministic keyboard-focus policy is inert and rejects unknown modes.
no_focus = child["no_keyboard_focus"]
assert no_focus([{"keyboard_interactivity": "none"}])
assert no_focus([{"keyboard_interactivity": "WlrKeyboardFocus.None"}])
assert not no_focus([{"keyboard_interactivity": "exclusive"}])
assert not no_focus([{"keyboard_interactivity": "unknown"}])
assert not no_focus([])

# Exercise exact lower-layer QML staging and private config without a window.
with tempfile.TemporaryDirectory(prefix="wull-nested-pointer-inert-") as root:
    root = Path(root)
    underlay, env = child["phase_config"](
        root / "underlay", child["UNDERLAY"], "underlay")
    staged = (underlay / "shell.qml").read_text()
    assert "WlrLayer.Bottom" in staged
    assert "WlrKeyboardFocus.None" in staged
    assert "WULL_POINTER_UNDERLAY_PRESS" in staged
    assert not (underlay / "modules").exists()
    conf = json.loads((ROOT / "defaults/config.json").read_text())
    conf["abyss"]["companion"]["enabled"] = True
    production, env = child["phase_config"](
        root / "production", child["PRODUCTION"], "enabled", conf)
    assert "AbyssPerimeter { }" in (production / "shell.qml").read_text()
    assert (production / "modules").is_symlink()
    isolated_config = root / "production" / "xdg" / "config" / (
        "illogical-impulse/config.json")
    assert isolated_config.is_file()
    assert json.loads(isolated_config.read_text())["abyss"]["companion"]["enabled"]
    assert env["QT_QPA_PLATFORM"] == "wayland"
    # Parse only local synthetic files; no live injected click.
    logfile = root / "private.log"
    logfile.write_text(
        "WULL_POINTER_UNDERLAY_QML_READY\n"
        "WULL_POINTER_UNDERLAY_PRESS {\"x\":120,\"y\":77,\"button\":1}\n")
    assert len(child["markers"](logfile, "WULL_POINTER_UNDERLAY_PRESS ")) == 1
    trace = root / "private.jsonl"
    trace.write_text(
        '{"kind":"real_bridge_click_received","when_monotonic":1.0}\n'
        '{"kind":"rust_happy_pulse_ack","when_monotonic":1.1}\n')
    assert child["trace_kinds"](trace) == [
        "real_bridge_click_received", "rust_happy_pulse_ack"]

# Source audit relies on an exact reviewed helper and previously PASS sources.
assert "stop_owned" in parent and "private_strays" in parent
assert "owned_cleanup" in child and "verify_isolation" in child
print("WULL_NESTED_POINTER_INERT_CONTRACT_PASS")
