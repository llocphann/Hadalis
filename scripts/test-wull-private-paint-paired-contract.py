#!/usr/bin/env python3
"""Fake-only same-Qt-session paired alpha source, process and PNG contract."""
import ast
import hashlib
import os
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "scripts/wull-fixtures/paint-alpha-paired/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-paint-paired.py"
BASE = ROOT / "scripts/wull-manual-private-paint-core.py"
MODEL = ROOT / "scripts/wull-private-painted-alpha-model.py"


def blob(file):
    data = file.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


assert blob(FIXTURE) == "83326999c8363420fabb5bbb5022d100ab1a64c6"
assert blob(RUNNER) == "c30279f99fbb05ff6e67d30c690b091851dfc4e5"
assert blob(BASE) == "1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c"
assert blob(MODEL) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
source = RUNNER.read_text(encoding="utf-8")
qml = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
pair = runpy.run_path(str(RUNNER), run_name="paired_inert_contract")
base = runpy.run_path(str(BASE), run_name="paired_base_inert_contract")
model = runpy.run_path(str(MODEL), run_name="paired_model_inert_contract")
assert pair["BASE_BLOB"] == blob(BASE)
assert pair["FIXTURE_BLOB"] == blob(FIXTURE)
assert pair["FILE_LIMIT"] == 8 * 1024 * 1024
assert pair["MAX_LOG"] <= 256 * 1024
assert pair["HOST"] == (100, 100, 112, 98)
assert pair["THRESHOLD"] == model["ALPHA_THRESHOLD"]

for fragment in (
    "AbyssCompanion {", 'edge: "top"', "scale: 1.0",
    "bodyStretch: 1", "captureStage.grabToImage(",
    "const visuals = b.children",
    "visuals.length !== 5",
    "coreCandidates.length !== 1",
    "for (const child of visuals)",
    "if (child !== shape)",
    "child.visible = false",
    "const fullOutput = Quickshell.env(\"WULL_CAPTURE_FULL\")",
    "const coreOutput = Quickshell.env(\"WULL_CAPTURE_CORE\")",
    "fullOutput === coreOutput",
    "privatePose = root.pose()", "root.samePose()",
    "Qt.callLater(() => {",
    'root.stage("FINISHED")',
):
    assert fragment in qml, fragment
assert qml.count("AbyssCompanion {") == 1
assert qml.count("captureStage.grabToImage(") == 2
assert qml.count("result.saveToFile(") == 2
assert "WaterDropletBody {" not in qml
for unsafe in ("grabWindow", "captureScreen", "ScreenCapture",
               "Wayland {", "Niri {", "Process {", "wdotool",
               "wlrctl", "ydotool", "HttpRequest"):
    assert unsafe not in qml, unsafe
for fragment in (
    "base[\"audit_clone\"]()", "BASE_BLOB", "FIXTURE_BLOB",
    "base[\"private_env\"](xdg, full)", "env.pop(\"WULL_CAPTURE_OUTPUT\", None)",
    "env[\"WULL_CAPTURE_FULL\"]", "env[\"WULL_CAPTURE_CORE\"]",
    '"QT_QPA_PLATFORM"', '"offscreen"', "start_new_session=True",
    "preexec_fn=child_limits", "proc.wait(timeout=14)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)",
    "base[\"verify_png\"](full)", "base[\"verify_png\"](core)",
    "a and b", "x0 <= x + .5 < x0 + w",
):
    # private_env source is defined in the pinned BASE, not the paired runner.
    if fragment in ('"QT_QPA_PLATFORM"', '"offscreen"'):
        assert fragment in BASE.read_text(encoding="utf-8")
    else:
        assert fragment in source, fragment
for unsafe in ('"git", "push"', '"git", "rebase"', '"--force"',
               "print(full_alpha)", "print(core_alpha)"):
    assert unsafe not in source

def denied(expected, fn, *args):
    try:
        fn(*args)
    except pair["Stop"] as exc:
        assert str(exc) == expected, (str(exc), expected)
    else:
        raise AssertionError("negative case accepted: " + expected)


valid = "\n".join(
    "private WULL_PAIRED_CORE_STAGE=" + step for step in pair["STAGES"])
assert pair["stages_from_log"](valid) == (list(pair["STAGES"]), [])
denied("PAIRED_STAGE_INVALID", pair["stages_from_log"],
       valid + "\nprivate WULL_PAIRED_CORE_STAGE=BOOT")
denied("PAIRED_STAGE_INVALID", pair["stages_from_log"],
       "private WULL_PAIRED_CORE_STAGE=UNSAFE_PRIVATE_COORD")
denied("PAIRED_FAILURE_UNRECOGNIZED", pair["stages_from_log"],
       "private WULL_PAIRED_CORE_FAILURE=/host/screen/private")
assert pair["stages_from_log"](
    "private WULL_PAIRED_CORE_FAILURE=PRE_FULL_POSE_DRIFT") == (
        [], ["PRE_FULL_POSE_DRIFT"])


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


def fake_png(points):
    width, height = 320, 300
    scan = bytearray()
    for y in range(height):
        scan.append(0)
        for x in range(width):
            scan.extend((14, 25, 36, 255) if (x, y) in points
                        else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return model["PNG_SIGNATURE"] + chunk(b"IHDR", header) + (
        chunk(b"IDAT", zlib.compress(bytes(scan), 9)) +
        chunk(b"IEND", b""))


inside = {(x, y) for x in range(106, 112) for y in range(106, 112)}
exterior_left = (98, 110)
exterior_right = (215, 110)
with tempfile.TemporaryDirectory(prefix="wull-paired-fake-") as dir:
    full = Path(dir) / "full.fake.png"
    core = Path(dir) / "core.fake.png"

    def capture(path, points):
        path.write_bytes(fake_png(points))
        path.chmod(0o600)

    capture(full, inside | {exterior_left})
    capture(core, inside | {exterior_left})
    assert pair["classify_private_images"](base, full, core) == (
        True, True, True)
    capture(core, inside | {exterior_right})
    assert pair["classify_private_images"](base, full, core) == (
        True, True, False)
    capture(core, inside)
    assert pair["classify_private_images"](base, full, core) == (
        True, False, False)
    capture(full, inside)
    capture(core, inside | {exterior_left})
    assert pair["classify_private_images"](base, full, core) == (
        False, True, False)
    capture(full, set())
    denied("PAIRED_PRIVATE_IMAGE_INVALID",
           pair["classify_private_images"], base, full, core)
    capture(full, inside | {exterior_left})
    capture(core, inside | {(0, 0)})
    denied("PAIRED_PRIVATE_IMAGE_INVALID",
           pair["classify_private_images"], base, full, core)
    core.write_bytes(b"not-a-private-png")
    denied("PAIRED_PRIVATE_IMAGE_INVALID",
           pair["classify_private_images"], base, full, core)

print("WULL_PRIVATE_PAIRED_CORE_INERT_PASS")
