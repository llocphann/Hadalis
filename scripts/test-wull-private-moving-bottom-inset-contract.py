#!/usr/bin/env python3
"""FAKE ONLY original moving BOTTOM×1.5 cradle0 versus private cradle1 A/B.

No Qt, desktop/Wayland, network, screenshots, live private files or publication.
The alpha PNGs are synthetic in-memory or 0600 temporary fake files.
"""
import ast
import hashlib
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "scripts/wull-private-dynamic-bottom-inset-model.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-moving-bottom-inset/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-moving-bottom-inset.py"
ORIGINAL_ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
GUARD = ROOT / "scripts/wull-manual-private-paint-core.py"


def blob(path):
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


assert blob(MODEL) == "834dc0e861bf2b06821a3f4399833201841e7d0e"
assert blob(FIXTURE) == "26133a295433f7f61ce64f94a2ece3d14015a57b"
assert blob(RUNNER) == "d58e8c4720573de94e0992f35d3a2b6e4dd65a7e"
assert blob(ORIGINAL_ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(GUARD) == "1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c"

model = runpy.run_path(str(MODEL), run_name="wull_fake_moving_inset_model")
runner = runpy.run_path(str(RUNNER), run_name="wull_fake_moving_inset_runner")
alpha = runpy.run_path(str(ORIGINAL_ALPHA), run_name="wull_fake_moving_inset_alpha")
qml = FIXTURE.read_text(encoding="utf-8")
code = RUNNER.read_text(encoding="utf-8")
ast.parse(code)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
assert runner["BORROW_BLOB"] == blob(GUARD)
assert model["MODEL_ORIGINAL_BLOB"] == blob(ORIGINAL_ALPHA)
assert runner["CASES"] == ("m0", "m1")
assert model["CASES"] == ("m0_150", "m1_150")
assert runner["PHASES"] == model["PHASES"] == ("stretch", "release")
assert runner["SAMPLES"] == model["SAMPLES"] == 8
assert len(model["expected"]()) == 32
assert len(runner["stages"]()) == 39
assert runner["stages"]()[:4] == [
    "BOOT", "CRADLE_MARGIN_PAIR_VERIFIED", "NEUTRAL_READY", "STRETCH_START"]
assert runner["MAX_LOG"] <= 256 * 1024
assert runner["MAX_PNG"] <= 1024 * 1024
assert runner["FILE_LIMIT"] == 8 * 1024 * 1024
assert runner["TIMEOUT"] == 48
assert model["geometry"]("m0_150") == (72.0, 75.5, 168.0, 147.0)
assert model["geometry"]("m1_150") == model["geometry"]("m0_150")

for word in (
    "AbyssCompanion {", 'name: "m0", edge: "bottom"',
    'name: "m1", edge: "bottom"',
    "scaleValue: 1.5, margin: 0", "scaleValue: 1.5, margin: 1",
    "host.children.length !== 2",
    "b.children.length !== 5",
    "b.children.some(item => !item.visible)",
    "function checkedCradle(n): bool",
    "Math.abs(item.anchors.bottomMargin - spec.margin) > .001",
    "Math.abs(a.x - 112.5) < .18",
    "Math.abs(a.y - (207.5 - 1.5 * spec.margin)) < .18",
    "Math.abs(b.y - (222.5 - 1.5 * spec.margin)) < .18",
    "c1.anchors.bottomMargin = 1",
    "Math.abs(c0.anchors.bottomMargin) > .001",
    "Math.abs(c1.anchors.bottomMargin) > .001",
    'root.stage("CRADLE_MARGIN_PAIR_VERIFIED")',
    "root.checkedCradle(0)", "root.checkedCradle(1)",
    "!root.checkedCradle(n)", "root.noteMotion(n, geometry)",
    "root.stateMoved[n]", "root.intermediateStretch[n]",
    "root.moved[n]", "root.observerTicks[n] < 4",
    "a.stateStretch = 1", "b.stateStretch = 1",
    "top.stateStretch = 0", "bottom.stateStretch = 0",
    "motionWatch.start()", "motionWatch.stop()",
    "interval: 40", "interval: 350", "interval: 38000",
    "root.stageAt(n).grabToImage(", "result.saveToFile(name)",
    'Quickshell.env("WULL_MOVING_INSET_DIR")',
    'root.stage("WITNESS_COMPLETE")',
):
    assert word in qml, word
assert qml.count("AbyssCompanion {") == 2
assert qml.count("FloatingWindow {") == 2
assert qml.count("grabToImage(") == 1
for invalid in (
    "ScreenCapture", "grabWindow", "captureScreen",
    "Wayland {", "Niri {", "Process {", "HttpRequest",
    "wlrctl", "ydotool", "wdotool",
):
    assert invalid not in qml, invalid
for word in (
    'base["audit_clone"]()', "BORROW_BLOB", "FIXTURE_BLOB",
    "MODEL_BLOB", 'base["private_env"](',
    'env["WULL_MOVING_INSET_DIR"]',
    'env.pop("WULL_DYNAMIC_PILOT_DIR", None)',
    "start_new_session=True", "preexec_fn=resource_limits",
    "proc.wait(timeout=TIMEOUT)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)",
    "found == stages()", "private_classify(directory)",
    "MARGIN0_POSITIVE_BOTH_PHASES=YES",
    "MOVING_BASELINE_NOT_REPRODUCED",
    "SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED",
    "PRIVATE_MOVING_INSET_CANDIDATE_CLASSIFIED",
):
    assert word in code, word
for name in (
    "ORIGINAL_MARGINS_OR_SOURCE_INVALID",
    "PRIVATE_INSET_GEOMETRY_INVALID",
    "MOTION_M0_STRETCH_SPRING_UNOBSERVED",
    "MOTION_M1_RELEASE_MAPPED_UNOBSERVED",
):
    assert name in runner["FAILURES"]
for invalid in ('"git", "push"', '"git", "commit"', "print(raw)",
                "print(directory)", "print(log.read_text"):
    assert invalid not in code, invalid


def denied(error_cls, name, action, *args):
    try:
        action(*args)
    except error_cls as exc:
        assert str(exc) == name, (str(exc), name)
    else:
        raise AssertionError("Unsafe synthetic state accepted: " + name)


stages = runner["stages"]()
complete = "\n".join("audit WULL_MOVING_INSET_STAGE=" + stage
                     for stage in stages)
assert runner["private_stages"](complete) == (stages, [])
denied(runner["Stop"], "DYNAMIC_STAGE_INVALID",
       runner["private_stages"],
       complete + "\nWULL_MOVING_INSET_STAGE=DONE")
denied(runner["Stop"], "DYNAMIC_STAGE_INVALID",
       runner["private_stages"], "WULL_MOVING_INSET_STAGE=RELEASE_START")
denied(runner["Stop"], "DYNAMIC_FAILURE_UNRECOGNIZED",
       runner["private_stages"],
       "WULL_MOVING_INSET_FAILURE=PRIVATE_IMAGE_PATH")
assert runner["private_stages"](
    "WULL_MOVING_INSET_STAGE=BOOT\n"
    "WULL_MOVING_INSET_FAILURE=ORIGINAL_MARGINS_OR_SOURCE_INVALID"
) == (["BOOT"], ["ORIGINAL_MARGINS_OR_SOURCE_INVALID"])


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))


def png(points):
    w, h = model["CANVAS"]
    scan = bytearray()
    for y in range(h):
        scan.append(0)
        for x in range(w):
            scan.extend((25, 55, 85, 255)
                        if (x, y) in points else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return alpha["PNG_SIGNATURE"] + chunk(
        b"IHDR", header) + chunk(
        b"IDAT", zlib.compress(bytes(scan), 9)) + chunk(b"IEND", b"")


interior = {(x, y) for x in range(145, 152)
            for y in range(135, 143)}
outside = {(251, 150)}
normal = png(interior)
painted = png(interior | outside)
clipped = png(interior | {(0, 0)})
assert model["classify"](
    "m0_150", "stretch", 0, painted, alpha
)["composite_outside_host_alpha"] is True
assert model["classify"](
    "m1_150", "stretch", 0, normal, alpha
)["composite_outside_host_alpha"] is False
denied(model["Inconclusive"], "UNKNOWN_PHASE_OR_SAMPLE",
       model["classify"], "m1_150", "stretch", True, normal, alpha)
denied(model["Inconclusive"], "PRIVATE_DYNAMIC_PNG_UNSUPPORTED",
       model["classify"], "m0_150", "stretch", 0, b"bad", alpha)
denied(model["Inconclusive"], "PRIVATE_DYNAMIC_CANVAS_PAINT_TRUNCATED",
       model["classify"], "m0_150", "stretch", 0, clipped, alpha)

witness = {
    "active_stretch": True, "active_release": True,
    "mapped_change_m0_stretch": True,
    "mapped_change_m1_stretch": True,
    "mapped_change_m0_release": True,
    "mapped_change_m1_release": True,
    "stretch_target_reached": True,
    "release_target_reached": True,
}
with tempfile.TemporaryDirectory(prefix="wull-inset-fake-") as parent:
    directory = Path(parent)
    rows = []
    for phase, i, case in model["expected"]():
        positive = case == "m0_150" and i == 3
        raw = painted if positive else normal
        rows.append(model["classify"](case, phase, i, raw, alpha))
        stem = "m0" if case == "m0_150" else "m1"
        image = directory / (
            phase + "-" + stem + "-" + str(i) + ".private.png")
        image.write_bytes(raw)
        image.chmod(0o600)
    summary = model["summarize"](rows, witness)
    assert summary["sampled_frames"] == 32
    assert summary["baseline_margin0_both_phase_exterior_required"] is True
    assert summary["cases"] == [
        {"case": "m0_150", "stretch_exterior_alpha_observed": True,
         "release_exterior_alpha_observed": True},
        {"case": "m1_150", "stretch_exterior_alpha_observed": False,
         "release_exterior_alpha_observed": False},
    ]
    assert runner["private_classify"](directory) == summary
    unqualified = [dict(row) for row in rows]
    for row in unqualified:
        if row["case"] == "m0_150" and row["phase"] == "release":
            row["composite_outside_host_alpha"] = False
    denied(model["Inconclusive"],
           "ORIGINAL_DYNAMIC_BASELINE_NOT_REPRODUCED",
           model["summarize"], unqualified, witness)
    fake_witness = dict(witness, mapped_change_m1_release=False)
    denied(model["Inconclusive"], "DYNAMIC_PHASE_OR_MOTION_WITNESS_MISSING",
           model["summarize"], rows, fake_witness)
    denied(model["Inconclusive"], "DYNAMIC_CAPTURE_MATRIX_INCOMPLETE",
           model["summarize"], rows[:-1], witness)
    forged = [dict(row) for row in rows]
    forged[-1]["raw_pixel"] = "unsafe"
    denied(model["Inconclusive"], "DYNAMIC_FRAME_ORDER_OR_FIELDS_INVALID",
           model["summarize"], forged, witness)
    extra = directory / "unreviewed.private.png"
    extra.write_bytes(normal)
    extra.chmod(0o600)
    denied(runner["Stop"], "DYNAMIC_PNG_SET_INCOMPLETE",
           runner["private_classify"], directory)
    extra.unlink()
    target = directory / "stretch-m0-0.private.png"
    target.chmod(0o644)
    denied(runner["Stop"], "DYNAMIC_PNG_UNSAFE",
           runner["private_classify"], directory)
    target.chmod(0o600)
    target.write_bytes(b"bad")
    denied(runner["Stop"], "DYNAMIC_PAINT_ALPHA_INCONCLUSIVE",
           runner["private_classify"], directory)

print("WULL_PRIVATE_MOVING_BOTTOM_INSET_INERT_PASS")
