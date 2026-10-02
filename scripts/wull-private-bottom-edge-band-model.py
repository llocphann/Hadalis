#!/usr/bin/env python3
"""PURE synthetic-panel-edge alpha-band diagnostic on four original FULL
BOTTOM×1.5 private 320×300 same-pose original cradle margin images.

This tests only potential contact with an ABSTRACT bottom host/panel boundary.
It does not verify real panel pixels, visible aesthetics, desktop/compositor
clipping, native input or continuous spring motion. No IO or Qt.
"""
MARGINS = (0, 1, 2, 3)
CANVAS = (320, 300)
HOST_RECT = (72.0, 75.5, 168.0, 147.0)
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
EDGE_MARGIN = 2
THRESHOLD = 24
# For host [75.5,222.5), pixel center y+0.5 means last strictly INSIDE
# host raster row is y=221. The virtual adjacent panel begins y=222.
LAST_HOST_ROW = 221
INNER_SUPPORT_ROW = 220
# Strict central portion of original 58×10 cradle, mapped x≈112.5..199.5.
# Leave generous room from rounded ends to avoid falsely inferring corner gaps.
CRADLE_CENTER_X = (119, 192)
MIN_RUN = 3


class Unqualified(ValueError):
    pass


def deny(code):
    raise Unqualified(code)


def band_contact(pixels, width):
    """Consecutive alpha >=24 at last inside row and supporting inner row.

    A positive only indicates a 3-pixel-thick synthetic boundary candidate;
    it does NOT establish the layer producing it or visual contact with a
    real-world panel, whose pixels are NOT captured here.
    """
    run = 0
    for x in range(CRADLE_CENTER_X[0], CRADLE_CENTER_X[1] + 1):
        if (pixels[LAST_HOST_ROW * width + x] >= THRESHOLD and
                pixels[INNER_SUPPORT_ROW * width + x] >= THRESHOLD):
            run += 1
            if run >= MIN_RUN:
                return True
        else:
            run = 0
    return False


def classify(images, parser):
    if type(images) is not dict or set(images) != set(MARGINS):
        deny("EXACT_FOUR_ORIGINAL_MARGIN_CAPTURES_REQUIRED")
    if (type(parser) is not dict or
            parser.get("ALPHA_THRESHOLD") != THRESHOLD or
            parser.get("EDGE_MARGIN") != EDGE_MARGIN):
        deny("ORIGINAL_BOUNDED_RGBA8_PARSER_REQUIRED")
    x0, y0, w, h = HOST_RECT
    outside = {}
    contact = {}
    for margin in MARGINS:
        try:
            iw, ih, alpha = parser["png_alpha"](images[margin])
        except (ValueError, TypeError, KeyError):
            deny("ORIGINAL_PRIVATE_PNG_INVALID")
        if (iw, ih) != CANVAS:
            deny("ORIGINAL_PRIVATE_CANVAS_INVALID")
        inside = exterior = 0
        for py in range(ih):
            for px in range(iw):
                if alpha[py * iw + px] < THRESHOLD:
                    continue
                if (px < EDGE_MARGIN or py < EDGE_MARGIN or
                        px >= iw - EDGE_MARGIN or
                        py >= ih - EDGE_MARGIN):
                    deny("PRIVATE_PAINT_REACHES_CANVAS_EDGE")
                if (x0 <= px + .5 < x0 + w and
                        y0 <= py + .5 < y0 + h):
                    inside += 1
                else:
                    exterior += 1
        if inside < 8:
            deny("ORIGINAL_FULL_INTERIOR_PAINT_MISSING")
        outside[margin] = exterior > 0
        contact[margin] = band_contact(alpha, iw)

    if not outside[0]:
        deny("ORIGINAL_MARGIN0_EXTERIOR_BASELINE_NOT_REPRODUCED")
    if outside[1]:
        deny("MARGIN1_ZERO_EXTERIOR_CANDIDATE_NOT_REPRODUCED")
    if not contact[0]:
        deny("ORIGINAL_MARGIN0_EDGE_BAND_CONTACT_UNESTABLISHED")

    return {
        "kind": "private_original_bottom_full_raster_virtual_panel_edge_band",
        "margins": MARGINS,
        "margin0_exterior_positive": True,
        "margin1_exterior_negative": True,
        "original_margin0_boundary_band_positive": True,
        "inner_boundary_band_by_margin": contact,
        "candidate_margin1_no_boundary_band_signal": not contact[1],
        "original_full_scene_not_cradle_only": True,
        "virtual_panel_only_not_real_visual_connection": True,
        "frozen_original_pose_only": True,
        "animated_extrema": "not_tested",
        "compositor_and_pointer": "not_tested",
        "production_mask_changed": False,
    }
