#!/usr/bin/env python3
"""FAKE ONLY: syntax, pinned original+private nested visual safety contract.

No compositor, Qt, grim, Cargo, Git publication, screenshots, network or
desktop interaction. All PNGs, sessions and Niri API objects are synthetic.
"""
import hashlib
import json
import os
from pathlib import Path
import runpy
import stat
import struct
import tempfile
import zlib

os.umask(0o077)
ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/wull-manual-private-nested-quarter-visual.py"
SHADOW = ROOT / "scripts/wull-private-panel-quarter-shadow.py"
PREFLIGHT = ROOT / "scripts/wull-private-nested-visual-prerequisites.py"
ORIGINAL = ROOT / "modules/abyss/companion/AbyssCompanion.qml"
PERIMETER = ROOT / "modules/abyss/AbyssPerimeter.qml"
FIXTURE = ROOT / "scripts/wull-fixtures/production-layer/shell.qml"
NESTED = ROOT / "scripts/wull-manual-nested-niri.py"
RELAY = ROOT / "scripts/wull-fixtures/pointer-underlay/companion-relay.py"
DEFAULTS = ROOT / "defaults/config.json"

EXPECTED = {
    RUNNER: "b719f2b0a6c6e0121f9f2c0467f8d4e7a28cfa9f",
    SHADOW: "dd62b2b834e86d41856730547bca8ea4d73aaca8",
    PREFLIGHT: "83367598877fa61804cdb84ef500fce744fbbb99",
    ORIGINAL: "b5b01835a282458eba0d0268396ae2c350d919d2",
    PERIMETER: "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
    FIXTURE: "e16b6dcada26a27fd71cc670e30c55135401bcef",
    NESTED: "7edf8328df1f9704f1331fbe1a5e84e659cd360a",
    RELAY: "7e450db1db23e3c250859b0271a655d6325f0bc8",
    DEFAULTS: "e10d98c0f26d3e47c51cb8452bcd0d2cea735501",
}


def blob(raw):
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
    ).hexdigest()


for path, sha in EXPECTED.items():
    # A historical owner-qualified trial must read its ORIGINAL QML from
    # archived fixtures now that dev has intentionally moved production.
    historic = ROOT / "scripts/wull-fixtures/historical"
    archived = (
        historic / "pre-surface-attachment-companion.snapshot"
        if path == ORIGINAL else
        historic / "pre-surface-attachment-perimeter.snapshot"
        if path == PERIMETER else path
    )
    assert archived.is_file() and blob(archived.read_bytes()) == sha, path.name

script = RUNNER.read_text(encoding="utf-8")
runner = runpy.run_path(str(RUNNER), run_name="wull_fake_nested_quarter_import")
assert runner["BORROW_BLOB"] == EXPECTED[NESTED]
assert runner["SHADOW_BLOB"] == EXPECTED[SHADOW]
assert runner["PREFLIGHT_BLOB"] == EXPECTED[PREFLIGHT]
assert runner["PERIMETER_BLOB"] == EXPECTED[PERIMETER]
assert runner["COMPANION_BLOB"] == EXPECTED[ORIGINAL]
assert runner["FIXTURE_BLOB"] == EXPECTED[FIXTURE]
assert runner["DEFAULTS_BLOB"] == EXPECTED[DEFAULTS]
assert runner["RELAY_BLOB"] == EXPECTED[RELAY]
assert set(runner["REQUIRED"]) == {
    (str(path.relative_to(ROOT)), sha) for path, sha in EXPECTED.items()
    if path not in (RUNNER,)
}
assert runner["ORIGIN"] == "https://github.com/llocphann/Hadalis.git"
assert runner["MAX_LOG"] <= 1024 * 1024
assert runner["MAX_IMAGE"] <= 24 * 1024 * 1024
assert runner["TIMEOUT_SCREENSHOT"] <= 16

# Absolute screenshot authority is always the separately verified nested
# socket. No inherited WAYLAND_SOCKET FD or screenshot fallback to host.
for token in (
    'capture_env.pop("WAYLAND_SOCKET", None)',
    'capture_env["WAYLAND_DISPLAY"] != host[0]',
    'capture_env["NIRI_SOCKET"] != str(host[1])',
    'need(ipc != host[1] and display != host[0]',
    'native_layer(niri, ipc, output, count=1)',
    '[grim, "-o", output, "-t", "png", str(image)]',
    'env.pop(key, None)',
    'image.chmod(0o600)',
    'MAXIMUM_SPRING_EXTREMA',  # documentary negative: MUST NOT claim any
):
    if token == "MAXIMUM_SPRING_EXTREMA":
        assert token not in script
    else:
        assert token in script, token
assert script.index('capture_env.pop("WAYLAND_SOCKET", None)') < (
    script.index('result = subprocess.run(\n            [grim,'))
assert script.count('capture_once(niri, nested_ipc') == 1
assert 'for mode in ("original_m0", "private_bottom_m025"):' in script
assert 'SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED' in script
assert 'REAL_PANEL_VISUAL_CONNECTION=OWNER_REVIEW_REQUIRED' in script
assert 'COMPOSITOR_POINTER_AND_POPUP=NOT_TESTED' in script
for unsafe in ('git("push"', '"git", "commit"', "wlrctl", "wdotool",
               'WAYLAND_DISPLAY=host_display,\n                           NIRI_SOCKET=str(ipc)'):
    assert unsafe not in script, unsafe


def denied(category, action, *args):
    try:
        action(*args)
    except runner["Stop"] as exc:
        assert str(exc) == category, (str(exc), category)
    else:
        raise AssertionError("Unsafe synthetic state accepted: " + category)


logical = {"x": 0, "y": 0, "width": 1280, "height": 720,
           "scale": 1.0, "transform": "normal"}
entry = {"logical": logical, "is_focused": True}
json_api = {"Ok": {"Outputs": {"Virtual-1": entry}}}
outputs = runner["parse_api"](json.dumps(json_api).encode(), "outputs")
assert runner["active_outputs"](outputs) == {"Virtual-1": entry}
new_focus = {"Virtual-1": dict(entry, is_focused=False)}
assert runner["host_signature"](outputs) == runner["host_signature"](new_focus)
invalid_output = {"Virtual-1": dict(entry, logical=dict(logical, scale=1.25))}
fn = runner["one_output"]
old_json = fn.__globals__["niri_json"]
try:
    fn.__globals__["niri_json"] = lambda _bin, _ipc, _cmd: outputs
    assert fn("fake", "fake") == ("Virtual-1", 1280, 720, 1.0)
    fn.__globals__["niri_json"] = lambda _bin, _ipc, _cmd: invalid_output
    denied("NESTED_OUTPUT_GEOMETRY_OR_SCALE_UNVERIFIED",
           fn, "fake", "fake")
finally:
    fn.__globals__["niri_json"] = old_json
assert runner["parse_api"](
    json.dumps({"Ok": {"Layers": []}}).encode(), "layers") == []

# Original default is read, never changed. Private config has real Bar and
# bottom Wull at scale1.5, disabled interactive pointer for visual phase.
before = DEFAULTS.read_bytes()
cfg = runner["fixed_config"]("Virtual-1")
assert DEFAULTS.read_bytes() == before
assert cfg["bar"]["bottom"] is True
assert cfg["bar"]["vertical"] is False
assert cfg["bar"]["autoHide"]["enable"] is False
assert "abyssBar" in cfg["enabledPanels"]
assert "abyssPerimeter" in cfg["enabledPanels"]
assert cfg["abyss"]["companion"]["enabled"] is True
assert cfg["abyss"]["companion"]["size"] == 1.5
assert cfg["abyss"]["companion"]["edge"] == "bottom"
assert cfg["abyss"]["companion"]["interactive"] is False
# Test inherited Wayland FD in fake process and RESTORE it immediately.
old_socket = os.environ.get("WAYLAND_SOCKET")
os.environ["WAYLAND_SOCKET"] = "inherited-host-fd"
try:
    private = runner["private_qt_env"](
        Path("/private/xdg"), Path("/runtime/niri-private.sock"),
        "wayland-private", Path("/private/release/inir-companiond"))
finally:
    if old_socket is None:
        del os.environ["WAYLAND_SOCKET"]
    else:
        os.environ["WAYLAND_SOCKET"] = old_socket
assert private["NIRI_SOCKET"] == "/runtime/niri-private.sock"
assert private["WAYLAND_DISPLAY"] == "wayland-private"
assert private["INIR_COMPANIOND"] == "/private/release/inir-companiond"
assert "WAYLAND_SOCKET" not in private

# Even a caller-supplied full fake environment must NEVER screen-capture
# when the claimed nested endpoints are literally identical to the host.
with tempfile.TemporaryDirectory(prefix="wull-nested-visual-fake.") as tmp:
    directory = Path(tmp)
    denied("NESTED_IDENTITY_LOST_BEFORE_QT", runner["capture_once"],
           None, directory, "wayland-fake", directory,
           "output", (1280, 720), None, None, None, None,
           directory, "original_m0", {}, {}, ("wayland-fake", directory))

    def chunk(name, payload):
        return (struct.pack(">I", len(payload)) + name + payload +
                struct.pack(">I", zlib.crc32(name + payload) & 0xffffffff))

    w, h = 1280, 720
    pixels = (b"\0" + b"\0" * (w * 4)) * h
    raw = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) +
           chunk(b"IDAT", zlib.compress(pixels, 9)) +
           chunk(b"IEND", b""))
    png = directory / "fake-image.png"
    png.write_bytes(raw)
    png.chmod(0o600)
    runner["secure_png"](png, (w, h))
    denied("NESTED_SCREENSHOT_DIMENSIONS_UNVERIFIED",
           runner["secure_png"], png, (w + 1, h))
    bad = bytearray(raw)
    bad[-10] ^= 1
    png.write_bytes(bytes(bad))
    denied("NESTED_SCREENSHOT_PNG_INVALID",
           runner["secure_png"], png, (w, h))
    png.write_bytes(raw)
    png.chmod(0o644)
    denied("NESTED_SCREENSHOT_UNSAFE",
           runner["secure_png"], png, (w, h))

print("WULL_PRIVATE_NESTED_QUARTER_VISUAL_INERT_PASS")
