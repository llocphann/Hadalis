#!/usr/bin/env python3
"""INERT classification for private Wull captured PNG alpha masks.

No QML, Qt, compositor, screenshot access, filesystem scan, or publication.
A composite capture CANNOT identify whether an exterior pixel is core,
halo or ripple. A separately staged body-only shadow is not production.
"""
import math
import struct
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_PNG_BYTES = 1024 * 1024
MAX_DIMENSION = 512
MIN_INTERIOR_PIXELS = 8
ALPHA_THRESHOLD = 24
EDGE_MARGIN = 2
EDGES = ("top", "right", "bottom", "left")
SCALES = (0.65, 1.0, 1.5)
PHASES = ("stretch", "release")
VARIANTS = ("production_composite", "body_only_shadow")
FRAME_FIELDS = frozenset((
    "edge", "scale", "phase", "variant", "host_rect",
    "captured_during_phase", "mapped_change_witness",
))


class InvalidCapture(ValueError):
    """Fixed error category only. Never attach private frame contents."""


def fail(reason):
    raise InvalidCapture(reason)


def png_alpha(raw):
    """Decode bounded 8-bit noninterlaced RGBA PNG with all five PNG filters."""
    if type(raw) is not bytes or not 0 < len(raw) <= MAX_PNG_BYTES:
        fail("PNG_BYTES_UNREVIEWED")
    if not raw.startswith(PNG_SIGNATURE):
        fail("PNG_SIGNATURE_INVALID")
    pos = len(PNG_SIGNATURE)
    width = height = None
    idat = bytearray()
    seen_idat = seen_end = False
    state = "start"
    while pos < len(raw):
        if len(raw) - pos < 12:
            fail("PNG_TRUNCATED")
        length = struct.unpack_from(">I", raw, pos)[0]
        pos += 4
        typ = raw[pos:pos + 4]
        pos += 4
        if length > MAX_PNG_BYTES or pos + length + 4 > len(raw):
            fail("PNG_CHUNK_INVALID")
        data = raw[pos:pos + length]
        pos += length
        crc = struct.unpack_from(">I", raw, pos)[0]
        pos += 4
        if zlib.crc32(typ + data) & 0xffffffff != crc:
            fail("PNG_CRC_INVALID")
        if typ == b"IHDR":
            if state != "start" or length != 13:
                fail("PNG_HEADER_INVALID")
            width, height, depth, color, comp, filt, interlace = struct.unpack(
                ">IIBBBBB", data)
            if (not 1 <= width <= MAX_DIMENSION
                    or not 1 <= height <= MAX_DIMENSION
                    or (depth, color, comp, filt, interlace) != (8, 6, 0, 0, 0)):
                fail("PNG_RGBA_FORMAT_REQUIRED")
            state = "after_header"
        elif typ == b"IDAT":
            if state not in ("after_header", "idat") or seen_end:
                fail("PNG_IDAT_ORDER_INVALID")
            idat.extend(data)
            if len(idat) > MAX_PNG_BYTES:
                fail("PNG_IDAT_TOO_LARGE")
            state = "idat"
            seen_idat = True
        elif typ == b"IEND":
            if length != 0 or not seen_idat or seen_end or pos != len(raw):
                fail("PNG_END_INVALID")
            seen_end = True
            break
        elif typ in (b"sRGB", b"gAMA", b"pHYs", b"iCCP", b"cHRM",
                     b"tEXt", b"zTXt", b"iTXt", b"tIME"):
            if state == "start" or state == "idat":
                fail("PNG_METADATA_ORDER_INVALID")
        else:
            fail("PNG_UNSUPPORTED_CHUNK")
    if not seen_end or width is None or not idat:
        fail("PNG_INCOMPLETE")
    stride = width * 4
    expected = height * (stride + 1)
    decoder = zlib.decompressobj()
    try:
        unpacked = decoder.decompress(bytes(idat), expected + 1)
        if (len(unpacked) != expected or decoder.unconsumed_tail
                or not decoder.eof or decoder.unused_data
                or decoder.flush()):
            fail("PNG_DECOMPRESSED_SIZE_INVALID")
    except zlib.error:
        fail("PNG_ZLIB_INVALID")
    alphas = bytearray(width * height)
    prev = bytearray(stride)
    offset = 0
    for y in range(height):
        filter_type = unpacked[offset]
        offset += 1
        if filter_type > 4:
            fail("PNG_FILTER_INVALID")
        row = bytearray(unpacked[offset:offset + stride])
        offset += stride
        for n in range(stride):
            left = row[n - 4] if n >= 4 else 0
            up = prev[n]
            upper_left = prev[n - 4] if n >= 4 else 0
            if filter_type == 1:
                row[n] = (row[n] + left) & 255
            elif filter_type == 2:
                row[n] = (row[n] + up) & 255
            elif filter_type == 3:
                row[n] = (row[n] + (left + up) // 2) & 255
            elif filter_type == 4:
                p = left + up - upper_left
                da, db, dc = abs(p - left), abs(p - up), abs(p - upper_left)
                predictor = (left if da <= db and da <= dc
                             else up if db <= dc else upper_left)
                row[n] = (row[n] + predictor) & 255
        alphas[y * width:(y + 1) * width] = row[3::4]
        prev = row
    return width, height, alphas


def classify_frame(frame, png):
    if type(frame) is not dict or set(frame) != FRAME_FIELDS:
        fail("FRAME_FIELDS_INVALID")
    edge, scale, phase, variant = (frame[k] for k in (
        "edge", "scale", "phase", "variant"))
    if (edge not in EDGES or type(scale) not in (int, float)
            or scale not in SCALES or phase not in PHASES
            or variant not in VARIANTS
            or frame["captured_during_phase"] is not True
            or frame["mapped_change_witness"] is not True):
        fail("FRAME_PHASE_OR_SOURCE_UNVERIFIED")
    rect = frame["host_rect"]
    if (type(rect) is not list or len(rect) != 4
            or any(type(value) not in (float, int)
                   or not math.isfinite(value) for value in rect)):
        fail("HOST_RECT_INVALID")
    x, y, w, h = rect
    if w <= 0 or h <= 0:
        fail("HOST_RECT_INVALID")
    image_w, image_h, alphas = png_alpha(png)
    if (x < EDGE_MARGIN or y < EDGE_MARGIN
            or x + w > image_w - EDGE_MARGIN
            or y + h > image_h - EDGE_MARGIN):
        fail("HOST_NOT_FULLY_ON_CAPTURE_CANVAS")
    inside = outside = 0
    for py in range(image_h):
        for px in range(image_w):
            if alphas[py * image_w + px] < ALPHA_THRESHOLD:
                continue
            if (px < EDGE_MARGIN or py < EDGE_MARGIN
                    or px >= image_w - EDGE_MARGIN
                    or py >= image_h - EDGE_MARGIN):
                fail("PAINT_REACHES_CAPTURE_CANVAS_EDGE")
            if x <= px + 0.5 < x + w and y <= py + 0.5 < y + h:
                inside += 1
            else:
                outside += 1
    if inside < MIN_INTERIOR_PIXELS:
        fail("PAINTED_CORE_NOT_ESTABLISHED")
    return {
        "edge": edge, "scale": float(scale), "phase": phase,
        "variant": variant,
        "outside_host_alpha_observed": outside > 0,
    }


def summarize(cases):
    """Only fixed categorical outcomes: never pixels, rects or paths."""
    if type(cases) is not list or len(cases) != 48:
        fail("CAPTURE_MATRIX_INCOMPLETE")
    expected = {(edge, scale, phase, variant) for edge in EDGES
                for scale in SCALES for phase in PHASES
                for variant in VARIANTS}
    seen = {}
    for case in cases:
        if (type(case) is not dict or set(case) != {
                "edge", "scale", "phase", "variant",
                "outside_host_alpha_observed"}):
            fail("CAPTURE_RESULT_FIELDS_INVALID")
        edge, scale, phase, variant = (
            case[name] for name in ("edge", "scale", "phase", "variant"))
        key = edge, scale, phase, variant
        if (key not in expected or key in seen
                or type(case["outside_host_alpha_observed"]) is not bool):
            fail("CAPTURE_CASE_INVALID")
        seen[key] = case["outside_host_alpha_observed"]
    if set(seen) != expected:
        fail("CAPTURE_CASES_MISSING")
    # The shadow variant is not the exact production renderer; never
    # combine, subtract, or attribute its alpha to the composite capture.
    return {
        "status": "sampled_alpha_classification_only",
        "case_count": 48,
        "captured_renderers_not_frame_synchronized": True,
        "body_shadow_not_identical_to_production": True,
        "painted_core_hit_testing": "not_proven",
        "compositor_clipping": "not_tested",
        "global_motion_extrema": "not_proven",
        "production_mask_changed": False,
        "categories": {
            str(scale): {
                phase: {
                    variant + "_outside_host_edges": [
                        edge for edge in EDGES
                        if seen[edge, scale, phase, variant]]
                    for variant in VARIANTS
                } for phase in PHASES
            } for scale in SCALES
        },
    }
