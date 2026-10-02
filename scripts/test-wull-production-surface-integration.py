#!/usr/bin/env python3
"""Production Wull field-rim, source-local free-slot and default-off contract.

Actual rendering/hover/popup still require the maintainer's live desktop;
this test checks the CURRENT production integration and pure JS behavior.
Historical source is archived as exact fixture blobs to avoid pretending old
pre-integration private evidence is testing the new production QML.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PERIMETER = ROOT / "modules/abyss/AbyssPerimeter.qml"
BODY = ROOT / "modules/abyss/companion/AbyssCompanion.qml"
PLACEMENT = ROOT / "modules/abyss/companion/WullSurfacePlacement.js"
OLD_ROOT = ROOT / "scripts/wull-fixtures/historical"
OLD_PERIMETER = OLD_ROOT / "pre-surface-attachment-perimeter.snapshot"
OLD_BODY = OLD_ROOT / "pre-surface-attachment-companion.snapshot"


def blob(raw):
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
    ).hexdigest()


assert blob(OLD_PERIMETER.read_bytes()) == (
    "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac")
assert blob(OLD_BODY.read_bytes()) == (
    "b5b01835a282458eba0d0268396ae2c350d919d2")

defaults = json.loads((ROOT / "defaults/config.json").read_text())
assert defaults["abyss"]["companion"]["enabled"] is False
assert defaults["abyss"]["companion"]["soundEnabled"] is False
assert defaults["abyss"]["companion"]["interactive"] is True

original_body = OLD_BODY.read_text()
body = BODY.read_text()
bottom_marker = (
    "        anchors.bottom: parent.bottom\n"
    "        scale: 1 + root.ripple * 0.16"
)
# Historical pre-integration body stays SHA-pinned; current production is
# intentionally evolving beyond the old one-line private cradle experiment.
assert original_body.count(bottom_marker) == 1
for marker in (
    'orientationAngle: root.edge === "left" ? 90',
    'anchors.bottom: root.verticalEdge ? undefined : parent.bottom',
    'anchors.bottomMargin: root.edge === "bottom" ? 0.25 : 0',
    'anchors.horizontalCenter: root.verticalEdge ? undefined : parent.horizontalCenter',
    'anchors.verticalCenter: root.verticalEdge ? parent.verticalCenter : undefined',
    'anchors.left: root.edge === "left" ? parent.left : undefined',
    'anchors.right: root.edge === "right" ? parent.right : undefined',
):
    assert body.count(marker) == 1, marker
assert 'rotation: root.edge === "left" ? 90' not in body
assert body.count("WaterDropletBody {") == 1
assert "anchors.centerIn: parent" in body
assert "transformOrigin: Item.Center" in body
assert "color: Qt.alpha(AbyssStyle.accent," in body

original = OLD_PERIMETER.read_text()
source = PERIMETER.read_text()
assert source != original
assert source.count("AbyssCompanion {") == 1
assert source.count("CompanionBridge {") == 1
assert source.count('import "companion/WullSurfacePlacement.js" as WullSurfacePlacement') == 1
assert 'binaryPath: root.companionEnabled ?' in source
assert 'useNativeDispatcher: root.companionEnabled' in source
mask = (
    "Region { item: WullHostPolicy.acceptsInput("
    "window.companionHostActive, companion.interactive, companion.visible)"
    " ? companion : emptyInput }"
)
assert original.count(mask) == source.count(mask) == 1
for marker in (
    "readonly property var companionPlacement:",
    "return WullSurfacePlacement.slot({",
    "bar.visible ? bar.layoutRecords.map(record => ({",
    "footprint: span + 16,",
    "maxShift: Math.min(360, extent * 0.28),",
    "cornerStart:", "cornerEnd:",
    "&& window.companionPlacement.qualified",
    "? window.companionPlacement.center : preferred",
    "function companionFieldDepth(): real",
    "const actual = window.bodyInsets(root.companionEdge, along, span)",
    "Math.max(AbyssStyle.perimeterThickness, depth)",
    "const horizontal = Geometry.horizontal(root.companionEdge)",
    "root.companionScale - 1",
    "readonly property bool companionOccluded:",
    "liquid.popupsOpen",
    "popup.presented",
    "leftPanel.presented",
    "rightPanel.presented",
    "WullHostPolicy.alongPosition(extent, span,",
):
    assert marker in source, marker
assert "window.height - AbyssStyle.perimeterThickness - implicitHeight" not in source
assert "window.width - AbyssStyle.perimeterThickness - implicitWidth" not in source
assert source.count("window.companionFieldDepth()") == 4
assert source.count('edge === "left"') >= 1
assert source.count('edge === "top"') >= 1
assert source.count("function companionAlongPosition()") == 1
# No new input-mask geometry, no extra full-screen renderer or new process.
for marker in ("nativeInputMask: Region {", "AbyssField {",
               "AbyssBar {", "AbyssCompanion {"):
    assert source.count(marker) == original.count(marker), marker
assert source.count("CompanionBridge {") == original.count("CompanionBridge {")
assert source.count("WlrLayershell.namespace:") == original.count(
    "WlrLayershell.namespace:")
assert PLACEMENT.is_file()
assert "function slot(options)" in PLACEMENT.read_text()
result = subprocess.run(
    ["node", "scripts/test-wull-production-surface-slot.cjs"],
    cwd=ROOT, capture_output=True, text=True, timeout=35,
    check=False,
)
assert result.returncode == 0, "Pure production slot behavior failed"
assert "WULL_PRODUCTION_SURFACE_SLOT_PASS" in result.stdout
print("WULL_PRODUCTION_FIELD_RIM_SURFACE_INTEGRATION_PASS")
