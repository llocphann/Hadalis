#!/usr/bin/env python3
"""PURE private BOTTOM×1.5 full-original composite cradle inset pilot.

One original component, four frozen sequential source instances of the
original QML rendered with private cradle bottomMargin = 0,1,2,3 only.
Classifies sampled exterior alpha; NOT production, dynamic or compositor.
"""
CANVAS = (320, 300)
HOST = (72.0, 75.5, 168.0, 147.0)
MARGINS = (0, 1, 2, 3)
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
THRESHOLD = 24
EDGE_MARGIN = 2


class Unqualified(ValueError):
    pass


def reject(code):
    raise Unqualified(code)


def classify(images, parser):
    if type(images) is not dict or set(images) != set(MARGINS):
        reject("FOUR_MARGIN_CAPTURES_REQUIRED")
    if (type(parser) is not dict or
            parser.get("ALPHA_THRESHOLD") != THRESHOLD or
            parser.get("EDGE_MARGIN") != EDGE_MARGIN):
        reject("ORIGINAL_ALPHA_PARSER_REQUIRED")
    x, y, width, height = HOST
    exterior = {}
    for margin in MARGINS:
        try:
            px_w, px_h, pixels = parser["png_alpha"](images[margin])
        except (ValueError, TypeError, KeyError):
            reject("MARGIN_PRIVATE_PNG_INVALID")
        if (px_w, px_h) != CANVAS:
            reject("MARGIN_PRIVATE_CANVAS_INVALID")
        inside = outside = 0
        for py in range(px_h):
            for px in range(px_w):
                if pixels[py * px_w + px] < THRESHOLD:
                    continue
                if (px < EDGE_MARGIN or py < EDGE_MARGIN or
                        px >= px_w - EDGE_MARGIN or
                        py >= px_h - EDGE_MARGIN):
                    reject("MARGIN_PAINT_REACHES_CAPTURE_EDGE")
                if x <= px + .5 < x + width and y <= py + .5 < y + height:
                    inside += 1
                else:
                    outside += 1
        if inside < 8:
            reject("MARGIN_INSIDE_ORIGINAL_COMPOSITE_MISSING")
        exterior[margin] = outside > 0
    if exterior[0] is not True:
        reject("ORIGINAL_ZERO_MARGIN_BASELINE_NOT_REPRODUCED")
    candidates = [margin for margin in MARGINS[1:]
                  if exterior[margin] is False]
    # A smaller success is only the smallest among THESE three
    # sampled margins, not a global minimum.
    return {
        "kind": "private_original_bottom150_cradle_inset_candidate",
        "margin_units": "original_QML_host_logical_px",
        "sampled_margin_values": MARGINS,
        "original_zero_margin_exterior": True,
        "exterior_by_margin": exterior,
        "smallest_tested_zero_exterior_margin": (
            candidates[0] if candidates else None),
        "four_frames": 4,
        "one_original_qt_instance": True,
        "fixed_original_body_pose": True,
        "sequential_altered_cradle_margins": True,
        "sampled_static_only": True,
        "dynamic_and_compositor_input": "not_tested",
        "production_mask_changed": False,
    }
