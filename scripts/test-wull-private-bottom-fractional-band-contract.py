#!/usr/bin/env python3
"""FAKE ONLY. Five synthetic RGBA8 fractional-band pictures; NO real Qt/Git.

Tests both positive controls, five source-pinned categorical classifications,
unsafe image rejection, strict stage prefix and safe report-source envelope.
"""
import ast
import hashlib
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "scripts/wull-fixtures/paint-bottom-fractional-band/shell.qml"
MODEL = ROOT / "scripts/wull-private-bottom-fractional-band-model.py"
RUNNER = ROOT / "scripts/wull-manual-private-bottom-fractional-band.py"
BASE = ROOT / "scripts/wull-manual-private-bottom-inset.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
ORIGINAL = ROOT / "scripts/wull-fixtures/historical/pre-surface-attachment-companion.snapshot"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(FIXTURE) == "9203e9bf935c0a0ab995380dadf6a6ff27cc004d"
assert blob(MODEL) == "f1c91fc2742b21a1cee9cb2911be7c614e8aeee5"
assert blob(RUNNER) == "da49d48850374c6f6da0db7ef11883959baebce1"
assert blob(BASE) == "75f923b104c8409b3532a809c3ba62cfd5998e03"
assert blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(ORIGINAL) == "b5b01835a282458eba0d0268396ae2c350d919d2"
model = runpy.run_path(str(MODEL), run_name="fake_fractional_model")
runner = runpy.run_path(str(RUNNER), run_name="fake_fractional_runner")
previous = runpy.run_path(str(BASE), run_name="fake_fractional_previous")
alpha = runpy.run_path(str(ALPHA), run_name="fake_fractional_alpha")
fixture = FIXTURE.read_text(encoding="utf-8")
source = RUNNER.read_text(encoding="utf-8")
ast.parse(source)
assert runner["FIXTURE_BLOB"] == blob(FIXTURE)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["ALPHA_BLOB"] == blob(ALPHA)
assert runner["BASE_BLOB"] == blob(BASE)
assert runner["KEYS"] == model["MARGINS"] == (
    "m000", "m025", "m050", "m075", "m100")
assert model["MARGIN_VALUES"] == (0., .25, .5, .75, 1.)
assert model["CANVAS"] == (320, 300)
assert model["HOST_RECT"] == (72., 75.5, 168., 147.)
assert model["LAST_HOST_ROW"] == 221
assert model["INNER_SUPPORT_ROW"] == 220
assert fixture.count("AbyssCompanion {") == 1
assert fixture.count("FloatingWindow {") == 1
assert "root.sourceCradle.anchors.bottomMargin = margin" in fixture
assert "root.sourceCradle.anchors.bottomMargin = 0" in fixture
assert "readonly property var margins: [0, 0.25, 0.5, 0.75, 1]" in fixture
assert 'Math.round(margin * 100).toString().padStart(3, "0")' in fixture
assert 'Quickshell.env("WULL_FRACTIONAL_BAND_DIR")' in fixture
assert 'Qt.size(320, 300)' in fixture
assert "root.sourceAndPose()" in fixture
assert "root.marginVerified(margin)" in fixture
assert runner["stages"]() == [
    "BOOT", "PREPARED", "M000_REQUESTED", "M000_SAVED",
    "M025_REQUESTED", "M025_SAVED", "M050_REQUESTED", "M050_SAVED",
    "M075_REQUESTED", "M075_SAVED", "M100_REQUESTED", "M100_SAVED",
    "DONE"]
for token in (
    'previous["checked_sources"]()', 'core["stage_files"](directory)',
    'core["private_env"](', 'previous["secure_png"](',
    '"FRACTIONAL_CAPTURE_SET_INVALID"',
    '"FRACTIONAL_POSTRUN_SOURCE_CHANGED"',
    '"FRACTIONAL_BASELINE_UNQUALIFIED"',
    'if "--publish-sanitized-report" in sys.argv[1:]:',
    '"evidence_type": "owner_local_self_report_not_independently_replayed"',
    '"real_panel_visual": "untested"',
    '"production_mask_changed": False',
    'call("push", "origin", "HEAD:refs/heads/dev")',
    'signal.signal(signal.SIGTERM, stop_signal)',
    'checked_clone_layout()',
    '"FRACTIONAL_INHERITED_SOURCE_AUDIT_REJECTED"',
    '"https://github.com/llocphann/Hadalis.git"',
    'call("diff", "--cached", "--name-only") == relative',
    '"WULL_FRACTIONAL_BAND_DIR"',
    '"GIT_TERMINAL_PROMPT": "0"',
    '"GCM_INTERACTIVE": "never"',
    '"GIT_ASKPASS": "/bin/false"',
    '"SSH_ASKPASS": "/bin/false"',
    '"-c", "credential.interactive=never"',
    'stdin=subprocess.DEVNULL',
    'env=no_prompt',
):
    assert token in source, token
assert "force=True" not in source and "git push --force" not in source
assert "print(logpath)" not in source
assert "print(logpath.read_text" not in source


def denied(exc, reason, fn, *args):
    try:
        fn(*args)
    except exc as error:
        assert str(error) == reason, (str(error), reason)
    else:
        raise AssertionError("Unsafe synthetic state accepted: " + reason)


def chunk(tag, raw):
    return (struct.pack(">I", len(raw)) + tag + raw +
            struct.pack(">I", zlib.crc32(tag + raw) & 0xffffffff))


def png(points):
    w, h = model["CANVAS"]
    data = bytearray()
    for y in range(h):
        data.append(0)
        for x in range(w):
            data.extend((45, 100, 130, 255) if (x, y) in points
                        else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(bytes(data), 9)) +
            chunk(b"IEND", b""))


def changed(source, key, replacement):
    alt = dict(source)
    alt[key] = replacement
    return alt


inside = {(x, y) for x in range(145, 155)
          for y in range(135, 144)}
outside = {(251, 152)}
contact = {(x, y) for x in range(145, 152) for y in (220, 221)}
near = {(x, 220) for x in range(145, 152)}
images = {
    "m000": png(inside | outside | contact),
    "m025": png(inside | outside | contact),
    "m050": png(inside | contact),
    "m075": png(inside | near),
    "m100": png(inside | near),
}
result = model["classify"](images, alpha)
assert result["exterior"] == dict(
    m000=True, m025=True, m050=False, m075=False, m100=False)
assert result["contact"] == dict(
    m000=True, m025=True, m050=True, m075=False, m100=False)
assert result["fractional_joint_candidates"] == ("m050",)
assert result["virtual_panel_band_not_real_connection"] is True
assert result["production_mask_changed"] is False
assert model["classify"](
    changed(images, "m100", png(inside | contact)), alpha)["contact"]["m100"]

denied(model["Unqualified"], "FIVE_EXACT_ORIGINAL_FULL_CAPTURES_REQUIRED",
       model["classify"], {"m000": images["m000"]}, alpha)
denied(model["Unqualified"], "ORIGINAL_M0_EXTERIOR_BASELINE_NOT_REPRODUCED",
       model["classify"],
       changed(images, "m000", png(inside | contact)), alpha)
denied(model["Unqualified"], "ORIGINAL_M1_ZERO_EXTERIOR_NOT_REPRODUCED",
       model["classify"],
       changed(images, "m100", png(inside | outside)), alpha)
denied(model["Unqualified"], "ORIGINAL_M0_BOUNDARY_BAND_NOT_REPRODUCED",
       model["classify"],
       changed(images, "m000", png(inside | outside | near)), alpha)
denied(model["Unqualified"], "ORIGINAL_PRIVATE_PNG_INVALID",
       model["classify"], changed(images, "m050", b"bad"), alpha)
denied(model["Unqualified"], "PRIVATE_PAINT_REACHES_CANVAS_EDGE",
       model["classify"],
       changed(images, "m050", png(inside | {(0, 0)})), alpha)
denied(model["Unqualified"], "ORIGINAL_FULL_INTERIOR_PAINT_MISSING",
       model["classify"], changed(images, "m075", png(set())), alpha)

valid = "\n".join(
    "WULL_FRACTIONAL_BAND_STAGE=" + token
    for token in runner["stages"]())
assert runner["checked_stage_log"](valid) == (runner["stages"](), [])
denied(runner["Stop"], "FRACTIONAL_STAGE_INVALID",
       runner["checked_stage_log"],
       "WULL_FRACTIONAL_BAND_STAGE=M050_SAVED")
denied(runner["Stop"], "FRACTIONAL_STAGE_INVALID",
       runner["checked_stage_log"],
       "WULL_FRACTIONAL_BAND_STAGE=BOOT\n"
       "WULL_FRACTIONAL_BAND_STAGE=M025_REQUESTED")
denied(runner["Stop"], "FRACTIONAL_STAGE_INVALID",
       runner["checked_stage_log"],
       "WULL_FRACTIONAL_BAND_STAGE=BOOT\n"
       "WULL_FRACTIONAL_BAND_FAILURE=BOTTOM_INSET_TIMEOUT\n"
       "WULL_FRACTIONAL_BAND_STAGE=PREPARED")
denied(runner["Stop"], "FRACTIONAL_FAILURE_INVALID",
       runner["checked_stage_log"],
       "WULL_FRACTIONAL_BAND_FAILURE=ARBITRARY_FAILURE")

with tempfile.TemporaryDirectory(prefix="wull-fractional-FAKE-") as tmp:
    directory = Path(tmp)
    for key, raw in images.items():
        file = directory / (key + ".private.png")
        file.write_bytes(raw)
        file.chmod(0o600)
    assert runner["private_classify"](directory, previous) == result
    extra = directory / "extra.private.png"
    extra.write_bytes(images["m100"])
    extra.chmod(0o600)
    denied(runner["Stop"], "FRACTIONAL_CAPTURE_SET_INVALID",
           runner["private_classify"], directory, previous)
    extra.unlink()
    victim = directory / "m000.private.png"
    victim.chmod(0o644)
    denied(previous["Stop"], "BOTTOM_INSET_PNG_UNSAFE",
           runner["private_classify"], directory, previous)
    victim.chmod(0o600)
    victim.write_bytes(b"invalid")
    denied(runner["Stop"], "FRACTIONAL_ALPHA_UNQUALIFIED",
           runner["private_classify"], directory, previous)

# Mirror the inherited immutable audit's clone layout before any real Qt.
with tempfile.TemporaryDirectory(prefix="wull-paint-canary.") as tmp:
    scratch = Path(tmp)
    clone = scratch / "repo"
    clone.mkdir(mode=0o700)
    runner["checked_clone_layout"](clone, clone)
    denied(runner["Stop"], "FRACTIONAL_CLONE_LAYOUT_INVALID",
           runner["checked_clone_layout"], clone, scratch)
    wrong_name = scratch / "Hadalis"
    wrong_name.mkdir(mode=0o700)
    denied(runner["Stop"], "FRACTIONAL_CLONE_LAYOUT_INVALID",
           runner["checked_clone_layout"], wrong_name, wrong_name)
    clone.chmod(0o755)
    denied(runner["Stop"], "FRACTIONAL_CLONE_LAYOUT_INVALID",
           runner["checked_clone_layout"], clone, clone)
    clone.chmod(0o700)
    scratch.chmod(0o755)
    denied(runner["Stop"], "FRACTIONAL_CLONE_LAYOUT_INVALID",
           runner["checked_clone_layout"], clone, clone)
    scratch.chmod(0o700)

with tempfile.TemporaryDirectory(prefix="wull-fractional-wrong-parent.") as tmp:
    wrong_parent = Path(tmp) / "repo"
    wrong_parent.mkdir(mode=0o700)
    denied(runner["Stop"], "FRACTIONAL_CLONE_LAYOUT_INVALID",
           runner["checked_clone_layout"], wrong_parent, wrong_parent)

print("WULL_PRIVATE_FRACTIONAL_BAND_INERT_PASS")
