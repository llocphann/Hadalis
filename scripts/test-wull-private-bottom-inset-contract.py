#!/usr/bin/env python3
"""FAKE ONLY: source-pinned original full BOTTOM×1.5 cradle-inset pilot.

Never run Qt, inspect host screenshots, publish private artifacts or mutate Git.
All PNG captures in this test are synthetic memory bytes / 0600 temp files.
"""
import ast
import hashlib
import runpy
from pathlib import Path
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "scripts/wull-private-bottom-cradle-inset-model.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-bottom-inset/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-bottom-inset.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
BASE = ROOT / "scripts/wull-manual-private-bottom-source.py"


def git_blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert git_blob(MODEL) == "77c89bd49771992b2618ba656768840592aaa594"
assert git_blob(FIXTURE) == "45fc03e743d08a996c763c491e0d2b42d22f75ba"
assert git_blob(RUNNER) == "75f923b104c8409b3532a809c3ba62cfd5998e03"
assert git_blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert git_blob(BASE) == "5130e0dcf14e987291f828fc4ce6baaf8429af2f"

model = runpy.run_path(str(MODEL), run_name="wull_inset_fake_model")
runner = runpy.run_path(str(RUNNER), run_name="wull_inset_fake_runner")
alpha = runpy.run_path(str(ALPHA), run_name="wull_inset_fake_original_alpha")
qml = FIXTURE.read_text(encoding="utf-8")
py = RUNNER.read_text(encoding="utf-8")
ast.parse(py)
assert model["ALPHA_BLOB"] == git_blob(ALPHA)
assert runner["MODEL_BLOB"] == git_blob(MODEL)
assert runner["FIXTURE_BLOB"] == git_blob(FIXTURE)
assert runner["BASE_BLOB"] == git_blob(BASE)
assert runner["ALPHA_BLOB"] == git_blob(ALPHA)
assert runner["MARGINS"] == model["MARGINS"] == (0, 1, 2, 3)
assert runner["PROCESS_TIMEOUT"] == 34
assert runner["MAX_PNG"] <= 1024 * 1024
assert runner["MAX_LOG"] <= 256 * 1024
assert runner["CHILD_FILE_LIMIT"] == 8 * 1024 * 1024
assert model["HOST"] == (72.0, 75.5, 168.0, 147.0)

for phrase in (
    "AbyssCompanion {", 'edge: "bottom"', "scale: 1.5",
    "host.children.length !== 2", "b.children.length !== 5",
    "b.children.some(child => !child.visible)",
    "Math.abs(b.rotation - 180)", "root.pose.length !== 24",
    "Math.abs(n - root.pose[i]) < .05",
    "root.sourceCradle.anchors.bottomMargin = margin",
    "root.sourceCradle.anchors.bottomMargin = 0",
    "Math.abs(c.anchors.bottomMargin - margin) > .001",
    "207.5 - 1.5 * margin", "222.5 - 1.5 * margin",
    "root.marginVerified(margin)", "root.marginVerified(0)",
    "stageItem.grabToImage(", "result.saveToFile(output)",
    'Quickshell.env("WULL_BOTTOM_INSET_DIR")',
    '"BOTTOM_INSET_TIMEOUT"', 'root.stage("DONE")',
):
    assert phrase in qml, phrase
assert qml.count("AbyssCompanion {") == 1
assert qml.count("FloatingWindow {") == 1
assert qml.count("grabToImage(") == 1
for forbidden in (
    "ScreenCapture", "grabWindow", "captureScreen", "Wayland {",
    "Niri {", "Process {", "HttpRequest", "wlrctl", "ydotool", "wdotool",
):
    assert forbidden not in qml, forbidden
for phrase in (
    'base["checked_sources"]()', 'core["stage_files"](directory)',
    'core["private_env"](', 'env["WULL_BOTTOM_INSET_DIR"]',
    "start_new_session=True", "preexec_fn=child_limits",
    "proc.wait(timeout=PROCESS_TIMEOUT)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)",
    "stages == expected_stages()", "private_classify(directory)",
    "ORIGINAL_FULL_COMPOSITE=SOURCE_PINNED",
    "PRIVATE_BOTTOM_INSET_CANDIDATE_CLASSIFIED",
):
    assert phrase in py, phrase
for forbidden in ('"git", "push"', '"git", "commit"', "print(raw)",
                  "print(directory)", "print(log.read_text"):
    assert forbidden not in py, forbidden


def denied(exc_type, error, fn, *args):
    try:
        fn(*args)
    except exc_type as exc:
        assert str(exc) == error, (str(exc), error)
    else:
        raise AssertionError("Fake unsafe input accepted: " + error)


expected = runner["expected_stages"]()
assert expected == [
    "BOOT", "PREPARED",
    "M0_REQUESTED", "M0_SAVED",
    "M1_REQUESTED", "M1_SAVED",
    "M2_REQUESTED", "M2_SAVED",
    "M3_REQUESTED", "M3_SAVED", "DONE"
]
markers = "\n".join(
    "checked WULL_BOTTOM_INSET_STAGE=" + name for name in expected)
assert runner["private_stages"](markers) == (expected, [])
denied(runner["Stop"], "BOTTOM_INSET_STAGE_INVALID",
       runner["private_stages"],
       markers + "\nWULL_BOTTOM_INSET_STAGE=DONE")
denied(runner["Stop"], "BOTTOM_INSET_STAGE_INVALID",
       runner["private_stages"], "WULL_BOTTOM_INSET_STAGE=M2_SAVED")
denied(runner["Stop"], "BOTTOM_INSET_FAILURE_UNRECOGNIZED",
       runner["private_stages"],
       "WULL_BOTTOM_INSET_FAILURE=PRIVATE_HOST_DATA")
assert runner["private_stages"](
    "WULL_BOTTOM_INSET_STAGE=BOOT\n"
    "WULL_BOTTOM_INSET_FAILURE=ORIGINAL_SOURCE_OR_POSE_DRIFT"
) == (["BOOT"], ["ORIGINAL_SOURCE_OR_POSE_DRIFT"])


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


def png(points):
    width, height = model["CANVAS"]
    buffer = bytearray()
    for y in range(height):
        buffer.append(0)
        for x in range(width):
            buffer.extend((25, 65, 100, 255) if (x, y) in points
                          else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(buffer), 9))
            + chunk(b"IEND", b""))


inside = {(x, y) for x in range(140, 148) for y in range(135, 143)}
exterior = {(255, 150)}
plain, out = png(inside), png(inside | exterior)
images = {0: out, 1: out, 2: plain, 3: plain}
report = model["classify"](images, alpha)
assert report["original_zero_margin_exterior"] is True
assert report["smallest_tested_zero_exterior_margin"] == 2
assert report["exterior_by_margin"] == {
    0: True, 1: True, 2: False, 3: False}
assert report["production_mask_changed"] is False
assert report["dynamic_and_compositor_input"] == "not_tested"
assert model["classify"](
    {0: out, 1: out, 2: out, 3: out},
    alpha)["smallest_tested_zero_exterior_margin"] is None
assert model["classify"](
    {0: out, 1: plain, 2: out, 3: plain},
    alpha)["smallest_tested_zero_exterior_margin"] == 1
denied(model["Unqualified"], "FOUR_MARGIN_CAPTURES_REQUIRED",
       model["classify"], {0: out, 1: out}, alpha)
denied(model["Unqualified"],
       "ORIGINAL_ZERO_MARGIN_BASELINE_NOT_REPRODUCED",
       model["classify"], {0: plain, 1: plain, 2: plain, 3: plain}, alpha)
denied(model["Unqualified"], "MARGIN_PRIVATE_PNG_INVALID",
       model["classify"], {0: out, 1: out, 2: b"bad", 3: plain}, alpha)
denied(model["Unqualified"], "MARGIN_PAINT_REACHES_CAPTURE_EDGE",
       model["classify"],
       {0: out, 1: out, 2: png(inside | {(0, 0)}), 3: plain},
       alpha)
denied(model["Unqualified"], "MARGIN_INSIDE_ORIGINAL_COMPOSITE_MISSING",
       model["classify"], {0: out, 1: out, 2: png(set()), 3: plain}, alpha)

with tempfile.TemporaryDirectory(prefix="wull-inset-fake-") as tmp:
    directory = Path(tmp)
    for margin, raw in images.items():
        p = directory / ("m" + str(margin) + ".private.png")
        p.write_bytes(raw)
        p.chmod(0o600)
    assert runner["private_classify"](directory) == report
    extra = directory / "extra.private.png"
    extra.write_bytes(plain)
    extra.chmod(0o600)
    denied(runner["Stop"], "BOTTOM_INSET_PNG_SET_INCOMPLETE",
           runner["private_classify"], directory)
    extra.unlink()
    victim = directory / "m0.private.png"
    victim.chmod(0o644)
    denied(runner["Stop"], "BOTTOM_INSET_PNG_UNSAFE",
           runner["private_classify"], directory)
    victim.chmod(0o600)
    victim.write_bytes(b"bad")
    denied(runner["Stop"], "BOTTOM_INSET_ALPHA_INCONCLUSIVE",
           runner["private_classify"], directory)

print("WULL_PRIVATE_BOTTOM_INSET_INERT_PASS")
