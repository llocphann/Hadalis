#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"overview hover contract failed: {message}")

def forbid(text: str, token: str, message: str) -> None:
    if token in text:
        raise SystemExit(f"overview hover contract failed: {message}")

def main() -> None:
    workspaces = read("modules/bar/Workspaces.qml")
    popup = read("modules/bar/BarWorkspaceOverview.qml")
    niri = read("modules/overview/OverviewNiriWidget.qml")
    hypr = read("modules/overview/OverviewWidget.qml")
    runtime = read("modules/overview/Overview.qml")
    panels = read("modules/settings/InterfaceConfig.qml")
    overview_settings = read("modules/settings/OverviewConfig.qml")
    registry = read("modules/settings/SettingsPageRegistryData.qml")
    config = read("modules/common/Config.qml")
    defaults = read("defaults/config.json")

    require(workspaces, "workspaceOverviewPopup.showWorkspace(workspaceId, button)",
            "workspace hover must route to the connected Overview popup")
    require(workspaces, "workspaceOverviewHoverEnabled",
            "workspace hover must have a dedicated Overview enable gate")
    require(popup, "StyledPopup {",
            "workspace Overview must attach through shared Bar popup geometry")
    require(popup, "preferredWorkspaceId: root.workspaceId",
            "hovered workspace must anchor the visible Overview group")
    require(niri, "property bool embeddedSurface: false",
            "Niri Overview must support embedded popup rendering")
    require(niri, "property bool presentationActive: GlobalStates.overviewOpen",
            "Niri preview lifecycle must be decoupled from full-screen Overview state")
    require(hypr, "property bool embeddedSurface: false",
            "Hyprland Overview must support embedded popup rendering")
    require(runtime, "active: root.shouldShow && root.taskViewMode",
            "normal launcher must not instantiate the old full-screen workspace Overview")
    forbid(panels, 'settingsTaskSection: "overview"',
           "Panels settings must no longer own Overview")
    require(overview_settings, "settingsPageIndex: 29",
            "Overview must have a dedicated Settings page")
    require(registry, 'key: "overview"',
            "Settings registry must expose the dedicated Overview page")
    require(config, "property JsonObject workspaceHover: JsonObject",
            "typed config must define Overview workspace-hover behavior")
    require(defaults, '"workspaceHover": {',
            "persisted defaults must define Overview workspace-hover behavior")

    print("overview hover contracts: ok")

if __name__ == "__main__":
    main()
