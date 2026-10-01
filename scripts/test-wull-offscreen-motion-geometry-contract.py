#!/usr/bin/env python3
"""INERT source, exact-pose parser and redacted offscreen Qt receipt contract.

Tests SYNTHETIC fixtures only; never launches Qt, a desktop or an input tool.
"""
import ast
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"
FIXTURE = ROOT / "scripts/wull-fixtures/motion-geometry/shell.qml"
source = SCRIPT.read_text(encoding="utf-8")
qml = FIXTURE.read_text(encoding="utf-8")
ast.parse(source)
for literal in (
    '"QT_QPA_PLATFORM": "offscreen"',
    '"WAYLAND_DISPLAY", "NIRI_SOCKET"',
    'explicit_offscreen_qt_opt_in_required',
    'clean_private_owned_dev_clone_required',
    'offscreen_motion_source_changed_after_review',
    'private_offscreen_receipt_push_refused',
    '"git", "push", "origin", "HEAD:refs/heads/dev"',
    '"rebase", "--onto", remote, previous',
    '"raw_local_qt_coordinates_logs": "private_local_only"',
):
    assert literal in source, literal
for forbidden in ('"reset"', '"--force"', '"ydotool"',
                  '"uinput"', '"wlrctl"', '"/dev/uinput"'):
    assert forbidden not in source, forbidden
for literal in (
    "Repeater {", "import qs.modules.abyss.companion",
    "body.motionEnabled = false",
    "body.stateStretch = 1",
    'root.collect("neutral")',
    'root.collect("stretch_target")',
    "body.mapToItem(host, 0, 0)",
    "host.mapToItem(stage, host.width, host.height)",
    "WULL_OFFSCREEN_MOTION_GEOMETRY",
):
    assert literal in qml, literal
assert qml.count("AbyssCompanion {") == 1
assert "WaterDropletBody {" not in qml
m = runpy.run_path(str(SCRIPT), run_name="wull_offscreen_inert_contract")
assert m["BASE"] == "07c81fef4217f634a8a8910a1903a7d9007c878a"
assert m["PINNED"][m["FIXTURE"]] == (
    "548daff91ca9a1d7961bedd098fd314159cb520d")
assert m["PINNED"]["modules/abyss/companion/WaterDropletBody.qml"] == (
    "fc5b1c227026786ab553685bc170daff74e82517")
assert m["EDGES"] == ("top", "right", "bottom", "left")
assert m["SCALES"] == (.65, 1.0, 1.5)
assert m["PHASES"] == ("neutral", "stretch_target")

def synthetic(edge, scale, phase):
    vertical = edge in ("right", "left")
    hostw, hosth = (98, 112) if vertical else (112, 98)
    bx, by = (3, 18) if vertical else (18, 3)
    bw, bh = (92, 76) if vertical else (76, 92)
    tipx, tipy = {
        "top": (56, 5), "bottom": (56, 93),
        "left": (93, 56), "right": (5, 56),
    }[edge]
    # One hypothetical top stretch=1 transform; the contract must
    # report this separately rather than treating synthetic data as live.
    protrusion = edge == "top" and scale == 1.0 and phase == "stretch_target"
    top = -4.5 if protrusion else by
    tipy = -.4 if protrusion else tipy
    result = dict(
        valid=True, edge=edge, requested_scale=scale, phase=phase,
        host_width=hostw, host_height=hosth,
        stage_host_width=hostw*scale,
        stage_host_height=hosth*scale,
        bbox_left=bx, bbox_top=top,
        bbox_right=bx+bw, bbox_bottom=by+bh,
        tip_x=tipx, tip_y=tipy,
        bbox_inside_host=not protrusion,
        tip_inside_host=not protrusion,
        bbox_inside_source_static=not protrusion,
        tip_inside_source_static=not protrusion)
    return result

rows = [synthetic(edge, scale, phase) for edge in m["EDGES"]
        for scale in m["SCALES"] for phase in m["PHASES"]]
proof = m["model_summary"](rows)
assert proof["status"] == "pass"
assert proof["reason"] is None
assert proof["qt_24_poses_observed"] is True
assert proof["qt_parent_scale_mapping_consistent"] is True
assert proof["per_scale_stretch_geometry"]["1.0"][
    "stretched_tip_outside_host_edges"] == ["top"]
assert proof["per_scale_stretch_geometry"]["1.0"][
    "stretched_bbox_outside_source_static_edges"] == ["top"]
assert proof["per_scale_stretch_geometry"]["0.65"][
    "stretched_tip_outside_host_edges"] == []

data = m["public_report"](proof, "a"*40, "b"*40, "0.2.0", "6.8.0")
assert data["status"] == "pass"
assert data["observed_pose_count"] == 24
assert data["scope"].startswith("unmodified_actual_qml_private_offscreen")
assert data["stretch_target_observations"]["1.0"][
    "stretched_tip_outside_host_edges"] == ["top"]
assert data["real_backend_animation"] == "not_run"
assert data["wayland_region_pointer_hover"] == "not_run"
assert data["production_mask_changed"] is False
for bad in (
    rows[:-1],
    [*rows[:-1], rows[0]],
    [{**rows[0], "requested_scale": 1.25}, *rows[1:]],
    [{**rows[0], "bbox_inside_host": False}, *rows[1:]],
    [{**rows[0], "stage_host_width": 999}, *rows[1:]],
    [{**rows[0], "bbox_left": "private"}, *rows[1:]],
):
    try:
        m["model_summary"](bad)
    except (ValueError, TypeError):
        pass
    else:
        raise AssertionError("Unqualified QT geometry accepted")
for bad, sha, version in (
    ({**proof, "reason": "private host data"}, "a"*40, "0.2.0"),
    ({**proof, "real_backend_animation": "pass"}, "a"*40, "0.2.0"),
    ({**proof, "per_scale_stretch_geometry": {
        **proof["per_scale_stretch_geometry"],
        "1.0": {**proof["per_scale_stretch_geometry"]["1.0"],
                "stretched_tip_outside_host_edges": ["right", "top"]}}},
     "a"*40, "0.2.0"),
    (proof, "no_sha", "0.2.0"),
    (proof, "a"*40, "quickshell-private-host"),
):
    try:
        m["public_report"](bad, sha, "b"*40, version, "6.8.0")
    except (ValueError, TypeError):
        pass
    else:
        raise AssertionError("Unsafe offscreen public proof accepted")
serialized = json.dumps(data)
for forbidden in ('"bbox_left":', '"tip_y":', '"wayland_socket":',
                  '"host_name":', '"private_qt_log":'):
    assert forbidden not in serialized
print("WULL_OFFSCREEN_MOTION_GEOMETRY_INERT_CONTRACT_PASS")
