#!/usr/bin/env python3
"""FAKE-ONLY source/privacy/process-contract and synthetic PNG tests.

Does not start a compositor, Qt, D-Bus or read private capture files.
"""
import ast
import hashlib
import os
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "scripts/wull-fixtures/paint-alpha-shadow/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-paint-shadow.py"
MODEL = ROOT / "scripts/wull-private-painted-alpha-model.py"


def blob(path):
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


assert blob(FIXTURE) == "feea498f8b75c24cdd93fe116bac0dd6b36b1d01"
assert blob(RUNNER) == "08670b15307115adf8432614bdb13b36071effe0"
assert blob(MODEL) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
source = RUNNER.read_text(encoding="utf-8")
qml = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
model = runpy.run_path(str(MODEL), run_name="wull_paint_canary_inert_model")
program = runpy.run_path(str(RUNNER), run_name="wull_paint_canary_inert_runner")
assert program["PINS"][program["FIXTURE"]] == blob(FIXTURE)
assert program["PINS"][program["MODEL"]] == blob(MODEL)
assert program["PINS"]["modules/abyss/companion/AbyssCompanion.qml"] == (
    "b5b01835a282458eba0d0268396ae2c350d919d2")
assert program["PINS"]["modules/abyss/companion/WaterDropletBody.qml"] == (
    "fc5b1c227026786ab553685bc170daff74e82517")
assert program["PINS"]["modules/abyss/AbyssPerimeter.qml"] == (
    "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac")
assert program["PINS"]["modules/common/Config.qml"] == (
    "2bdf7d37f183b976d928fa15b0eb2ec57c646b60")
assert program["PINS"]["scripts/wull-manual-offscreen-motion-geometry.py"] == (
    "0dd833ed05d54e9d1045553a1da8be8f66b6511a")
assert program["PINS"]["scripts/wull-manual-private-paint-canary.py"] == (
    "5ce5155303913b9eda49590ba017c074b8e176fc")
assert program["FILE_LIMIT"] == 8 * 1024 * 1024
assert program["MAX_LOG"] <= 256 * 1024

# Source check: actual unchanged companion is the only visual content.
for literal in (
    "import qs.modules.abyss.companion",
    "FloatingWindow {",
    'color: "transparent"',
    "implicitWidth: 320",
    "implicitHeight: 300",
    "WaterDropletBody {",
    "id: shadowHost",
    "width: 112",
    "stateStretch: 1",
    "transformOrigin: Item.Center",
    "motionEnabled: false",
    "pulse: 0",
    "ripple: 0",
    "captureStage.grabToImage(",
    "result.saveToFile(output)",
    "Quickshell.env(\"WULL_CAPTURE_OUTPUT\")",
    "privateWindow.backingWindowVisible",
    'root.abort("CAPTURE_TIMEOUT")',
):
    assert literal in qml, literal
assert qml.count("WaterDropletBody {") == 1
assert "AbyssCompanion {" not in qml
for forbidden in (
    "grabWindow", "captureScreen", "ScreenCapture", "Process {",
    "Wayland {", "Niri {", "wlrctl", "ydotool", "wdotool", "ShellService",
    "HttpRequest",
):
    assert forbidden not in qml, forbidden
assert "QT_QPA_PLATFORM" in source
assert '"offscreen"' in source
assert '"DISPLAY", "WAYLAND_DISPLAY", "NIRI_SOCKET"' in source
assert '"DBUS_SESSION_BUS_ADDRESS"' in source
assert '"DBUS_SYSTEM_BUS_ADDRESS"' in source
assert "preexec_fn=child_resource_limit" in source
assert "start_new_session=True" in source
assert "os.killpg(process.pid, signal.SIGTERM)" in source
assert "os.killpg(process.pid, signal.SIGKILL)" in source
assert "process.wait(timeout=13)" in source
assert "git(\"status\", \"--porcelain=v1\", \"--untracked-files=all\")" in source
assert '"git", "push"' not in source
assert '"git", "rebase"' not in source
for forbidden in ('"reset"', '"--force"', "print(raw)", "print(png.read_bytes())"):
    assert forbidden not in source

# No host identifiers, screen/display values, user paths or coordinates escape.
fake_xdg = Path("/private-owned-fake-scratch/xdg")
fake_png = Path("/private-owned-fake-scratch/out.private.png")
prior = dict(os.environ)
os.environ["WAYLAND_DISPLAY"] = "secret-wayland-host"
os.environ["DISPLAY"] = "secret-x-server"
os.environ["NIRI_SOCKET"] = "/private/host/niri"
os.environ["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/private/host/bus"
try:
    safe = program["private_env"](fake_xdg, fake_png)
finally:
    os.environ.clear()
    os.environ.update(prior)
for key in ("DISPLAY", "WAYLAND_DISPLAY", "NIRI_SOCKET",
            "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS"):
    assert key not in safe, key
assert safe["QT_QPA_PLATFORM"] == "offscreen"
assert safe["XDG_RUNTIME_DIR"] == str(fake_xdg / "runtime")
assert safe["WULL_CAPTURE_OUTPUT"] == str(fake_png)
assert "secret-wayland-host" not in str(safe)
assert "secret-x-server" not in str(safe)

def rejected(code, fn, *args):
    try:
        fn(*args)
    except program["Stop"] as ex:
        assert str(ex) == code, (str(ex), code)
    else:
        raise AssertionError("Unexpectedly accepted: " + code)

status_line = "\n".join(
    "internal WULL_PAINT_SHADOW_STAGE=" + name
    for name in program["STAGES"])
assert program["stages_from_log"](status_line) == (
    list(program["STAGES"]), [])
rejected("PRIVATE_STAGE_SEQUENCE_INVALID",
         program["stages_from_log"], status_line +
         "\ninternal WULL_PAINT_SHADOW_STAGE=BOOT")
rejected("PRIVATE_STAGE_SEQUENCE_INVALID",
         program["stages_from_log"],
         "internal WULL_PAINT_SHADOW_STAGE=SECRET")
rejected("PRIVATE_FAILURE_UNRECOGNIZED",
         program["stages_from_log"],
         "internal WULL_PAINT_SHADOW_FAILURE=private/path/secret")
assert program["stages_from_log"](
    "internal WULL_PAINT_SHADOW_FAILURE=CAPTURE_TIMEOUT") == (
        [], ["CAPTURE_TIMEOUT"])


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


def fake_png(points):
    width, height = 320, 300
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            if (x, y) in points:
                raw.extend((90, 40, 20, 255))
            else:
                raw.extend((0, 0, 0, 0))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (model["PNG_SIGNATURE"] + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(bytes(raw), level=9)) +
            chunk(b"IEND", b""))


interior = {(x, y) for x in range(106, 112) for y in range(106, 112)}
with tempfile.TemporaryDirectory(prefix="wull-paint-inert-") as directory:
    png = Path(directory) / "fake.private.png"

    def stored(points):
        png.write_bytes(fake_png(points))
        png.chmod(0o600)
        return png

    assert program["verify_png"](stored(interior)) is False
    assert program["verify_png"](stored(interior | {(98, 110)})) is True
    rejected("PRIVATE_PNG_NO_INTERIOR_PAINT",
             program["verify_png"], stored(set()))
    rejected("PRIVATE_PNG_CANVAS_CLIPPED",
             program["verify_png"], stored(interior | {(0, 0)}))
    png.write_bytes(b"private-inert-not-a-png")
    png.chmod(0o600)
    try:
        program["verify_png"](png)
    except ValueError as exc:
        assert str(exc) == "PNG_SIGNATURE_INVALID"
    else:
        raise AssertionError("Malformed fake capture was accepted")

print("WULL_PRIVATE_PAINT_SHADOW_INERT_PASS")
