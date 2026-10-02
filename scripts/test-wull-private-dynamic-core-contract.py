#!/usr/bin/env python3
"""FAKE-ONLY source-isolated original ShapePath/stroke moving painted-alpha contract.

No Qt, compositor, host display, real screenshots, subprocess or publication.
Fixtures are generated in memory, and private file model uses FAKE PNGs.
"""
import ast
import copy
import hashlib
import os
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "scripts/wull-private-dynamic-core-model.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-dynamic-core/shell.qml"
RUNNER = ROOT / "scripts/wull-manual-private-dynamic-core.py"
GUARD = ROOT / "scripts/wull-manual-private-paint-core.py"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(MODEL) == "ec4ba1af10cabbb1f645ea94af7f5fca0ac5e731"
assert blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(FIXTURE) == "d10da7216afef1ba579775a87505b2d649e4fe65"
assert blob(RUNNER) == "50e351a3ec2775f02d92d76e63d09727e008cf71"
assert blob(GUARD) == "1fbc0e8e0c8c361a706ff31af1b0a138ec9b841c"

model = runpy.run_path(str(MODEL), run_name="wull_fake_dynamic_model")
alpha = runpy.run_path(str(ALPHA), run_name="wull_fake_dynamic_alpha")
runner = runpy.run_path(str(RUNNER), run_name="wull_fake_dynamic_runner")
qml = FIXTURE.read_text(encoding="utf-8")
source = RUNNER.read_text(encoding="utf-8")
ast.parse(source)
assert model["MODEL_ORIGINAL_BLOB"] == blob(ALPHA)
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["BORROW_BLOB"] == blob(GUARD)
assert runner["TIMEOUT"] == 48
assert "MOTION_TOP_STRETCH_MAPPED_UNOBSERVED" in runner["FAILURES"]
assert "MOTION_BOTTOM_STRETCH_SPRING_UNOBSERVED" in runner["FAILURES"]
assert "MOTION_TOP_RELEASE_TRANSITION_UNOBSERVED" in runner["FAILURES"]
assert "MOTION_BOTTOM_RELEASE_OBSERVER_INSUFFICIENT" in runner["FAILURES"]
assert "SAMPLED_MAPPED_MOTION_NOT_OBSERVED" not in runner["FAILURES"]
assert runner["FILE_LIMIT"] == 8 * 1024 * 1024
assert runner["MAX_LOG"] <= 256 * 1024
assert runner["MAX_PNG"] <= 1024 * 1024
assert runner["CASES"] == ("top", "bottom")
assert model["CASES"] == ("top_100", "bottom_150")
assert model["SAMPLES"] == runner["SAMPLES"] == 8
assert len(model["expected"]()) == 32
assert len(runner["stages"]()) == 39
assert runner["stages"]()[:2] == ["BOOT", "CORE_ISOLATION_VERIFIED"]
assert {"CORE_ISOLATION_INVALID", "CORE_ISOLATION_DRIFT"} <= runner["FAILURES"]
assert model["geometry"]("bottom_150") == (72.0, 75.5, 168.0, 147.0)

for phrase in (
    "AbyssCompanion {", "id: topHost", "id: bottomHost",
    'edge: "top"', 'edge: "bottom"', "scale: 1.5",
    "topStage.grabToImage" if "topStage.grabToImage" in qml else
    "root.stageAt(n).grabToImage",
    "b.mapToItem(stageItem", "root.noteMotion(n, values)",
    "root.watch()", "motionWatch.start()", "motionWatch.stop()",
    "function isolate(n): bool", "function isCoreAlone(n): bool",
    "host.children.length !== 2", "visuals.length !== 5",
    "cradle[0].visible = false", "child.visible = false",
    "root.isCoreAlone(n)", "root.isolate(0)", "root.isolate(1)",
    'root.stage("CORE_ISOLATION_VERIFIED")',
    "interval: 40", "root.stateMoved[n]", "root.intermediateStretch[n]",
    "root.moved[n]", "root.observerTicks[n] < 4",
    "STRETCH_BASELINE_INVALID", "RELEASE_BASELINE_INVALID",
    "droplet.motionEnabled = true" if "droplet.motionEnabled = true"
    in qml else "a.motionEnabled = true",
    "a.stateStretch = 1", "b.stateStretch = 1",
    "top.stateStretch = 0", "bottom.stateStretch = 0",
    'root.stage("WITNESS_COMPLETE")',
    'Quickshell.env("WULL_DYNAMIC_CORE_DIR")',
    'result.saveToFile(name)',
    "interval: 38000",
):
    assert phrase in qml, phrase
assert qml.count("AbyssCompanion {") == 2
assert qml.count("FloatingWindow {") == 2
assert qml.count("grabToImage(") == 1
for forbidden in (
    "grabWindow", "ScreenCapture", "captureScreen",
    "Wayland {", "Niri {", "Process {", "HttpRequest", "wlrctl",
    "ydotool", "wdotool",
):
    assert forbidden not in qml, forbidden
for phrase in (
    'base["audit_clone"]()', "BORROW_BLOB", "FIXTURE_BLOB",
    "MODEL_BLOB", 'base["private_env"](',
    'env.pop("WULL_CAPTURE_OUTPUT", None)',
    'env["WULL_DYNAMIC_PILOT_DIR"]',
    "start_new_session=True", "preexec_fn=resource_limits",
    "proc.wait(timeout=TIMEOUT)", "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)", "stages == stages()" if
    "stages == stages()" in source else "found == stages()",
    'model["classify"](case, phase, i, raw, alpha)',
):
    assert phrase in source, phrase
for forbidden in ('"git", "push"', '"git", "rebase"', '"--force"',
                  "print(raw)", "print(directory)"):
    assert forbidden not in source, forbidden


def denied(exc, category, func, *args):
    try:
        func(*args)
    except exc as err:
        assert str(err) == category, (str(err), category)
    else:
        raise AssertionError("Unsafe synthetic input accepted: " + category)


# A legitimate categorized fixture failure remains a FAIL, never a PASS.
assert "GATE=PRIVATE_DYNAMIC_CORE_QML_FAILURE_IDENTIFIED" in source
assert "KNOWN_QML_FAILURE=" in source
assert "found == stages()[:len(found)]" in source
recognized = runner["ObservedQmlFailure"](
    "MOTION_BOTTOM_STRETCH_MAPPED_UNOBSERVED", "STRETCH_7_BOTTOM")
assert recognized.category in runner["FAILURES"]
assert recognized.last_stage in runner["stages"]()
steps = runner["stages"]()
assert len(steps) == 39
assert steps[1] == "CORE_ISOLATION_VERIFIED"
log = "\n".join("noise WULL_DYNAMIC_CORE_STAGE=" + x for x in steps)
assert runner["private_stages"](log) == (steps, [])
denied(runner["Stop"], "DYNAMIC_STAGE_INVALID",
       runner["private_stages"], log +
       "\nnoise WULL_DYNAMIC_CORE_STAGE=DONE")
denied(runner["Stop"], "DYNAMIC_STAGE_INVALID",
       runner["private_stages"], "WULL_DYNAMIC_CORE_STAGE=PRIVATE_PATH")
denied(runner["Stop"], "DYNAMIC_FAILURE_UNRECOGNIZED",
       runner["private_stages"],
       "WULL_DYNAMIC_CORE_FAILURE=HOST_SCREEN_DATA")


def chunk(tag, body):
    return (struct.pack(">I", len(body)) + tag + body
            + struct.pack(">I", zlib.crc32(tag + body) & 0xffffffff))


def png(points):
    width, height = model["CANVAS"]
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend((30, 70, 100, 255) if (x, y) in points
                       else (0, 0, 0, 0))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


inside = {(x, y) for x in range(145, 152) for y in range(136, 143)}
top_exterior = (98, 125)
bottom_exterior = (260, 150)
plain = png(inside)
top_painted = png(inside | {top_exterior})
bottom_painted = png(inside | {bottom_exterior})
clipped = png(inside | {(0, 0)})
assert model["classify"](
    "top_100", "stretch", 0, top_painted, alpha
)["source_core_outside_host_alpha"] is True
assert model["classify"](
    "bottom_150", "stretch", 0, plain, alpha
)["source_core_outside_host_alpha"] is False
denied(model["Inconclusive"], "UNKNOWN_PHASE_OR_SAMPLE",
       model["classify"], "top_100", "stretch", True, plain, alpha)
denied(model["Inconclusive"], "PRIVATE_DYNAMIC_PNG_UNSUPPORTED",
       model["classify"], "top_100", "stretch", 0, b"fake", alpha)
denied(model["Inconclusive"], "PRIVATE_DYNAMIC_CANVAS_PAINT_TRUNCATED",
       model["classify"], "top_100", "stretch", 0, clipped, alpha)
denied(model["Inconclusive"], "PRIVATE_DYNAMIC_INTERIOR_PAINT_MISSING",
       model["classify"], "top_100", "stretch", 0, png(set()), alpha)

witness = {
    "active_stretch": True, "active_release": True,
    "mapped_change_top_stretch": True,
    "mapped_change_bottom_stretch": True,
    "mapped_change_top_release": True,
    "mapped_change_bottom_release": True,
    "stretch_target_reached": True,
    "release_target_reached": True,
}
rows = []
with tempfile.TemporaryDirectory(prefix="wull-dynamic-fake-") as root:
    folder = Path(root)
    for phase, i, case in model["expected"]():
        stem = "top" if case == "top_100" else "bottom"
        data = (top_painted if phase == "stretch" and i == 3 and
                case == "top_100"
                else bottom_painted if phase == "release" and i == 6 and
                case == "bottom_150" else plain)
        row = model["classify"](case, phase, i, data, alpha)
        rows.append(row)
        file = folder / (phase + "-" + stem + "-" + str(i) + ".private.png")
        file.write_bytes(data)
        file.chmod(0o600)

    summary = model["summarize"](rows, witness)
    assert summary["sampled_frames"] == 32
    assert summary["real_qt_phase_witness"] is True
    assert summary["cases"] == [
        {"case": "top_100", "stretch_core_exterior_alpha_observed": True,
         "release_core_exterior_alpha_observed": False},
        {"case": "bottom_150", "stretch_core_exterior_alpha_observed": False,
         "release_core_exterior_alpha_observed": True},
    ]
    qualified = runner["private_classify"](folder)
    assert qualified == summary
    denied(model["Inconclusive"], "DYNAMIC_CAPTURE_MATRIX_INCOMPLETE",
           model["summarize"], rows[:-1], witness)
    spoof = copy.deepcopy(rows)
    spoof[-1]["raw_coordinates"] = "sensitive"
    denied(model["Inconclusive"], "DYNAMIC_FRAME_ORDER_OR_FIELDS_INVALID",
           model["summarize"], spoof, witness)
    no_witness = dict(witness, mapped_change_bottom_release=False)
    denied(model["Inconclusive"], "DYNAMIC_PHASE_OR_MOTION_WITNESS_MISSING",
           model["summarize"], rows, no_witness)

    extra = folder / "extra.private.png"
    extra.write_bytes(plain)
    extra.chmod(0o600)
    denied(runner["Stop"], "DYNAMIC_PNG_SET_INCOMPLETE",
           runner["private_classify"], folder)
    extra.unlink()
    victim = folder / "stretch-top-0.private.png"
    victim.chmod(0o644)
    denied(runner["Stop"], "DYNAMIC_PNG_UNSAFE",
           runner["private_classify"], folder)
    victim.chmod(0o600)
    victim.write_bytes(b"forged-private-bad-png")
    denied(runner["Stop"], "DYNAMIC_PAINT_ALPHA_INCONCLUSIVE",
           runner["private_classify"], folder)

print("WULL_PRIVATE_DYNAMIC_OBSERVED_INERT_PASS")
