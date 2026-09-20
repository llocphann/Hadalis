#!/usr/bin/env python3
"""Static regression gate for the production iRiS split-composition popup path."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, label: str) -> None:
    if token not in text:
        raise SystemExit(f"iRiS production surface contract failed: {label}: {token}")


def forbid(text: str, token: str, label: str) -> None:
    if token in text:
        raise SystemExit(f"iRiS production surface contract failed: {label}: {token}")


styled = read("modules/bar/StyledPopup.qml")
frame = read("modules/common/perimeter/ConnectedSurfaceIrisFrame.qml")
field = read("modules/common/perimeter/ConnectedSurfaceIrisField.qml")
mask = read("modules/common/perimeter/ConnectedSurfaceBodyMask.qml")
tokens = read("modules/common/perimeter/PerimeterTokens.qml")
qmldir = read("modules/common/perimeter/qmldir")
motion = read("modules/common/SurfaceMotion.qml")
waffle = read("modules/waffle/bar/BarPopup.qml")

production_qsb = ROOT / "modules/common/perimeter/IrisField.frag.qsb"
locked_qsb = ROOT / "scripts/iris-corner-poc/IrisField.frag.qsb"
production_frag = ROOT / "modules/common/perimeter/IrisField.frag"
locked_frag = ROOT / "scripts/iris-corner-poc/IrisField.frag"

if production_qsb.read_bytes() != locked_qsb.read_bytes():
    raise SystemExit("iRiS production surface contract failed: production QSB differs from locked G1/G2 QSB")
if production_frag.read_bytes() != locked_frag.read_bytes():
    raise SystemExit("iRiS production surface contract failed: production shader source differs from locked G1/G2 source")
if production_qsb.stat().st_size != 16765:
    raise SystemExit("iRiS production surface contract failed: unexpected QSB byte size")

for token in (
    "ConnectedSurfaceGeometry {",
    "ConnectedSurfaceRevealClip {",
    "ConnectedSurfaceIrisFrame {",
    "ConnectedSurfaceContentHost {",
    "ConnectedSurfaceBodyMask {",
    "fuseDepth: PerimeterTokens.irisFuseDepth",
    "externalFrameThickness: root._screenEdgeThickness",
    "progress: root.revealProgress",
    "mask: connectedMask",
):
    require(styled, token, "StyledPopup cutover")

for token in ("ConnectedSurfaceFrame {", "ConnectedSurfaceMask {"):
    forbid(styled, token, "StyledPopup legacy renderer")

for token in (
    "function clipExternalOwners(raw)",
    "readonly property rect rawPaintBounds:",
    "readonly property rect paintBounds:",
    "readonly property var ownerShape:",
    "readonly property var frameStartShape:",
    "readonly property var frameEndShape:",
    "readonly property var popupShape:",
    "readonly property bool needsEndJoinAux:",
    'joins: ["frame-end"]',
    "ShaderEffectSource {",
    "sourceItem: shadowTextureSource",
    "sourceRect: Qt.rect(",
    "hideSource: true",
    "smooth: false",
    "ConnectedSurfaceIrisField {",
    "readonly property bool bodyHovered: bodyHover.hovered",
):
    require(frame, token, "ConnectedSurfaceIrisFrame")

for token in ("ConnectedSurfaceJoinFlares", "ConnectedSurfaceConnector", "Canvas {"):
    forbid(frame, token, "production renderer patch geometry")

for token in (
    'fragmentShader: Qt.resolvedUrl("IrisField.frag.qsb")',
    "readonly property vector4d viewport:",
    "pass.x, pass.y",
    "readonly property vector2d screen:",
    "readonly property vector4d shape19:",
    "readonly property vector4d joinE:",
    "readonly property vector4d alsoE:",
    "shaderCompiled: pass.status === ShaderEffect.Compiled",
):
    require(field, token, "ConnectedSurfaceIrisField")

for token in ("_sourceStrip", "_middleStrip", "_bodyStrip", "connectorItem"):
    forbid(mask, token, "body-only compositor mask")
require(mask, "visibleBodyRect", "body-only compositor mask")
require(tokens, "readonly property real irisFuseDepth: 30", "validated G2 fuse token")

for export in (
    "ConnectedSurfaceIrisField 1.0 ConnectedSurfaceIrisField.qml",
    "ConnectedSurfaceIrisFrame 1.0 ConnectedSurfaceIrisFrame.qml",
    "ConnectedSurfaceBodyMask 1.0 ConnectedSurfaceBodyMask.qml",
):
    require(qmldir, export, "perimeter module export")

require(motion, 'readonly property string mode: "slide"', "immutable motion")
require(waffle, "ConnectedSurfaceFrame {", "Waffle compatibility")
require(waffle, "ConnectedSurfaceMask {", "Waffle compatibility")
for token in ("ConnectedSurfaceIrisFrame {", "ConnectedSurfaceBodyMask {"):
    forbid(waffle, token, "Waffle must remain unchanged by ii cutover")

print("iRiS production surface contract: PASS")
