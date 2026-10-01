#!/usr/bin/env python3
"""INERT source-pinned static Wull silhouette band research, NOT a live mask.

Approximate the four source-measured PathCubics by conservative integer Rect
scanlines. Rotation covers all four output edges. No mask QML is emitted,
no native input is injected, and animated/halo pixels are NOT represented.
A production input region requires separate interaction/motion/scale QA.
"""
from __future__ import annotations

import hashlib
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BODY_PATH = "modules/abyss/companion/WaterDropletBody.qml"
REVIEWED_BODY_BLOB = "fc5b1c227026786ab553685bc170daff74e82517"
BASE_WIDTH = 76
BASE_HEIGHT = 92
# 400 equal-t subdivisions per original authored Bezier, analytical model
# ONLY for the exact source-pinned static non-animated 76x92 pose.
SUBDIVISIONS = 400
INSET = 1.7
HOST = {"top": (112, 98), "bottom": (112, 98),
        "left": (98, 112), "right": (98, 112)}
BODY_OFFSET = {"top": (18, 3), "bottom": (18, 3),
               "left": (3, 18), "right": (3, 18)}
# Normalized original source PathCubic controls. Tip and bottom start/end
# use absolute 2px / 3px literals from the original authored shape.
CUBICS = (
    (((.44, .18), (.12, .36)), (.12, .58)),
    (((.08, .83), (.28, None)), (.5, None)),
    (((.72, None), (.92, .83)), (.88, .58)),
    (((.88, .36), (.56, .18)), (.5, "tip")),
)


def source_ok(data: bytes) -> bool:
    if type(data) is not bytes:
        return False
    prefix = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(prefix + data).hexdigest() == REVIEWED_BODY_BLOB


def _xy(point):
    x, y = point
    if y is None:
        return x * BASE_WIDTH, BASE_HEIGHT - 3.0
    if y == "tip":
        return x * BASE_WIDTH, 2.0
    return x * BASE_WIDTH, y * BASE_HEIGHT


def cubic(a, p, q, b, t):
    """Pure cubic Bezier evaluation, 0<=t<=1, no animation state."""
    if not (type(t) in (int, float) and math.isfinite(t)
            and 0 <= t <= 1):
        raise ValueError("invalid_static_bezier_parameter")
    f = 1 - t
    return tuple(
        f ** 3 * a[i] + 3 * f * f * t * p[i]
        + 3 * f * t * t * q[i] + t ** 3 * b[i]
        for i in (0, 1))


def static_outline():
    """Returns a closed dense polygon of the exact STATIC source curve."""
    previous = (BASE_WIDTH * .5, 2.0)
    polygon = [previous]
    for controls, last in CUBICS:
        first, second = (_xy(point) for point in controls)
        end = _xy(last)
        polygon.extend(cubic(previous, first, second, end,
                             i / SUBDIVISIONS)
                       for i in range(1, SUBDIVISIONS + 1))
        previous = end
    if (len(polygon) != 1 + 4 * SUBDIVISIONS
            or any(not all(math.isfinite(n) for n in p) for p in polygon)
            or max(abs(a - b) for a, b in zip(polygon[0], polygon[-1])) > 1e-6):
        raise ValueError("unclosed_or_invalid_source_curve")
    return polygon


def intersections(polygon, y):
    xs = []
    for a, b in zip(polygon, polygon[1:]):
        if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
            xs.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
    return sorted(xs)


def top_interior_bands():
    """Interior-only, quantized 1px rows; merge identical consecutive spans.

    Three sub-row samples conservatively bound source-curve variation,
    plus an interior inset. This is an approximation, NOT exact visual
    shape/opacity support; the pulsating halo is deliberately excluded.
    """
    polygon = static_outline()
    rows = []
    for y in range(BASE_HEIGHT):
        left, right = -math.inf, math.inf
        for sample in (.01, .5, .99):
            xs = intersections(polygon, y + sample)
            if len(xs) != 2:
                break
            left = max(left, xs[0])
            right = min(right, xs[1])
        else:
            begin, end = math.ceil(left + INSET), math.floor(right - INSET)
            if end > begin:
                rows.append((begin, y, end - begin, 1))
    if not rows:
        raise ValueError("source_curve_has_no_safe_interior")
    merged = []
    for x, y, w, height in rows:
        if (merged and (merged[-1][0], merged[-1][2])
                == (x, w)
                and merged[-1][1] + merged[-1][3] == y):
            old = merged[-1]
            merged[-1] = (x, old[1], w, old[3] + height)
        else:
            merged.append((x, y, w, height))
    return merged


def rotated(rect, edge):
    """Rotate the 76x92 static item rectangle about its CENTER."""
    if (edge not in HOST or len(rect) != 4
            or any(type(v) is not int for v in rect)):
        raise ValueError("unreviewed_static_edge_or_rectangle")
    x, y, width, height = rect
    if (width <= 0 or height <= 0 or x < 0 or y < 0
            or x + width > BASE_WIDTH or y + height > BASE_HEIGHT):
        raise ValueError("source_rectangle_outside_static_body")
    if edge == "top":
        return rect
    if edge == "bottom":
        return (BASE_WIDTH - x - width, BASE_HEIGHT - y - height,
                width, height)
    if edge == "left":  # authored item rotation: +90 clockwise
        return (BASE_HEIGHT - y - height, x, height, width)
    return (y, BASE_WIDTH - x - width, height, width)


def edge_bands(edge):
    """Source-measured positions relative to ONE Wull host, not the screen."""
    if edge not in HOST:
        raise ValueError("unreviewed_static_edge")
    offset_x, offset_y = BODY_OFFSET[edge]
    width, height = HOST[edge]
    output = []
    for item in top_interior_bands():
        x, y, w, h = rotated(item, edge)
        bounded = (x + offset_x, y + offset_y, w, h)
        if (bounded[0] < 0 or bounded[1] < 0
                or bounded[0] + w > width
                or bounded[1] + h > height):
            raise ValueError("static_band_outside_source_measured_host")
        output.append(bounded)
    return output


def static_summary():
    """No exact path coordinates, raw pointer records, images or live QML."""
    top = top_interior_bands()
    area = sum(width * height for _, _, width, height in top)
    edges = {edge: len(edge_bands(edge))
             for edge in ("top", "bottom", "left", "right")}
    return {
        "kind": "inert_static_source_pinned_wull_curve_band_feasibility",
        "max_rectangles_per_edge": max(edges.values()),
        "rectangles_by_edge": edges,
        "conservative_interior_pixels": area,
        "static_body_bbox_pixels": BASE_WIDTH * BASE_HEIGHT,
        "animation_halo_scale_qualification": "not_run",
        "live_pointer_and_hover": "not_run",
        "production_changes": False,
    }


if __name__ == "__main__":
    original = (ROOT / BODY_PATH).read_bytes()
    if not source_ok(original):
        raise SystemExit("STOP: static silhouette source changed after review")
    # Only a safe summary: never generate a live QML mask or pointer event.
    import json
    print(json.dumps(static_summary(), sort_keys=True))
