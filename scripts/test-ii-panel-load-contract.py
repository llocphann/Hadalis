#!/usr/bin/env python3
"""Guard the static ii panel type chain against retired QML APIs."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
osd = (ROOT / "modules" / "onScreenDisplay" / "OnScreenDisplay.qml").read_text(encoding="utf-8")
panels = (ROOT / "modules" / "ii" / "ShellIiPanelsImpl.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "modules" / "common" / "perimeter" / "qmldir").read_text(encoding="utf-8")

failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

def forbid(source: str, token: str, label: str) -> None:
    if token in source:
        failures.append(f"{label}: forbidden {token!r}")

for token in (
    'PanelLoader { identifier: "iiOnScreenDisplay"; component: OnScreenDisplay {} }',
    'identifier: "iiDashboard"',
    'identifier: "iiScreenCorners"',
):
    require(panels, token, "ii panel registry")

for token in (
    "ConnectedSurfaceBodyMask 1.0 ConnectedSurfaceBodyMask.qml",
    "ConnectedSurfaceFrame 1.0 ConnectedSurfaceFrame.qml",
):
    require(qmldir, token, "perimeter exports")

for token in (
    "ConnectedSurfaceBodyMask {",
    "bodyItem: statusFrame.bodyItem",
    "inputEnabled: root.connectedIndicator && root._visualOpen",
):
    require(osd, token, "OnScreenDisplay supported perimeter consumer")

for token in (
    "ConnectedSurfaceMask {",
    "connectorItem:",
    "connectorVisible:",
    "connectorBorderWidth:",
):
    forbid(osd, token, "OnScreenDisplay retired perimeter API")

if failures:
    print("ii panel load contract regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("ii panel load contract: PASS")
