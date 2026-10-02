#!/usr/bin/env python3
"""FAKE-ONLY private static Qt matrix runner integration/cleanup/privacy gate.

Never launches Qt, Niri or D-Bus. Builds deterministic synthetic PNGs only.
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
RUNNER = ROOT / "scripts/wull-manual-private-paired-static-matrix.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-static-matrix/shell.qml"
MODEL = ROOT / "scripts/wull-private-static-paired-matrix-model.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
BASE = ROOT / "scripts/wull-manual-private-paint-paired.py"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(RUNNER) == "fee5944e8fe9fb40a38da24edd104ef78ef32496"
assert blob(FIXTURE) == "4860f504cff167e806afe8217d73201012b7d278"
assert blob(MODEL) == "b8870420db8d1e6cc08f1f5b0f792c4ab186be61"
assert blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(BASE) == "c30279f99fbb05ff6e67d30c690b091851dfc4e5"
source = RUNNER.read_text(encoding="utf-8")
qml = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
runner = runpy.run_path(str(RUNNER), run_name="wull_matrix_runner_inert")
model = runpy.run_path(str(MODEL), run_name="wull_matrix_model_inert")
alpha = runpy.run_path(str(ALPHA), run_name="wull_matrix_alpha_inert")
assert runner["BASE_BLOB"] == blob(BASE)
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["MAX_LOG"] <= 256 * 1024
assert runner["FILE_LIMIT"] == 8 * 1024 * 1024
assert runner["CAPTURE_TIMEOUT"] <= 75
assert runner["FAILURES"] >= {
    "CRADLE_RESTORE_FAILED", "PRE_FULL_CRADLE_OR_POSE_INVALID",
}
assert runner["EDGES"] == model["EDGES"]
assert runner["SCALES"] == model["SCALES"]
assert runner["expected_stages"]()[0] == "BOOT"
assert runner["expected_stages"]()[-1] == "DONE"
assert len(runner["expected_stages"]()) == 62

for mandatory in (
    "AbyssCompanion {", "captureStage.grabToImage(",
    "source-pinned" if "source-pinned" in qml else "PRIVATE SOURCE-PINNED",
    'edge: "top"', "scale: 1", "root.cases", "root.caseIndex",
    "privatePose: []", "root.samePose()", "root.hostGeometryConsistent()",
    "host.mapToItem(captureStage", "b.mapToItem(captureStage",
    "visuals.length !== 5", "core.length !== 1",
    "child.visible = false", "child.visible = true",
    "host.children.length !== 2", "const externalCradle = root.cradle()",
    "cradle.visible = false", "cradle.visible = true",
    "root.privateCradle = externalCradle",
    "root.caseIndex++", "Qt.callLater", "root.stage(\"DONE\")",
    'Quickshell.env("WULL_MATRIX_CAPTURE_DIR")',
    "captureStage.grabToImage", "result.saveToFile(output)",
    "interval: 65000",
):
    assert mandatory in qml, mandatory
assert qml.count("AbyssCompanion {") == 1
assert qml.count("captureStage.grabToImage(") == 2
assert qml.count("result.saveToFile(output)") == 2
assert "WaterDropletBody {" not in qml
for forbidden in ("ScreenCapture", "captureScreen", "grabWindow",
                  "Wayland {", "Niri {", "Process {",
                  "wlrctl", "ydotool", "wdotool", "HttpRequest"):
    assert forbidden not in qml
for mandatory in (
    "borrowed[\"checked_base\"]()", "start_new_session=True",
    "preexec_fn=child_limits", "proc.wait(timeout=CAPTURE_TIMEOUT)",
    "os.killpg(proc.pid, signal.SIGTERM)",
    "os.killpg(proc.pid, signal.SIGKILL)",
    'env.pop("WULL_CAPTURE_OUTPUT", None)',
    'env["WULL_MATRIX_CAPTURE_DIR"]',
    'stage == expected_stages()', "stages == expected_stages()",
    'matrix["classify"](i, full, core, alpha)',
    '"--acknowledge-private-static-paired-matrix"',
    "GATE=PRIVATE_STATIC_PAIRED_MATRIX_CLASSIFIED",
):
    # Check exact contract spelling, not generic static grep on tests.
    if mandatory == 'stage == expected_stages()':
        assert "stages == expected_stages()" in source
    else:
        assert mandatory in source, mandatory
for forbidden in ('"git", "push"', '"git", "rebase"',
                  "print(log.read_text", "print(full)", "print(core)"):
    assert forbidden not in source


def denied(category, action, *args):
    try:
        action(*args)
    except runner["Stop"] as exc:
        assert str(exc) == category, (str(exc), category)
    else:
        raise AssertionError("Unsafe fake matrix accepted: " + category)


stages = runner["expected_stages"]()
raw = "\n".join("prefix WULL_STATIC_MATRIX_STAGE=" + stage for stage in stages)
assert runner["classify_private_stages"](raw) == (stages, [])
denied("MATRIX_STAGE_INVALID", runner["classify_private_stages"],
       raw + "\nprefix WULL_STATIC_MATRIX_STAGE=DONE")
denied("MATRIX_STAGE_INVALID", runner["classify_private_stages"],
       "prefix WULL_STATIC_MATRIX_STAGE=PRIVATE_SCREEN_INFO")
denied("MATRIX_FAILURE_UNRECOGNIZED", runner["classify_private_stages"],
       "prefix WULL_STATIC_MATRIX_FAILURE=/host/home/private")
assert runner["classify_private_stages"](
    "prefix WULL_STATIC_MATRIX_FAILURE=CASE_MAPPED_GEOMETRY_INVALID"
) == ([], ["CASE_MAPPED_GEOMETRY_INVALID"])


def chunk(tag, payload):
    return (struct.pack(">I", len(payload)) + tag + payload +
            struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff))


def fake_png(points):
    width, height = model["CANVAS"]
    scan = bytearray()
    for y in range(height):
        scan.append(0)
        for x in range(width):
            scan.extend((35, 89, 104, 255) if (x, y) in points
                        else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(scan), 9))
            + chunk(b"IEND", b""))


inside = {(x, y) for x in range(148, 154) for y in range(142, 148)}
valid = fake_png(inside | {(60, 150)})
with tempfile.TemporaryDirectory(prefix="wull-static-matrix-inert-") as name:
    folder = Path(name)
    for i in range(12):
        for stem in ("full", "core"):
            f = folder / (stem + "-" + str(i) + ".private.png")
            f.write_bytes(valid)
            f.chmod(0o600)
    qualified = runner["private_classify"](folder)
    assert qualified["qualified_case_count"] == 12
    assert all(case["composite_outside_host"]
               and case["source_core_outside_host"]
               and case["same_pixel_exterior_overlap"]
               for case in qualified["cases"])
    # Synthetic extra/absent/unsafe image fixtures MUST all fail closed.
    extra = folder / "full-12.private.png"
    extra.write_bytes(valid)
    extra.chmod(0o600)
    denied("CAPTURE_MATRIX_FILES_INCOMPLETE",
           runner["private_classify"], folder)
    extra.unlink()
    missing = folder / "core-11.private.png"
    missing.unlink()
    denied("CAPTURE_MATRIX_FILES_INCOMPLETE",
           runner["private_classify"], folder)
    missing.write_bytes(valid)
    missing.chmod(0o600)
    os.chmod(folder / "full-0.private.png", 0o644)
    denied("UNSAFE_OR_INCOMPLETE_PNG",
           runner["private_classify"], folder)
    os.chmod(folder / "full-0.private.png", 0o600)
    (folder / "core-0.private.png").write_bytes(b"bad-private-fake-png")
    denied("CAPTURE_MATRIX_ALPHA_INCONCLUSIVE",
           runner["private_classify"], folder)

print("WULL_PRIVATE_STATIC_MATRIX_RUNNER_INERT_PASS")
