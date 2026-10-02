#!/usr/bin/env python3
"""FAKE-ONLY original bottom same-instance full/core/details/cradle isolation.

Never calls Qt, D-Bus, compositor, pointer or desktop. Uses ONLY synthetic
in-memory RGBA8 PNG, temporary private files and a source-reviewed parser.
"""
import ast
import hashlib
from pathlib import Path
import runpy
import stat
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "scripts/wull-private-bottom-static-source-model.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-bottom-source/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-bottom-source.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
BASE = ROOT / "scripts/wull-manual-private-paired-static-matrix.py"


def blob(p):
    raw = p.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(MODEL) == "3eb60d0b7222c12f6d07a772f3bbf94e0cadb3f3"
assert blob(FIXTURE) == "3838ac82c70263324fa50185d75a60478363f7c1"
assert blob(RUNNER) == "5130e0dcf14e987291f828fc4ce6baaf8429af2f"
assert blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(BASE) == "fee5944e8fe9fb40a38da24edd104ef78ef32496"
model = runpy.run_path(str(MODEL), run_name="fake_bottom_source_classifier")
alpha = runpy.run_path(str(ALPHA), run_name="fake_bottom_original_alpha")
runner = runpy.run_path(str(RUNNER), run_name="fake_bottom_source_runner")
qml = FIXTURE.read_text(encoding="utf-8")
source = RUNNER.read_text(encoding="utf-8")
ast.parse(source)
assert runner["BASE_BLOB"] == blob(BASE)
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["ALPHA_BLOB"] == blob(ALPHA)
assert model["ORIGINAL_ALPHA_BLOB"] == blob(ALPHA)
assert runner["PROCESS_TIMEOUT"] == 34
assert runner["MAX_LOG"] <= 256 * 1024
assert runner["MAX_PNG"] <= 1024 * 1024
assert runner["CHILD_FILE_LIMIT"] == 8 * 1024 * 1024
assert runner["VARIANTS"] == model["VARIANTS"] == (
    "full", "core", "details", "cradle")
assert model["HOST_RECT"] == (72.0, 75.5, 168.0, 147.0)
assert runner["expected_stages"]() == [
    "BOOT", "PREPARED",
    "FULL_REQUESTED", "FULL_SAVED",
    "CORE_REQUESTED", "CORE_SAVED",
    "DETAILS_REQUESTED", "DETAILS_SAVED",
    "CRADLE_REQUESTED", "CRADLE_SAVED", "DONE"
]
for token in (
    "one_private_qt_process" if "one_private_qt_process" in source
    else 'base["checked_sources"]()',
    "BOTTOM_SOURCE_PIN_INVALID",
    'core["stage_files"](directory)', 'core["private_env"](',
    'env["WULL_BOTTOM_SOURCE_DIR"]',
    "start_new_session=True", "preexec_fn=child_limits",
    "proc.wait(timeout=PROCESS_TIMEOUT)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)",
    "stages == expected_stages()", "private_classify(directory)",
    "PRIVATE_BOTTOM_STATIC_SOURCE_CLASSIFIED",
):
    assert token in source, token

for token in (
    "AbyssCompanion {", 'edge: "bottom"', "scale: 1.5",
    "host.children.length !== 2", "b.children.length !== 5",
    "Math.abs(b.rotation - 180)", "root.originalPose.length !== 24",
    "Math.abs(n - root.originalPose[i]) < .05",
    "root.sourceCore.width !== 76",
    "Math.abs(cradle.width - 58)", "Math.abs(cradle.height - 10)",
    'root.scene("full")', '"full", "core", "details", "cradle"',
    "if (child !== core) child.visible = false",
    "core.visible = false", "cradle.visible = false",
    "for (const child of visuals) child.visible = false",
    "root.sceneVerified(kind)", "root.samePose()",
    'root.stage("PREPARED")', "stageItem.grabToImage(",
    'Quickshell.env("WULL_BOTTOM_SOURCE_DIR")',
    "interval: 24000",
):
    assert token in qml, token

assert qml.count("AbyssCompanion {") == 1
assert qml.count("FloatingWindow {") == 1
assert qml.count("grabToImage(") == 1
for forbidden in (
    "grabWindow", "ScreenCapture", "captureScreen", "Niri {",
    "Wayland {", "Process {", "HttpRequest", "wlrctl",
    "ydotool", "wdotool",
):
    assert forbidden not in qml, forbidden
for forbidden in ("git push", '"git", "commit"', "print(raw)",
                  "print(directory)", "print(log.read_text"):
    assert forbidden not in source, forbidden


def denied(exc, category, func, *args):
    try:
        func(*args)
    except exc as err:
        assert str(err) == category, (str(err), category)
    else:
        raise AssertionError("Unsafe fake capture accepted: " + category)


sequence = runner["expected_stages"]()
rawlog = "\n".join("marker WULL_BOTTOM_SOURCE_STAGE=" + s for s in sequence)
assert runner["private_stages"](rawlog) == (sequence, [])
denied(runner["Stop"], "BOTTOM_SOURCE_STAGE_INVALID",
       runner["private_stages"], rawlog +
       "\nWULL_BOTTOM_SOURCE_STAGE=DONE")
denied(runner["Stop"], "BOTTOM_SOURCE_STAGE_INVALID",
       runner["private_stages"], "WULL_BOTTOM_SOURCE_STAGE=CORE_SAVED")
denied(runner["Stop"], "BOTTOM_SOURCE_FAILURE_UNRECOGNIZED",
       runner["private_stages"],
       "WULL_BOTTOM_SOURCE_FAILURE=PRIVATE_HOST_PATH")
assert runner["private_stages"](
    rawlog.split("\n")[0] +
    "\nWULL_BOTTOM_SOURCE_FAILURE=SOURCE_VISIBILITY_OR_POSE_CHANGED"
) == (["BOOT"], ["SOURCE_VISIBILITY_OR_POSE_CHANGED"])


def chunk(typ, data):
    return struct.pack(">I", len(data)) + typ + data + struct.pack(
        ">I", zlib.crc32(typ + data) & 0xffffffff)


def png(points):
    width, height = model["CANVAS"]
    buffer = bytearray()
    for y in range(height):
        buffer.append(0)
        for x in range(width):
            buffer.extend((22, 66, 88, 255)
                          if (x, y) in points else (0, 0, 0, 0))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(buffer), 9))
            + chunk(b"IEND", b""))


inside = {(x, y) for x in range(140, 148)
          for y in range(135, 143)}
outside = {(250, 150)}
base = png(inside)
only_outside = png(outside)
full = png(inside | outside)
transparent = png(set())
scenario = {
    "full": full, "core": base, "details": transparent,
    "cradle": only_outside,
}
result = model["classify"](scenario, alpha)
assert result["outside"] == {
    "full": True, "core": False, "details": False, "cradle": True}
assert result["full_exterior_same_pixel_overlap"] == {
    "core": False, "details": False, "cradle": True}
assert result["captures_sequential"] is True
assert result["overlap_is_not_causality"] is True
assert result["production_mask_changed"] is False
assert result["sampled_original_animation"] == "not_tested"
alternative = {
    "full": full, "core": base, "details": only_outside,
    "cradle": transparent,
}
check = model["classify"](alternative, alpha)
assert check["outside"]["details"] is True
assert check["outside"]["cradle"] is False
assert check["full_exterior_same_pixel_overlap"]["details"] is True
disjoint = dict(scenario, cradle=png({(252, 151)}))
assert model["classify"](
    disjoint, alpha)["full_exterior_same_pixel_overlap"]["cradle"] is False
denied(model["Unqualified"], "FOUR_SOURCE_CAPTURES_REQUIRED",
       model["classify"], {"full": full, "core": base}, alpha)
denied(model["Unqualified"], "SOURCE_PRIVATE_RGBA_PNG_UNSUPPORTED",
       model["classify"], dict(scenario, core=b"INVALID PNG"), alpha)
denied(model["Unqualified"], "SOURCE_PAINT_REACHES_CANVAS_EDGE",
       model["classify"], dict(scenario, cradle=png({(0, 0)})), alpha)
denied(model["Unqualified"], "FULL_OR_CORE_INTERIOR_PAINT_MISSING",
       model["classify"], dict(scenario, core=transparent), alpha)
with tempfile.TemporaryDirectory(prefix="wull-bottom-fake-") as temp:
    d = Path(temp)
    for name, contents in scenario.items():
        target = d / (name + ".private.png")
        target.write_bytes(contents)
        target.chmod(0o600)
    assert runner["private_classify"](d) == result
    extra = d / "extra.private.png"
    extra.write_bytes(base)
    extra.chmod(0o600)
    denied(runner["Stop"], "BOTTOM_SOURCE_PNG_SET_INCOMPLETE",
           runner["private_classify"], d)
    extra.unlink()
    victim = d / "full.private.png"
    victim.chmod(0o644)
    denied(runner["Stop"], "BOTTOM_SOURCE_PNG_UNSAFE",
           runner["private_classify"], d)
    victim.chmod(0o600)
    victim.write_bytes(b"forged-private")
    denied(runner["Stop"], "BOTTOM_SOURCE_ALPHA_INCONCLUSIVE",
           runner["private_classify"], d)

print("WULL_PRIVATE_BOTTOM_STATIC_SOURCE_INERT_PASS")
