#!/usr/bin/env python3
"""Guard the deferred ii host against cross-panel type-chain regressions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
osd = (ROOT / "modules" / "onScreenDisplay" / "OnScreenDisplay.qml").read_text(encoding="utf-8")
panels = (ROOT / "modules" / "ii" / "ShellIiPanelsImpl.qml").read_text(encoding="utf-8")
optional_runtime = (ROOT / "modules" / "ii" / "ShellIiOptionalRuntime.qml").read_text(encoding="utf-8")
sidebar_host = (ROOT / "modules" / "sidebar" / "SidebarHost.qml").read_text(encoding="utf-8")
shell_updates = (ROOT / "services" / "ShellUpdates.qml").read_text(encoding="utf-8")
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


# Explicit IPC/bar opens must not be suppressed by a stale enabledPanels
# snapshot. Closed disabled panels remain unloaded.
for source, content in (
    ("ShellIiPanelsImpl.qml", panels),
    ("ShellIiOptionalRuntime.qml", optional_runtime),
):
    require(content, "configuredPanelEnabled || open", source)

# SidebarHost owns only geometry/lifecycle. Concrete left/right content stays
# behind URL loaders so a regression in one content tree cannot invalidate both.
for token in (
    'source: root.featureRole',
    '"../sidebarLeft/SidebarLeftContent.qml"',
    '"../sidebarRight/CompactSidebarRightContent.qml"',
    '"../sidebarRight/SidebarRightContent.qml"',
    "item.screenWidth = Qt.binding",
    "item.panelVisible = Qt.binding",
):
    require(sidebar_host, token, "SidebarHost content isolation")
for token in (
    "import qs.modules.sidebarLeft",
    "import qs.modules.sidebarRight",
    "SidebarLeftContent {",
    "SidebarRightContent {",
    "CompactSidebarRightContent {",
):
    forbid(sidebar_host, token, "SidebarHost content isolation")

# Opening Shell Update is also a freshness request: fetch first, then rebuild
# detail state from the freshly updated origin ref.
for token in (
    "property bool _refreshDetailsAfterCheck: false",
    "root._refreshDetailsAfterCheck = true",
    "root._completeInteractiveRefresh()",
    "if (root.repoPathLoaded && root.available && !root.isChecking",
):
    require(shell_updates, token, "ShellUpdates interactive refresh")

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
