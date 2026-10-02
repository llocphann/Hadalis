#!/usr/bin/env python3
"""PURE original-full frozen BOTTOM x1.5 fractional private visual-band probe.

No Qt, I/O or actual desktop/panel inference. All five captures must be from
the same source/pose session; the runner and QML enforce this separately.
"""
MARGINS = ("m000", "m025", "m050", "m075", "m100")
MARGIN_VALUES = (0.0, 0.25, 0.5, 0.75, 1.0)
CANVAS = (320, 300)
HOST_RECT = (72.0, 75.5, 168.0, 147.0)
THRESHOLD = 24
EDGE_MARGIN = 2
LAST_HOST_ROW = 221
INNER_SUPPORT_ROW = 220
CRADLE_CENTER_X = (119, 192)
MIN_RUN = 3
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"


class Unqualified(ValueError):
    pass


def deny(reason):
    raise Unqualified(reason)


def band_contact(alpha, width):
    consecutive = 0
    for x in range(CRADLE_CENTER_X[0], CRADLE_CENTER_X[1] + 1):
        if (alpha[LAST_HOST_ROW * width + x] >= THRESHOLD and
                alpha[INNER_SUPPORT_ROW * width + x] >= THRESHOLD):
            consecutive += 1
            if consecutive >= MIN_RUN:
                return True
        else:
            consecutive = 0
    return False


def classify(images, parser):
    if type(images) is not dict or set(images) != set(MARGINS):
        deny("FIVE_EXACT_ORIGINAL_FULL_CAPTURES_REQUIRED")
    if (type(parser) is not dict or
            parser.get("ALPHA_THRESHOLD") != THRESHOLD or
            parser.get("EDGE_MARGIN") != EDGE_MARGIN):
        deny("ORIGINAL_BOUNDED_ALPHA_PARSER_REQUIRED")
    exterior, contact = {}, {}
    x0, y0, w, h = HOST_RECT
    for key in MARGINS:
        try:
            iw, ih, alpha = parser["png_alpha"](images[key])
        except (KeyError, ValueError, TypeError):
            deny("ORIGINAL_PRIVATE_PNG_INVALID")
        if (iw, ih) != CANVAS:
            deny("ORIGINAL_PRIVATE_CANVAS_INVALID")
        inside = outside = 0
        for py in range(ih):
            for px in range(iw):
                if alpha[py * iw + px] < THRESHOLD:
                    continue
                if (px < EDGE_MARGIN or py < EDGE_MARGIN or
                        px >= iw - EDGE_MARGIN or py >= ih - EDGE_MARGIN):
                    deny("PRIVATE_PAINT_REACHES_CANVAS_EDGE")
                if x0 <= px + 0.5 < x0 + w and y0 <= py + 0.5 < y0 + h:
                    inside += 1
                else:
                    outside += 1
        if inside < 8:
            deny("ORIGINAL_FULL_INTERIOR_PAINT_MISSING")
        exterior[key] = bool(outside)
        contact[key] = band_contact(alpha, iw)

    if not exterior["m000"]:
        deny("ORIGINAL_M0_EXTERIOR_BASELINE_NOT_REPRODUCED")
    if exterior["m100"]:
        deny("ORIGINAL_M1_ZERO_EXTERIOR_NOT_REPRODUCED")
    if not contact["m000"]:
        deny("ORIGINAL_M0_BOUNDARY_BAND_NOT_REPRODUCED")
    # m100 contact is measured, NOT preordained. It is not actual panel proof.
    joint = [key for key in MARGINS[1:-1]
             if not exterior[key] and contact[key]]
    return {
        "kind": "private_original_bottom150_fractional_frozen_band",
        "margins": MARGINS,
        "exterior": exterior,
        "contact": contact,
        "fractional_joint_candidates": tuple(joint),
        "same_session_frozen_source_only": True,
        "virtual_panel_band_not_real_connection": True,
        "spring_motion": "not_tested",
        "compositor_pointer_popup": "not_tested",
        "production_mask_changed": False,
    }
