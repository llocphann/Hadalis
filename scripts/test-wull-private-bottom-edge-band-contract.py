#!/usr/bin/env python3
"""FAKE ONLY: original FULL BOTTOM×1.5 virtual panel edge-band regression.

Synthetic in-memory RGBA8 PNGs and 0600 temporary FAKE files only. NO Qt,
desktop screenshots, compositor, native input, Git mutation or publication.
"""
import ast
import hashlib
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "scripts/wull-private-bottom-edge-band-model.py"
RUNNER = ROOT / "scripts/wull-manual-private-bottom-edge-band.py"
BASE = ROOT / "scripts/wull-manual-private-bottom-inset.py"
ALPHA = ROOT / "scripts/wull-private-painted-alpha-model.py"
FIXTURE = ROOT / "scripts/wull-fixtures/paint-bottom-inset/shell.qml"


def blob(path):
    data = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data
    ).hexdigest()


assert blob(MODEL) == "dbfb226a4fa5f53154df25a6bd69d90674372a0f"
assert blob(RUNNER) == "a629324e7107882475dcf4cedbff208945c7eddf"
assert blob(BASE) == "75f923b104c8409b3532a809c3ba62cfd5998e03"
assert blob(ALPHA) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
assert blob(FIXTURE) == "45fc03e743d08a996c763c491e0d2b42d22f75ba"

model = runpy.run_path(str(MODEL), run_name="fake_original_bottom_band")
runner = runpy.run_path(str(RUNNER), run_name="fake_original_bottom_band_runner")
previous = runpy.run_path(str(BASE), run_name="fake_original_margin_base")
alpha = runpy.run_path(str(ALPHA), run_name="fake_original_rgba8")
source = RUNNER.read_text(encoding="utf-8")
fixture = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
assert runner["BASE_BLOB"] == blob(BASE)
assert runner["MODEL_BLOB"] == blob(MODEL)
assert runner["ALPHA_BLOB"] == blob(ALPHA)
assert previous["FIXTURE_BLOB"] == blob(FIXTURE)
assert model["ALPHA_BLOB"] == blob(ALPHA)
assert runner["MARGINS"] == model["MARGINS"] == (0, 1, 2, 3)
assert model["LAST_HOST_ROW"] == 221
assert model["INNER_SUPPORT_ROW"] == 220
assert model["CRADLE_CENTER_X"] == (119, 192)
assert model["MIN_RUN"] == 3
assert model["HOST_RECT"] == (72.0, 75.5, 168.0, 147.0)
assert previous["expected_stages"]() == [
    "BOOT", "PREPARED",
    "M0_REQUESTED", "M0_SAVED",
    "M1_REQUESTED", "M1_SAVED",
    "M2_REQUESTED", "M2_SAVED",
    "M3_REQUESTED", "M3_SAVED", "DONE"
]
for token in (
    'previous["checked_sources"]()', 'previous["private_run"](core)',
    'previous["secure_png"](', 'ROOT.parent / "bottom-inset"',
    '"EDGE_BAND_CAPTURE_SET_INVALID"',
    'qualified_previous["exterior_by_margin"][1] is False',
    'results["candidate_margin1_no_boundary_band_signal"]',
    'print("REAL_PANEL_VISUAL_CONNECTION=UNTESTED")',
    'print("PRODUCTION_MASK_CHANGED=NO")',
    '"--acknowledge-private-original-bottom-edge-band"',
):
    assert token in source, token
assert fixture.count("AbyssCompanion {") == 1
assert fixture.count("FloatingWindow {") == 1
assert 'root.sourceCradle.anchors.bottomMargin = margin' in fixture
assert 'root.sourceCradle.anchors.bottomMargin = 0' in fixture
assert 'Qt.size(320, 300)' in fixture
for forbidden in ('"git", "push"', '"git", "commit"', "print(raw)",
                  "print(directory)", "print(log.read_text"):
    assert forbidden not in source, forbidden


def denied(error_cls, expected, fn, *args):
    try:
        fn(*args)
    except error_cls as err:
        assert str(err) == expected, (str(err), expected)
    else:
        raise AssertionError("Unsafe FAKE accepted: " + expected)


def changed(original, margin, replacement):
    new = dict(original)
    new[margin] = replacement
    return new


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xffffffff)


def png(points):
    w, h = model["CANVAS"]
    image = bytearray()
    for y in range(h):
        image.append(0)
        for x in range(w):
            image.extend(
                (45, 100, 130, 255) if (x, y) in points
                else (0, 0, 0, 0))
    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (alpha["PNG_SIGNATURE"] + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(image), 9))
            + chunk(b"IEND", b""))


inside = {(x, y) for x in range(145, 155)
          for y in range(135, 144)}
outside = {(251, 152)}
contact = {(x, y) for x in range(145, 152) for y in (220, 221)}
one_row_away = {(x, 220) for x in range(145, 152)}
m0 = png(inside | outside | contact)
m1 = png(inside | one_row_away)
m2 = png(inside | contact)
m3 = png(inside)
images = {0: m0, 1: m1, 2: m2, 3: m3}
result = model["classify"](images, alpha)
assert result["inner_boundary_band_by_margin"] == {
    0: True, 1: False, 2: True, 3: False}
assert result["margin0_exterior_positive"] is True
assert result["margin1_exterior_negative"] is True
assert result["candidate_margin1_no_boundary_band_signal"] is True
assert result["virtual_panel_only_not_real_visual_connection"] is True
assert result["production_mask_changed"] is False
assert result["animated_extrema"] == "not_tested"
positive_m1 = model["classify"](
    changed(images, 1, png(inside | contact)), alpha)
assert positive_m1["inner_boundary_band_by_margin"][1] is True
assert positive_m1["candidate_margin1_no_boundary_band_signal"] is False

denied(model["Unqualified"], "EXACT_FOUR_ORIGINAL_MARGIN_CAPTURES_REQUIRED",
       model["classify"], {0: m0, 1: m1}, alpha)
denied(model["Unqualified"],
       "ORIGINAL_MARGIN0_EXTERIOR_BASELINE_NOT_REPRODUCED",
       model["classify"], changed(images, 0, png(inside | contact)), alpha)
denied(model["Unqualified"],
       "MARGIN1_ZERO_EXTERIOR_CANDIDATE_NOT_REPRODUCED",
       model["classify"],
       changed(images, 1, png(inside | outside | one_row_away)), alpha)
denied(model["Unqualified"],
       "ORIGINAL_MARGIN0_EDGE_BAND_CONTACT_UNESTABLISHED",
       model["classify"],
       changed(images, 0, png(inside | outside | one_row_away)), alpha)
denied(model["Unqualified"], "ORIGINAL_PRIVATE_PNG_INVALID",
       model["classify"], changed(images, 2, b"bad"), alpha)
denied(model["Unqualified"], "PRIVATE_PAINT_REACHES_CANVAS_EDGE",
       model["classify"], changed(images, 2, png(inside | {(0, 0)})), alpha)
denied(model["Unqualified"], "ORIGINAL_FULL_INTERIOR_PAINT_MISSING",
       model["classify"], changed(images, 3, png(set())), alpha)

with tempfile.TemporaryDirectory(prefix="wull-band-fake-") as tmp:
    directory = Path(tmp)
    for margin, raw in images.items():
        target = directory / ("m" + str(margin) + ".private.png")
        target.write_bytes(raw)
        target.chmod(0o600)
    assert runner["private_classify"](directory, previous) == result
    extra = directory / "extra.private.png"
    extra.write_bytes(m3)
    extra.chmod(0o600)
    denied(runner["Stop"], "EDGE_BAND_CAPTURE_SET_INVALID",
           runner["private_classify"], directory, previous)
    extra.unlink()
    victim = directory / "m0.private.png"
    victim.chmod(0o644)
    denied(previous["Stop"], "BOTTOM_INSET_PNG_UNSAFE",
           runner["private_classify"], directory, previous)
    victim.chmod(0o600)
    victim.write_bytes(b"corrupt")
    denied(runner["Stop"], "EDGE_BAND_ALPHA_INCONCLUSIVE",
           runner["private_classify"], directory, previous)

print("WULL_PRIVATE_BOTTOM_EDGE_BAND_INERT_PASS")
