#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"fullscreen input lifecycle contract failed: {message}")


# These layer-shell surfaces intentionally remain mapped while their visual exit
# animation finishes (or, for Dashboard, remain mapped for warm reopens). Their
# input lifetime must therefore be shorter than their native surface lifetime.
contracts = {
    "modules/settings/SettingsOverlay.qml": (
        "readonly property bool acceptsInput: root.settingsOpen",
        "WlrLayershell.keyboardFocus: settingsPanel.acceptsInput",
        "settingsPanel.acceptsInput ? fullSettingsInput : emptySettingsInput",
    ),
    "modules/settings/SettingsFocus.qml": (
        "readonly property bool acceptsInput: root.settingsOpen",
        "WlrLayershell.keyboardFocus: settingsPanel.acceptsInput",
        "settingsPanel.acceptsInput ? fullFocusInput : emptyFocusInput",
    ),
    "modules/overview/Overview.qml": (
        "readonly property bool acceptsInput: root.shouldShow",
        "WlrLayershell.keyboardFocus: root.acceptsInput",
        "root.acceptsInput ? overviewInputMask : emptyDragMask",
    ),
    "modules/wallpaperSelector/WallpaperSelector.qml": (
        "readonly property bool acceptsInput: GlobalStates.wallpaperSelectorOpen",
        "WlrLayershell.keyboardFocus: panelWindow.acceptsInput",
        "? wallpaperSelectorBackdrop : emptyWallpaperSelectorInput",
    ),
    "modules/wallpaperLauncher/WallpaperLauncher.qml": (
        "readonly property bool acceptsInput: GlobalStates.wallpaperLauncherOpen",
        "WlrLayershell.keyboardFocus: root.acceptsInput",
        "root.acceptsInput ? launcherBackdrop : emptyWallpaperLauncherInput",
    ),
    "modules/controlPanel/ControlPanel.qml": (
        "readonly property bool acceptsInput: GlobalStates.controlPanelOpen",
        "WlrLayershell.keyboardFocus: panelRoot.acceptsInput",
        "panelRoot.acceptsInput ? backdropClickArea : emptyControlPanelInput",
    ),
    "modules/cheatsheet/Cheatsheet.qml": (
        "readonly property bool acceptsInput: root.cheatsheetOpen",
        "WlrLayershell.keyboardFocus: window.acceptsInput",
        "window.acceptsInput ? cheatsheetBackdrop : emptyCheatsheetInput",
    ),
    "modules/waffle/startMenu/WaffleStartMenu.qml": (
        "readonly property bool acceptsInput: GlobalStates.searchOpen",
        "WlrLayershell.keyboardFocus: panelWindow.acceptsInput",
        "panelWindow.acceptsInput ? content : emptyStartMenuPanelInput",
        "? startMenuBackdropMouse : emptyStartMenuBackdropInput",
    ),
    "modules/waffle/actionCenter/WaffleActionCenter.qml": (
        "readonly property bool acceptsInput: GlobalStates.waffleActionCenterOpen",
        "WlrLayershell.keyboardFocus: panelWindow.acceptsInput",
        "panelWindow.acceptsInput ? content : emptyActionCenterPanelInput",
        "? actionCenterBackdropMouse : emptyActionCenterBackdropInput",
    ),
    "modules/waffle/notificationCenter/WaffleNotificationCenter.qml": (
        "readonly property bool acceptsInput: GlobalStates.waffleNotificationCenterOpen",
        "WlrLayershell.keyboardFocus: panelWindow.acceptsInput",
        "panelWindow.acceptsInput ? content : emptyNotificationCenterPanelInput",
        "? notificationCenterBackdropMouse : emptyNotificationCenterBackdropInput",
    ),
    "modules/waffle/widgets/WaffleWidgets.qml": (
        "readonly property bool acceptsInput: GlobalStates.waffleWidgetsOpen",
        "WlrLayershell.keyboardFocus: panelWindow.acceptsInput",
        "panelWindow.acceptsInput ? content : emptyWidgetsPanelInput",
    ),
}

for path, tokens in contracts.items():
    source = read(path)
    require(source, "mask: Region", f"{path} must define an explicit pointer input region")
    for token in tokens:
        require(source, token, f"{path} lost input lifecycle token: {token}")

dashboard = read("modules/dashboard/Dashboard.qml")
require(
    dashboard,
    "item: GlobalStates.dashboardOpen\n                ? dashboardInputArea : emptyDashboardInputArea",
    "Dashboard is permanently mapped and must keep its existing zero-sized closed input region",
)

print("fullscreen input lifecycle contracts: ok")
