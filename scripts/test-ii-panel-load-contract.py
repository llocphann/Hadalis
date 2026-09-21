#!/usr/bin/env python3
"""Guard the deferred ii host against cross-panel type-chain regressions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
osd = (ROOT / "modules" / "onScreenDisplay" / "OnScreenDisplay.qml").read_text(encoding="utf-8")
panels = (ROOT / "modules" / "ii" / "ShellIiPanelsImpl.qml").read_text(encoding="utf-8")
optional_runtime = (ROOT / "modules" / "ii" / "ShellIiOptionalRuntime.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "modules" / "common" / "perimeter" / "qmldir").read_text(encoding="utf-8")

failures = []

def require(source: str, token: str, label: str) -> None:
    if token not in source:
        failures.append(f"{label}: missing {token!r}")

def forbid(source: str, token: str, label: str) -> None:
    if token in source:
        failures.append(f"{label}: forbidden {token!r}")

for token in (
    'PanelLoader { identifier: "iiOnScreenDisplay"; source: "../onScreenDisplay/OnScreenDisplay.qml" }',
    'identifier: "iiDashboard"',
    'source: "../dashboard/Dashboard.qml"',
    'identifier: "iiOverview"',
    'source: "../overview/Overview.qml"',
    'identifier: "iiScreenCorners"',
    'source: "../screenCorners/ScreenCorners.qml"',
    'identifier: "iiSidebarLeft"',
    'source: "../sidebarLeft/SidebarLeft.qml"',
    'identifier: "iiSidebarRight"',
    'source: "../sidebarRight/SidebarRight.qml"',
    'source: "ShellIiOptionalRuntime.qml"',
):
    require(panels, token, "ii panel registry")

for token in (
    "import qs.modules.common.widgets",
    "import qs.modules.ii.overlay",
    "import Quickshell.Hyprland",
    "FluidRipple {",
    "ShellLayoutEditorWindow {",
    "GlobalShortcut {",
    "OverlayContext.",
):
    forbid(panels, token, "ii deferred core host")

for token in (
    'source: "overlay/Overlay.qml"',
    "FluidRipple {",
    "ShellLayoutEditorWindow {",
    "GlobalShortcut {",
):
    require(optional_runtime, token, "ii optional runtime isolation")

# Optional panel implementations must stay behind URL boundaries. A parse/type
# regression in OSD, lock, wallpaper, etc. must not make the shared deferred
# host unavailable and take Sidebar/Dashboard/Overview down with it.
for token in (
    "component: NotificationPopup {}",
    "component: OnScreenDisplay {}",
    "component: BootGreeting {}",
    "component: Lock {}",
    "component: MediaControls {}",
    "component: OnScreenKeyboard {}",
    "component: Overlay {}",
    "component: Polkit {}",
    "component: RegionSelector {}",
    "component: ScreenCorners {}",
    "component: SessionScreen {}",
    "component: TilingOverlay {}",
    "component: WallpaperSelector {}",
    "component: WallpaperLauncher {}",
    "component: WallpaperCoverflow {}",
    "component: ClipboardModule.ClipboardPanel {}",
    "component: ShellUpdateOverlay {}",
    "component: RecordingOsd {}",
):
    forbid(panels, token, "ii deferred host isolation")

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
