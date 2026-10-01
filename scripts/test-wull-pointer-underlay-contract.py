#!/usr/bin/env python3
"""Inert pointer-test fixture/geometry safety contract. NO live input."""
import ast
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
fixture = (ROOT / "scripts/wull-fixtures/pointer-underlay/shell.qml").read_text()
helper = (ROOT / "scripts/wull-pointer-targets.py").read_text()
perimeter = (ROOT / "modules/abyss/AbyssPerimeter.qml").read_text()
companion = (ROOT / "modules/abyss/companion/AbyssCompanion.qml").read_text()
policy = (ROOT / "modules/abyss/companion/WullHostPolicy.js").read_text()
defaults = json.loads((ROOT / "defaults/config.json").read_text())

# The event witness is an entirely separate LOWER layer; it cannot shadow
# the actual production host, mutate Wull settings, or inject host input.
for marker in (
    'WlrLayershell.namespace: "hadalis:wull-pointer-underlay"',
    "WlrLayershell.layer: WlrLayer.Bottom",
    "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None",
    "mask: Region { item: witness }",
    "acceptedButtons: Qt.LeftButton",
    "WULL_POINTER_UNDERLAY_PRESS",
    "WULL_POINTER_UNDERLAY_QML_READY",
):
    assert marker in fixture, marker
assert fixture.count("PanelWindow {") == 1
assert "AbyssPerimeter" not in fixture
assert "INIR_COMPANIOND" not in fixture
assert "Quickshell.env" not in fixture

# This test only recognizes the CURRENT complete-host input mask. A future
# narrowed mask MUST receive its own independent pointer acceptance.
assert "WullHostPolicy.acceptsInput(window.companionHostActive, companion.interactive, companion.visible) ? companion : emptyInput" in perimeter
assert "onActivated: companionBridge.sendEvent(\"click\")" in perimeter
assert "transformOrigin: Item.Center" in companion
assert "anchors.centerIn: parent" in companion
assert "function alongPosition(extent, footprint, along)" in policy
assert defaults["abyss"]["companion"]["enabled"] is False
assert defaults["abyss"]["companion"]["interactive"] is True
assert defaults["abyss"]["companion"]["edge"] == "auto"
assert float(defaults["abyss"]["companion"]["along"]) == 0.72
assert float(defaults["abyss"]["companion"]["size"]) == 1
assert defaults["abyss"]["perimeter"]["thickness"] == 16
assert defaults["bar"]["height"] == 40

# A static target estimate is not a pointer-mask acceptance. Keep this
# explicit while exercising compact viewports and adverse settings.
ast.parse(helper)
targets = runpy.run_path(str(ROOT / "scripts/wull-pointer-targets.py"),
                         run_name="wull_targets_contract_only")["top_edge_targets"]
for width, height, along in (
    (480, 240, .08), (800, 600, .50), (1280, 720, .72),
    (1920, 1080, .92)
):
    points = targets(width, height, along=along)
    body = points["body_center"]
    margin = points["inside_host_outside_body"]
    exterior = points["outside_host_control"]
    hx, hy, hw, hh = points["host_bounds"]
    bx, by, bw, bh = points["mapped_body_bounds"]
    assert points["estimated_from_static_production_source"] is True
    assert hx <= body[0] <= hx + hw and hy <= body[1] <= hy + hh
    assert bx < body[0] < bx + bw and by < body[1] < by + bh
    assert margin[0] < bx and hx < margin[0] < hx + hw
    assert not (hx <= exterior[0] <= hx + hw)
    assert all(40 < pt[1] < height for pt in (body, margin, exterior))
for args in ((0, 720), (479, 240), (1280, 0)):
    try:
        targets(*args)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid output accepted: " + repr(args))
print("WULL_POINTER_UNDERLAY_INERT_CONTRACT_PASS")
