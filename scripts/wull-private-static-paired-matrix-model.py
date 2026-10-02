#!/usr/bin/env python3
"""INERT 4-edge x 3-scale fixed-pose paired PNG classifier.

Pure geometry + bounded original-alpha parser. No files, Qt, screenshots or
publication. Observed original full composite and a SAME-SESSION but altered
core-only sibling-visibility state are deliberately classified separately.
This is NOT live input/clipping, pixel causality or dynamic animation.
"""
from pathlib import Path
import math
import runpy

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_ALPHA = "scripts/wull-private-painted-alpha-model.py"
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
EDGES = ("top", "right", "bottom", "left")
SCALES = (0.65, 1.0, 1.5)
CANVAS = (320, 300)
HOST_ORIGIN = (100, 100)
MIN_INSIDE_PIXELS = 8


class Unqualified(ValueError):
    """Fixed error categories only; no private PNG content in exceptions."""


def reject(category):
    raise Unqualified(category)


def spec(index):
    if type(index) is not int or not 0 <= index < 12:
        reject("CASE_INDEX_INVALID")
    edge, scale = EDGES[index // 3], SCALES[index % 3]
    host_w, host_h = ((98, 112) if edge in ("left", "right") else (112, 98))
    x, y = HOST_ORIGIN
    # QQuickItem scale origin is its center in the source-pinned fixture.
    left = x + host_w * (1 - scale) / 2
    top = y + host_h * (1 - scale) / 2
    return (edge, scale, (left, top, host_w * scale, host_h * scale))


def decoded(raw, parser):
    try:
        width, height, alpha = parser["png_alpha"](raw)
    except (ValueError, TypeError):
        reject("PRIVATE_PNG_INVALID")
    if (width, height) != CANVAS:
        reject("PRIVATE_CAPTURE_DIMENSIONS_INVALID")
    return alpha


def classify(index, full_raw, core_raw, parser):
    # The caller owns both private captures and exact-source verification.
    # Accept only complete original parser output; no best-effort fallback.
    edge, scale, host_rect = spec(index)
    if type(parser) is not dict or parser.get("ALPHA_THRESHOLD") != 24 or (
            parser.get("EDGE_MARGIN") != 2):
        reject("PINNED_ALPHA_PARSER_REQUIRED")
    full = decoded(full_raw, parser)
    core = decoded(core_raw, parser)
    x0, y0, w, h = host_rect
    width, height = CANVAS
    margin = parser["EDGE_MARGIN"]
    if (x0 < 2 * margin or y0 < 2 * margin
            or x0 + w > width - 2 * margin
            or y0 + h > height - 2 * margin
            or not all(map(math.isfinite, host_rect))):
        reject("HOST_GEOMETRY_OR_CANVAS_INVALID")
    full_inside = core_inside = 0
    full_out = core_out = shared_out = 0
    threshold = parser["ALPHA_THRESHOLD"]
    for py in range(height):
        for px in range(width):
            offset = py * width + px
            a = full[offset] >= threshold
            b = core[offset] >= threshold
            if not a and not b:
                continue
            if (px < margin or py < margin
                    or px >= width - margin or py >= height - margin):
                reject("CAPTURE_PAINT_REACHES_CANVAS_EDGE")
            inside = (x0 <= px + 0.5 < x0 + w
                      and y0 <= py + 0.5 < y0 + h)
            if inside:
                full_inside += int(a)
                core_inside += int(b)
            else:
                full_out += int(a)
                core_out += int(b)
                shared_out += int(a and b)
    if full_inside < MIN_INSIDE_PIXELS or core_inside < MIN_INSIDE_PIXELS:
        reject("MISSING_INSIDE_PAINT")
    return {
        "edge": edge, "scale": scale,
        "composite_outside_host": full_out > 0,
        "source_core_outside_host": core_out > 0,
        "same_pixel_exterior_overlap": shared_out > 0,
    }


def summarize(rows):
    """Exactly twelve strictly ordered categorical case results."""
    if type(rows) is not list or len(rows) != 12:
        reject("INCOMPLETE_PAIRED_MATRIX")
    for i, case in enumerate(rows):
        edge, scale, unused = spec(i)
        if (type(case) is not dict or set(case) != {
                "edge", "scale", "composite_outside_host",
                "source_core_outside_host", "same_pixel_exterior_overlap"}
                or case["edge"] != edge
                or type(case["scale"]) not in (int, float)
                or case["scale"] != scale
                or any(type(case[key]) is not bool for key in (
                    "composite_outside_host", "source_core_outside_host",
                    "same_pixel_exterior_overlap"))
                or case["same_pixel_exterior_overlap"] and not (
                    case["composite_outside_host"]
                    and case["source_core_outside_host"])):
            reject("PAIRED_MATRIX_CASE_INVALID")
    return {
        "kind": "private_static_paired_full_original_core_alpha",
        "qualified_case_count": 12,
        "session_source": "one_private_qt_process",
        "captures_sequential_not_simultaneous": True,
        "core_scene_altered_sibling_visibility": True,
        "compositor_clip_and_input": "not_tested",
        "dynamic_painted_motion": "not_tested",
        "global_spring_extrema": "not_proven",
        "production_mask_changed": False,
        "cases": [{
            "edge": case["edge"],
            "scale": case["scale"],
            "composite_outside_host": case["composite_outside_host"],
            "source_core_outside_host": case["source_core_outside_host"],
            "same_pixel_exterior_overlap": case["same_pixel_exterior_overlap"],
        } for case in rows],
    }
