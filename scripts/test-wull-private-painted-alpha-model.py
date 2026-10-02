#!/usr/bin/env python3
"""Pure fake PNG fixtures, bad payload and privacy contract. No Qt execution."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/wull-private-painted-alpha-model.py"


def blob(path):
    raw = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


assert blob(SOURCE) == "fa9e7c2af87ee830336988fa7060e2720e816ed0"
m = runpy.run_path(str(SOURCE), run_name="wull_fake_alpha_contract")
assert m["PNG_SIGNATURE"] == b"\x89PNG\r\n\x1a\n"
assert m["MAX_DIMENSION"] <= 512
assert m["MAX_PNG_BYTES"] <= 1024 * 1024
assert m["ALPHA_THRESHOLD"] >= 16
assert m["VARIANTS"] == ("production_composite", "body_only_shadow")
assert m["PHASES"] == ("stretch", "release")


def chunk(tag, payload):
    return (struct.pack(">I", len(payload)) + tag + payload +
            struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff))


def make_png(points, mode=0, width=16, height=16):
    """Generate independent RGBA8 PNGs using all five supported filters."""
    last = bytes(width * 4)
    scanlines = bytearray()
    for y in range(height):
        original = bytearray(width * 4)
        for x in range(width):
            if (x, y) in points:
                original[4*x:4*x+4] = bytes((110, 120, 130, 255))
        filtered = bytearray(original)
        if mode:
            for i, byte in enumerate(original):
                left = original[i-4] if i >= 4 else 0
                above = last[i]
                upper_left = last[i-4] if i >= 4 else 0
                if mode == 1:
                    predictor = left
                elif mode == 2:
                    predictor = above
                elif mode == 3:
                    predictor = (left + above) // 2
                else:
                    p = left + above - upper_left
                    da, db, dc = (
                        abs(p-left), abs(p-above), abs(p-upper_left))
                    predictor = (left if da <= db and da <= dc
                                 else above if db <= dc else upper_left)
                filtered[i] = (byte - predictor) & 255
        scanlines.extend(bytes((mode,)) + filtered)
        last = bytes(original)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (m["PNG_SIGNATURE"] + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(bytes(scanlines))) +
            chunk(b"IEND", b""))


core = {(x, y) for x in range(6, 10) for y in range(6, 10)}
outside = core | {(3, 7)}
near_edge = core | {(1, 7)}
inside_png = make_png(core)
outside_png = make_png(outside)
blank_png = make_png(set())
edge_png = make_png(near_edge)


def frame(edge="top", scale=1, phase="stretch",
          variant="production_composite"):
    return {
        "edge": edge, "scale": scale, "phase": phase,
        "variant": variant, "host_rect": [5, 5, 6, 6],
        "captured_during_phase": True,
        "mapped_change_witness": True,
    }


for mode in range(5):
    png = make_png(outside, mode=mode)
    dims = m["png_alpha"](png)
    assert dims[0:2] == (16, 16)
    assert dims[2][7 * 16 + 3] == 255
    observed = m["classify_frame"](frame(), png)
    assert observed["outside_host_alpha_observed"] is True

assert m["classify_frame"](frame(), inside_png)[
    "outside_host_alpha_observed"] is False
assert m["classify_frame"](frame(scale=1.0), outside_png)["scale"] == 1.0
assert "host_rect" not in m["classify_frame"](frame(), outside_png)


def rejected(code, f, *args):
    try:
        f(*args)
    except m["InvalidCapture"] as ex:
        assert str(ex) == code, (str(ex), code)
    else:
        raise AssertionError("Unsafe private PNG/geometry accepted: " + code)


rejected("PAINTED_CORE_NOT_ESTABLISHED",
         m["classify_frame"], frame(), blank_png)
rejected("PAINT_REACHES_CAPTURE_CANVAS_EDGE",
         m["classify_frame"], frame(), edge_png)
rejected("PNG_SIGNATURE_INVALID",
         m["png_alpha"], b"not-a-png")
rejected("PNG_BYTES_UNREVIEWED",
         m["png_alpha"], inside_png * 30000)
rejected("PNG_CRC_INVALID",
         m["png_alpha"], inside_png[:-7] + b"broken!")
rejected("PNG_TRUNCATED",
         m["png_alpha"], inside_png[:-4])
rejected("PNG_RGBA_FORMAT_REQUIRED",
         m["png_alpha"], make_png(core, width=513))
rejected("PNG_FILTER_INVALID",
         m["png_alpha"],
         m["PNG_SIGNATURE"] +
         chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0)) +
         chunk(b"IDAT", zlib.compress(
             b"\x05" + bytes(16*4) +
             (b"\x00" + bytes(16*4)) * 15)) +
         chunk(b"IEND", b""))
rejected("HOST_NOT_FULLY_ON_CAPTURE_CANVAS",
         m["classify_frame"],
         {**frame(), "host_rect": [1, 5, 6, 6]}, inside_png)
rejected("HOST_RECT_INVALID",
         m["classify_frame"],
         {**frame(), "host_rect": [5, float("nan"), 6, 6]}, inside_png)
rejected("FRAME_PHASE_OR_SOURCE_UNVERIFIED",
         m["classify_frame"], frame(scale=True), inside_png)
rejected("FRAME_PHASE_OR_SOURCE_UNVERIFIED",
         m["classify_frame"],
         {**frame(), "mapped_change_witness": False}, inside_png)
rejected("FRAME_PHASE_OR_SOURCE_UNVERIFIED",
         m["classify_frame"],
         {**frame(), "captured_during_phase": "true"}, inside_png)
rejected("FRAME_FIELDS_INVALID",
         m["classify_frame"],
         {**frame(), "private_path": "/home/private/frame.png"}, inside_png)

records = []
for edge in m["EDGES"]:
    for scale in m["SCALES"]:
        for phase in m["PHASES"]:
            for variant in m["VARIANTS"]:
                png = (outside_png if variant == "production_composite"
                       and edge == "top" else inside_png)
                records.append(m["classify_frame"](
                    frame(edge, scale, phase, variant), png))
summary = m["summarize"](records)
assert summary["case_count"] == 48
assert summary["status"] == "sampled_alpha_classification_only"
assert summary["body_shadow_not_identical_to_production"] is True
assert summary["painted_core_hit_testing"] == "not_proven"
assert summary["production_mask_changed"] is False
assert summary["categories"]["1.0"]["stretch"][
    "production_composite_outside_host_edges"] == ["top"]
assert summary["categories"]["1.0"]["stretch"][
    "body_only_shadow_outside_host_edges"] == []
string = json.dumps(summary)
for forbidden in (
    "/home/", "frame.png", "pixels", "host_rect", "image", "coords",
    "private_path", "RGBA", "alpha_bytes",
):
    assert forbidden not in string
rejected("CAPTURE_MATRIX_INCOMPLETE",
         m["summarize"], records[:-1])
dupe = copy.deepcopy(records)
dupe[1] = copy.deepcopy(dupe[0])
rejected("CAPTURE_CASE_INVALID",
         m["summarize"], dupe)
bad = copy.deepcopy(records)
bad[0]["outside_host_alpha_observed"] = "true"
rejected("CAPTURE_CASE_INVALID",
         m["summarize"], bad)
bad = copy.deepcopy(records)
bad[0]["coordinates"] = [7, 9]
rejected("CAPTURE_RESULT_FIELDS_INVALID",
         m["summarize"], bad)
print("WULL_PRIVATE_PAINTED_ALPHA_INERT_PASS")
