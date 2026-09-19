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
    styled_popup = read("modules/bar/StyledPopup.qml")
    popup = read("modules/bar/BarWorkspaceOverview.qml")
    niri = read("modules/overview/OverviewNiriWidget.qml")
    hypr = read("modules/overview/OverviewWidget.qml")
    runtime = read("modules/overview/Overview.qml")
    panels = read("modules/settings/InterfaceConfig.qml")
    overview_settings = read("modules/settings/OverviewConfig.qml")
    dashboard_settings = read("modules/settings/DashboardConfig.qml")
    arrangement = read("modules/settings/SettingsArrangement.qml")
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
    require(styled_popup, "property bool centerOnOutput: false",
            "shared popup geometry must expose output-centered tangent placement")
    require(popup, "centerOnOutput: true",
            "workspace Overview must remain centered on the target output")
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
    forbid(overview_settings, "overview.dashboard.",
           "Overview Settings must not own Dashboard controls")
    forbid(overview_settings, "overview.allAppsGrid",
           "Overview Settings must not expose launcher grid controls")
    forbid(overview_settings, "overview.switchToWorkspaceOnOpen",
           "Overview Settings must not expose retired launcher-workspace behavior")
    forbid(overview_settings, "overview.focusAnimationDurationMs",
           "Overview Settings must keep advanced motion tuning out of the primary UI")
    require(dashboard_settings, "overview.dashboard.enable",
            "Dashboard Settings must own compact launcher Dashboard integration")
    require(arrangement, "readonly property int layoutSchemaVersion: 5",
            "Settings arrangement must migrate the Overview page into Shell")
    require(arrangement, "root.overviewPageIndex",
            "Overview Shell placement migration must be explicit")
    require(registry, 'key: "overview"',
            "Settings registry must expose the dedicated Overview page")
    require(config, "property JsonObject workspaceHover: JsonObject",
            "typed config must define Overview workspace-hover behavior")
    require(defaults, '"workspaceHover": {',
            "persisted defaults must define Overview workspace-hover behavior")

    print("overview hover contracts: ok")

if __name__ == "__main__":
    main()
