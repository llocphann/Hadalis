#!/usr/bin/env python3
"""INERT original-composite actual-frame alpha classifier for two moving cases.

Two cases x two real authored Qt phases x eight actual sampled PNGs. Caller
must independently verify real QML/phase/mapped-motion witnesses. Pure PNG
bytes in, categorical results out; NO Qt, IO, host screen or production mask.
"""
import math

CANVAS = (320, 300)
THRESHOLD = 24
EDGE_MARGIN = 2
CASES = ("top_100", "bottom_150")
PHASES = ("stretch", "release")
SAMPLES = 8
MODEL_ORIGINAL_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"


class Inconclusive(ValueError):
    pass


def deny(code):
    raise Inconclusive(code)


def geometry(case):
    if case == "top_100":
        return (100.0, 100.0, 112.0, 98.0)
    if case == "bottom_150":
        # The unchanged host (112x98) is center-scaled by Qt to 168x147.
        return (72.0, 75.5, 168.0, 147.0)
    deny("UNKNOWN_DYNAMIC_CASE")


def classify(case, phase, index, png, alpha_parser):
    if (case not in CASES or phase not in PHASES or
            type(index) is not int or not 0 <= index < SAMPLES):
        deny("UNKNOWN_PHASE_OR_SAMPLE")
    if (type(alpha_parser) is not dict or
            alpha_parser.get("ALPHA_THRESHOLD") != THRESHOLD or
            alpha_parser.get("EDGE_MARGIN") != EDGE_MARGIN):
        deny("ORIGINAL_PNG_MODEL_REQUIRED")
    try:
        width, height, values = alpha_parser["png_alpha"](png)
    except (ValueError, TypeError, KeyError):
        deny("PRIVATE_DYNAMIC_PNG_UNSUPPORTED")
    if (width, height) != CANVAS:
        deny("PRIVATE_DYNAMIC_CANVAS_INVALID")
    left, top, span_w, span_h = geometry(case)
    if not all(map(math.isfinite, (left, top, span_w, span_h))):
        deny("PRIVATE_DYNAMIC_GEOMETRY_INVALID")
    interior = exterior = 0
    for y in range(height):
        for x in range(width):
            if values[y * width + x] < THRESHOLD:
                continue
            if (x < EDGE_MARGIN or y < EDGE_MARGIN or
                    x >= width - EDGE_MARGIN or
                    y >= height - EDGE_MARGIN):
                deny("PRIVATE_DYNAMIC_CANVAS_PAINT_TRUNCATED")
            if (left <= x + 0.5 < left + span_w and
                    top <= y + 0.5 < top + span_h):
                interior += 1
            else:
                exterior += 1
    if interior < 8:
        deny("PRIVATE_DYNAMIC_INTERIOR_PAINT_MISSING")
    return {
        "case": case, "phase": phase, "sample": index,
        "composite_outside_host_alpha": exterior > 0,
    }


def expected():
    return [(phase, sample, case)
            for phase in PHASES for sample in range(SAMPLES)
            for case in CASES]


def summarize(rows, witness):
    # Data must have EXACT order and bounded boolean-only evidence.
    if type(rows) is not list or len(rows) != 32:
        deny("DYNAMIC_CAPTURE_MATRIX_INCOMPLETE")
    names = ("active_stretch", "active_release",
             "mapped_change_top_stretch", "mapped_change_bottom_stretch",
             "mapped_change_top_release", "mapped_change_bottom_release",
             "stretch_target_reached", "release_target_reached")
    if (type(witness) is not dict or set(witness) != set(names)
            or any(type(witness[n]) is not bool or not witness[n]
                   for n in names)):
        deny("DYNAMIC_PHASE_OR_MOTION_WITNESS_MISSING")
    summary = {
        (case, phase): False for case in CASES for phase in PHASES
    }
    for item, (phase, sample, case) in zip(rows, expected()):
        if (type(item) is not dict or set(item) != {
                "case", "phase", "sample", "composite_outside_host_alpha"}
                or item["case"] != case or item["phase"] != phase
                or type(item["sample"]) is not int
                or item["sample"] != sample
                or type(item["composite_outside_host_alpha"]) is not bool):
            deny("DYNAMIC_FRAME_ORDER_OR_FIELDS_INVALID")
        summary[(case, phase)] |= item["composite_outside_host_alpha"]
    return {
        "kind": "private_real_qt_dynamic_full_composite_pilot",
        "sampled_frames": 32,
        "real_qt_phase_witness": True,
        "sampled_mapped_change_witness": True,
        "composite_only": True,
        "original_shape_specific": "not_tested",
        "actual_wayland_clipping_or_click": "not_tested",
        "global_spring_extrema": "not_proven",
        "production_mask_changed": False,
        "cases": [{
            "case": case,
            "stretch_exterior_alpha_observed": summary[(case, "stretch")],
            "release_exterior_alpha_observed": summary[(case, "release")],
        } for case in CASES],
    }
