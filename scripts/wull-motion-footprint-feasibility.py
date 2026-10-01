#!/usr/bin/env python3
"""INERT SOURCE-PINNED Wull motion and scale MASK RISK, not live acceptance.

This explicitly demonstrates *possible* miss cases. It does NOT claim exact
Qt transform order, spring animation runtime extrema or actual frame states.
No QML output, compositor, native input, filesystem changes or network use.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_BLOBS = {
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/companion/CompanionBridge.qml":
        "93c8d99497988f86660547773e8c30d90ac4bb66",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
}
BODY_WIDTH = 76
BODY_HEIGHT = 92
HORIZONTAL_HOST = (112, 98)
VERTICAL_HOST = (98, 112)
# The previously tested PRIVATE rectangle occupies the static centered
# 76x92 body BBOX, not the whole 112x98 companion host.
TOP_BODY_OFFSET = (18, 3)
TOP_PATH_TIP = (BODY_WIDTH * .5, 2.0)
BRIDGE_SQUASH = (-1.0, 1.0)
BRIDGE_STRETCH = (-1.0, 1.0)
BRIDGE_LEAN = (-1.0, 1.0)
BRIDGE_TIP = (-1.0, 1.0)
BRIDGE_ENERGY = (0.0, 1.0)
BRIDGE_PULSE = (0.0, 1.0)
ROOT_ANIMATION_SQUASH_NOMINAL = (-.35, 1.0)
PARENT_SCALE_CONFIG = (.65, 1.5)


def git_blob(data):
    if type(data) is not bytes:
        raise ValueError("invalid_source_bytes")
    content = b"blob " + str(len(data)).encode("ascii") + b"\x00" + data
    return hashlib.sha1(content).hexdigest()


def verify_reviewed_source(root=ROOT):
    if not isinstance(root, Path):
        raise ValueError("invalid_source_root")
    paths = {path: (root / path).read_bytes()
             for path in SOURCE_BLOBS}
    for name, expected in SOURCE_BLOBS.items():
        if git_blob(paths[name]) != expected:
            raise ValueError("unreviewed_wull_motion_dependency:" + name)
    b = paths["modules/abyss/companion/WaterDropletBody.qml"].decode("utf-8")
    bridge = paths["modules/abyss/companion/CompanionBridge.qml"].decode("utf-8")
    wrapper = paths["modules/abyss/companion/AbyssCompanion.qml"].decode("utf-8")
    panel = paths["modules/abyss/AbyssPerimeter.qml"].decode("utf-8")
    for marker in (
        'width: 76; height: 92',
        'origin.x: root.width * 0.5',
        'origin.y: root.height',
        'yScale: 1 - root.stateSquash * 0.035 + root.stateStretch * 0.06',
        'xScale: 1 + root.stateSquash * 0.05 - root.stateStretch * 0.025',
        'rotation: sway * 2.2 + stateLean * 5.0 + stateTip * 2.4',
        'scale: 1 + squash * 0.035',
        'width: parent.width * (0.82 + root.pulse * 0.18)',
        'height: parent.height * (0.78 + root.pulse * 0.20)',
        'to: -1.2 - root.energy * 2.4',
        'to: 0.6 + root.energy * 1.2',
        'to: 0.45 + root.energy',
        'to: -0.3 - root.energy * 0.7',
        'SpringAnimation { spring: 2.8; damping: 0.36 }',
        'Easing.OutBack',
    ):
        if marker not in b:
            raise ValueError("unreviewed_body_transform_or_animation")
    for marker in (
        'root.stretch = root.boundedNumber(body.stretch, root.stretch, -1, 1)',
        'root.squash = root.boundedNumber(body.squash, root.squash, -1, 1)',
        'root.lean = root.boundedNumber(body.lean, root.lean, -1, 1)',
        'root.tip = root.boundedNumber(body.tip, root.tip, -1, 1)',
        'root.energy = root.boundedNumber(message.energy, root.energy, 0, 1)',
        'root.pulse = root.boundedNumber(message.pulse, root.pulse, 0, 1)',
    ):
        if marker not in bridge:
            raise ValueError("unreviewed_bridge_state_clamps")
    for marker in (
        'implicitWidth: verticalEdge ? 98 : 112',
        'implicitHeight: verticalEdge ? 112 : 98',
        'rotation: root.edge === "left" ? 90',
        'transformOrigin: Item.Center',
        'anchors.centerIn: parent',
    ):
        if marker not in wrapper:
            raise ValueError("unreviewed_four_edge_item_geometry")
    if ('scale: root.companionScale' not in panel
            or 'Math.max(0.65,' not in panel
            or 'Math.min(1.5,' not in panel):
        raise ValueError("unreviewed_companion_parent_scale")


def explicit_tip_vertical_scale(state_squash, state_stretch):
    """Source-level *isolated* bottom-origin yScale counterexample.

    Set all other transforms to their identity baseline for this analytical
    scenario. It is permitted by bridge clamps, not a witnessed actual frame,
    and proves STATIC body rectangle cannot be assumed a motion envelope.
    """
    for value in (state_squash, state_stretch):
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError("invalid_nominal_motion_input")
    if (not BRIDGE_SQUASH[0] <= state_squash <= BRIDGE_SQUASH[1]
            or not BRIDGE_STRETCH[0] <= state_stretch <= BRIDGE_STRETCH[1]):
        raise ValueError("motion_input_exceeds_reviewed_bridge_clamp")
    yscale = 1 - state_squash * .035 + state_stretch * .06
    # The top tip is at local y=2. The QML Scale transform's explicit
    # origin.y is BODY_HEIGHT; wrapper's body starts at host y=3.
    tip_relative = BODY_HEIGHT + (
        TOP_PATH_TIP[1] - BODY_HEIGHT) * yscale
    return {"y_scale": round(yscale, 6),
            "tip_y_relative_to_static_body": round(tip_relative, 6),
            "tip_y_relative_to_host": round(
                TOP_BODY_OFFSET[1] + tip_relative, 6),
            "private_bbox_top_relative_to_host": TOP_BODY_OFFSET[1]}


def nominal_parameter_budget():
    """ONLY input-clamp/binding arithmetic; excludes spring overshoot.

    Composition/order in real Qt scenes is NOT evaluated here. In particular
    anchor-vs-y semantics, transformed region behavior, parent scale pivot,
    compositor rounding and spring overshoot are separate live gates.
    """
    x_min = 1 + BRIDGE_SQUASH[0] * .05 - BRIDGE_STRETCH[1] * .025
    x_max = 1 + BRIDGE_SQUASH[1] * .05 - BRIDGE_STRETCH[0] * .025
    y_min = 1 - BRIDGE_SQUASH[1] * .035 + BRIDGE_STRETCH[0] * .06
    y_max = 1 - BRIDGE_SQUASH[0] * .035 + BRIDGE_STRETCH[1] * .06
    sway_min = -.3 - BRIDGE_ENERGY[1] * .7
    sway_max = .45 + BRIDGE_ENERGY[1]
    # Independent bounded inputs only; spring interpolation can OVERSHOOT.
    min_angle = sway_min * 2.2 + BRIDGE_LEAN[0] * 5 + BRIDGE_TIP[0] * 2.4
    max_angle = sway_max * 2.2 + BRIDGE_LEAN[1] * 5 + BRIDGE_TIP[1] * 2.4
    return {
        "state_xscale_nominal": (round(x_min, 6), round(x_max, 6)),
        "state_yscale_nominal": (round(y_min, 6), round(y_max, 6)),
        "root_animated_scale_nominal": (
            round(1 + ROOT_ANIMATION_SQUASH_NOMINAL[0] * .035, 6),
            round(1 + ROOT_ANIMATION_SQUASH_NOMINAL[1] * .035, 6)),
        "rotation_degrees_nominal": (round(min_angle, 6),
                                     round(max_angle, 6)),
        "bob_nominal_target_y": (-1.2 - 2.4 * BRIDGE_ENERGY[1],
                                 .6 + 1.2 * BRIDGE_ENERGY[1]),
        "parent_config_scale": PARENT_SCALE_CONFIG,
        "body_bbox": (BODY_WIDTH, BODY_HEIGHT),
        "source_host_top": HORIZONTAL_HOST,
        "source_host_side": VERTICAL_HOST,
        "max_pulse_halo_static_local": (
            round(BODY_WIDTH * (.82 + BRIDGE_PULSE[1] * .18), 6),
            round(BODY_HEIGHT * (.78 + BRIDGE_PULSE[1] * .20), 6)),
        "nominal_stretched_tip": explicit_tip_vertical_scale(0, 1),
        "parent_scale_1_5_nominal_bbox_top": (
            BODY_WIDTH * 1.5, BODY_HEIGHT * 1.5),
        "parent_scale_1_5_nominal_bbox_side": (
            BODY_HEIGHT * 1.5, BODY_WIDTH * 1.5),
        "independently_bounded_spring_runtime_extrema": False,
        "qt_transform_order_and_mask_coordinates_verified": False,
        "compositor_motion_hover_or_hit_accuracy": "not_run",
        "mask_or_production_changed": False,
    }


if __name__ == "__main__":
    verify_reviewed_source()
    # Intentional risk finding, not a mask or authoritative Qt render budget.
    print(json.dumps(nominal_parameter_budget(), sort_keys=True))
