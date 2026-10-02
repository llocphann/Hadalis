#!/usr/bin/env python3
"""INERT two-BOTTOM original full-composite margin0 versus private margin0.25 classifier.

Two BOTTOM×1.5 cases x two real springs x eight Qt images each. Caller
must independently verify real QML/phase/mapped-motion witnesses. Pure PNG
bytes in, categorical results out; NO Qt, IO, host screen or production mask.
"""
import math

CANVAS = (320, 300)
THRESHOLD = 24
EDGE_MARGIN = 2
CASES = ("m0_150", "m025_150")
PHASES = ("stretch", "release")
SAMPLES = 8
MODEL_ORIGINAL_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
# SAME original FULL PNG is analyzed for BOTH exterior and abstract
# two-row inner host boundary contact; this is NOT a desktop panel photo.
LAST_INSIDE = 221
SUPPORT_ROW = 220
CENTRAL_ROI = (119, 192)
MIN_CONTIGUOUS = 3


def band_contact(values, width):
    consecutive = 0
    for x in range(CENTRAL_ROI[0], CENTRAL_ROI[1] + 1):
        if (values[LAST_INSIDE * width + x] >= THRESHOLD and
                values[SUPPORT_ROW * width + x] >= THRESHOLD):
            consecutive += 1
            if consecutive >= MIN_CONTIGUOUS:
                return True
        else:
            consecutive = 0
    return False



class Inconclusive(ValueError):
    pass


def deny(code):
    raise Inconclusive(code)


def geometry(case):
    if case in CASES:
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
        "abstract_inner_band_contact": band_contact(values, width),
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
             "mapped_change_m0_stretch", "mapped_change_m025_stretch",
             "mapped_change_m0_release", "mapped_change_m025_release",
             "stretch_target_reached", "release_target_reached")
    if (type(witness) is not dict or set(witness) != set(names)
            or any(type(witness[n]) is not bool or not witness[n]
                   for n in names)):
        deny("DYNAMIC_PHASE_OR_MOTION_WITNESS_MISSING")
    summary = {
        (case, phase): False for case in CASES for phase in PHASES
    }
    band_any = {(case, phase): False for case in CASES for phase in PHASES}
    band_all = {(case, phase): True for case in CASES for phase in PHASES}
    for item, (phase, sample, case) in zip(rows, expected()):
        if (type(item) is not dict or set(item) != {
                "case", "phase", "sample", "composite_outside_host_alpha",
                "abstract_inner_band_contact"}
                or item["case"] != case or item["phase"] != phase
                or type(item["sample"]) is not int
                or item["sample"] != sample
                or type(item["composite_outside_host_alpha"]) is not bool
                or type(item["abstract_inner_band_contact"]) is not bool):
            deny("DYNAMIC_FRAME_ORDER_OR_FIELDS_INVALID")
        summary[(case, phase)] |= item["composite_outside_host_alpha"]
        band_any[(case, phase)] |= item["abstract_inner_band_contact"]
        band_all[(case, phase)] &= item["abstract_inner_band_contact"]
    # A/B causal hypotheses require a live-positive ORIGINAL control
    # in BOTH real spring phases within THIS SAME private Qt session.
    if not summary[("m0_150", "stretch")] or not summary[("m0_150", "release")]:
        deny("ORIGINAL_DYNAMIC_BASELINE_NOT_REPRODUCED")
    if not (band_any[("m0_150", "stretch")] and
            band_any[("m0_150", "release")]):
        deny("ORIGINAL_DYNAMIC_VIRTUAL_BAND_NOT_REPRODUCED")
    return {
        "kind": "private_original_bottom150_margin0_margin025_dynamic_exterior_and_virtual_band",
        "sampled_frames": 32,
        "real_qt_phase_witness": True,
        "sampled_mapped_change_witness": True,
        "full_original_component_only": True,
        "baseline_margin0_both_phase_exterior_required": True,
        "inset025_original_cradle_instance_only": True,
        "full_scene_pixel_causality": "not_tested",
        "actual_wayland_clipping_or_click": "not_tested",
        "global_spring_extrema": "not_proven",
        "production_mask_changed": False,
        "cases": [{
            "case": case,
            "stretch_exterior_alpha_observed": summary[(case, "stretch")],
            "release_exterior_alpha_observed": summary[(case, "release")],
            "stretch_virtual_band_any": band_any[(case, "stretch")],
            "release_virtual_band_any": band_any[(case, "release")],
            "stretch_virtual_band_all_samples": band_all[(case, "stretch")],
            "release_virtual_band_all_samples": band_all[(case, "release")],
        } for case in CASES],
    }
