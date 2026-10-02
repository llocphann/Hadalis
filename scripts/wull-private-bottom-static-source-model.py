#!/usr/bin/env python3
"""PURE INERT original BOTTOM×1.5 static full/core/details/cradle PNG classifier.

Four independent *sequential* captures on one verified original-QML instance
at one fixed mapped pose. Isolated source-layer overlap with full pixels is
a same-coordinate observation, NOT a compositing/causality proof.
No Qt, disk, OS, screenshots, host input or publication.
"""
import math

VARIANTS = ("full", "core", "details", "cradle")
ORIGINAL_ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
CANVAS = (320, 300)
HOST_RECT = (72.0, 75.5, 168.0, 147.0)
THRESHOLD = 24
MARGIN = 2


class Unqualified(ValueError):
    pass


def reject(code):
    raise Unqualified(code)


def classify(images, parser):
    if type(images) is not dict or set(images) != set(VARIANTS):
        reject("FOUR_SOURCE_CAPTURES_REQUIRED")
    if (type(parser) is not dict
            or parser.get("ALPHA_THRESHOLD") != THRESHOLD
            or parser.get("EDGE_MARGIN") != MARGIN):
        reject("ORIGINAL_BOUNDED_ALPHA_PARSER_REQUIRED")
    decoded = {}
    inside = {name: 0 for name in VARIANTS}
    exterior = {name: set() for name in VARIANTS}
    x0, y0, w, h = HOST_RECT
    if not all(map(math.isfinite, HOST_RECT)):
        reject("BOTTOM_HOST_GEOMETRY_INVALID")
    for name in VARIANTS:
        raw = images[name]
        try:
            size_x, size_y, pixels = parser["png_alpha"](raw)
        except (ValueError, TypeError, KeyError):
            reject("SOURCE_PRIVATE_RGBA_PNG_UNSUPPORTED")
        if (size_x, size_y) != CANVAS:
            reject("SOURCE_PRIVATE_CANVAS_INVALID")
        decoded[name] = pixels
        for py in range(size_y):
            for px in range(size_x):
                if pixels[py * size_x + px] < THRESHOLD:
                    continue
                if (px < MARGIN or py < MARGIN or
                        px >= size_x - MARGIN or py >= size_y - MARGIN):
                    reject("SOURCE_PAINT_REACHES_CANVAS_EDGE")
                if x0 <= px + .5 < x0 + w and y0 <= py + .5 < y0 + h:
                    inside[name] += 1
                else:
                    exterior[name].add(py * size_x + px)
    # A fully transparent decoration is a meaningful isolated observation:
    # do NOT forge minimum interior paint for details/cradle.
    if inside["full"] < 8 or inside["core"] < 8:
        reject("FULL_OR_CORE_INTERIOR_PAINT_MISSING")
    return {
        "kind": "private_original_bottom_static_source_layer_observation",
        "edge": "bottom", "scale": 1.5,
        "original_source_one_qt_instance": True,
        "fixed_pose": True,
        "captures_sequential": True,
        "individual_isolation_altered_scene": True,
        "overlap_is_not_causality": True,
        "sampled_original_animation": "not_tested",
        "actual_compositor_or_pointer": "not_tested",
        "production_mask_changed": False,
        "outside": {
            name: bool(exterior[name]) for name in VARIANTS
        },
        "full_exterior_same_pixel_overlap": {
            name: bool(exterior["full"] & exterior[name])
            for name in VARIANTS if name != "full"
        },
    }
