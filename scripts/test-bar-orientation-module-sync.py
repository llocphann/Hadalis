#!/usr/bin/env python3
"""Guard Classic Bar module visibility parity across horizontal and vertical edges."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)


def forbid(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(message)


def main() -> None:
    vertical = read("modules/verticalBar/VerticalBarContent.qml")
    settings = read("modules/settings/BarConfig.qml")
    editor = read("modules/common/widgets/BarModuleOrderEditor.qml")
    config = read("modules/common/Config.qml")
    defaults = read("defaults/config.json")
    util = read("modules/bar/UtilButtons.qml")
    weather_bar = read("modules/bar/weather/WeatherBar.qml")
    vertical_media = read("modules/verticalBar/VerticalMedia.qml")
    workspace_overview = read("modules/bar/BarWorkspaceOverview.qml")
    overview_niri = read("modules/overview/OverviewNiriWidget.qml")
    overview_hypr = read("modules/overview/OverviewWidget.qml")
    timer_indicator = read("modules/bar/TimerIndicator.qml")
    shell_update_indicator = read("modules/bar/ShellUpdateIndicator.qml")
    critical = read("modules/ii/critical/ShellIiCriticalPanels.qml")

    require(settings,
            'readonly property bool isVertical: Config.options?.bar?.vertical ?? false',
            "Bar Settings must react to the same orientation field used by the runtime.")
    for key in (
        "leftSidebarButton", "activeWindow", "taskbar", "sysTray", "resources",
        "media", "workspaces", "clock", "utilButtons", "battery", "weather",
        "rightSidebarButton",
    ):
        require(settings, f'bar.modules.{key}',
                f"Bar Settings lost canonical module key: {key}")

    require(settings, "verticalPreset: root.isVertical",
            "Bar Settings must edit the preset matching the active orientation.")
    require(settings, '"bar.verticalLayout.spacerHeight"',
            "Left/Right Bar Settings must persist an independent spacer height.")
    require(settings, '"bar.verticalLayout.spacerMode"',
            "Left/Right Bar Settings must persist an independent spacer mode.")
    forbid(settings, "compact fixed vertical order",
           "Left/Right Bar must no longer advertise a fixed module order.")

    for token in (
        "property JsonObject verticalLayout: JsonObject {",
        'property list<string> top: ["leftSidebarButton", "activeWindow", "spacer"]',
        'property list<string> centerTop: ["resources", "media"]',
        'property list<string> center: ["workspaces"]',
        'property list<string> centerBottom: ["clock", "utilButtons", "battery"]',
        'property list<string> bottom: ["weather", "tray", "timer", "shellUpdate", "spacer", "rightSidebarButton"]',
        "property int spacerHeight: 0",
    ):
        require(config, token, f"Vertical layout schema missing: {token}")

    require(defaults, '"verticalLayout": {',
            "Fresh-install config must include the independent Left/Right preset.")

    for token in (
        "property bool verticalPreset: false",
        'root.verticalPreset ? "bar.verticalLayout" : "bar.layout"',
        '["top", "centerTop", "center", "centerBottom", "bottom"]',
        'Translation.tr("Top edge")',
        'Translation.tr("Center top")',
        'Translation.tr("Center bottom")',
        'Translation.tr("Bottom edge")',
    ):
        require(editor, token, f"Bar layout editor is not orientation-aware: {token}")
    forbid(editor, 'Config.setNestedValue("bar.layout." + toZone',
           "Editor mutations must target the selected orientation preset.")

    for token in (
        'Config.options?.bar?.verticalLayout?.[name]',
        'readonly property var _topIds:',
        'readonly property var _centerTopIds:',
        'readonly property var _centerIds:',
        'readonly property var _centerBottomIds:',
        'readonly property var _bottomIds:',
        'verticalCenter: parent.verticalCenter',
        'zoneName: "top"',
        'zoneName: "centerTop"',
        'zoneName: "center"',
        'zoneName: "centerBottom"',
        'zoneName: "bottom"',
        'Bar.TimerIndicator { vertical: true }',
        'Bar.ShellUpdateIndicator { vertical: true }',
    ):
        require(vertical, token, f"Vertical Bar lost data-driven preset behavior: {token}")

    require(editor, 'if (toZone === "center" && id !== "workspaces") return',
            "Layout editor must protect the centered Workspaces pivot.")
    require(editor, 'enabled: zoneCard.zoneName !== "center"',
            "Pivot zone must reject drag/drop of ordinary modules.")

    require(vertical, "required property string modelData",
            "VerticalModuleCell must keep a modelData contract for its Repeater.")
    forbid(vertical,
           'delegate: VerticalModuleCell {\n                    required property string modelData',
           "Vertical delegate must not redeclare required modelData.")
    forbid(vertical, "moduleLoader.item.visible",
           "Vertical cell visibility must not depend on effective child visibility.")
    forbid(vertical, "readonly property bool sourceVisible",
           "Vertical renderer must not feed loaded-item visibility back into its parent.")
    forbid(vertical, "visible: implicitHeight > 0",
           "Vertical zones must stay instantiated while their natural size bootstraps.")
    forbid(vertical, "id: moduleLoader\n            anchors.fill: parent",
           "Vertical module Loader must not fill the main axis it is measuring.")
    require(vertical, "anchors.horizontalCenter: parent.horizontalCenter",
            "Vertical module Loader must preserve natural main-axis height.")
    require(vertical, "import qs.modules.bar.weather as BarWeather",
            "Vertical Bar must import the shared Weather renderer.")
    require(vertical, "BarWeather.WeatherBar {",
            "Left/Right Weather must reuse the Top/Bottom Weather control.")
    require(vertical, "vertical: true",
            "Left/Right Weather must request the compact icon-only presentation.")
    forbid(vertical, 'buttonText: Translation.tr("Weather")',
           "Vertical Weather must not paint a literal Weather label over its icon.")
    require(weather_bar, "property bool vertical: false",
            "Shared Weather control must expose an orientation-safe compact mode.")
    require(weather_bar, "visible: !root.vertical",
            "Vertical Weather must hide its inline temperature text.")
    require(weather_bar, "WeatherPopup {",
            "Shared Weather control must retain the Weather popup for both orientations.")

    require(vertical_media,
            "alternativeVisibleCondition:\n            root.volumePopupVisible",
            "Left/Right Media volume HUD must appear only after a volume action.")
    forbid(vertical_media, "(root.volumePopupVisible || root.containsMouse)",
           "Plain hover over Left/Right Media must not show the speaker/volume HUD.")

    require(workspace_overview, "readonly property bool transposeOverviewGrid:",
            "Workspace hover Overview must detect Left/Right Bar orientation.")
    if workspace_overview.count("transposeGrid: root.transposeOverviewGrid") != 2:
        raise SystemExit(
            "Workspace hover Overview must transpose both Niri and Hyprland renderers."
        )

    for overview, name in ((overview_niri, "Niri"), (overview_hypr, "Hyprland")):
        require(overview, "property bool transposeGrid: false",
                f"{name} Overview must expose presentation-only grid transpose.")
        require(overview, "configuredOverviewRows",
                f"{name} Overview must preserve the configured row count.")
        require(overview, "configuredOverviewColumns",
                f"{name} Overview must preserve the configured column count.")
        require(overview, "root.transposeGrid",
                f"{name} Overview must derive effective rows/columns from orientation.")

    forbid(overview_hypr, "Config.options.overview.rows",
           "Hyprland Overview workspace layout must use effective overviewRows.")
    forbid(overview_hypr, "Config.options.overview.columns",
           "Hyprland Overview workspace layout must use effective overviewColumns.")
    require(timer_indicator,
            "? ((anyActive || showPinnedIdle) ? 34 : 0)",
            "Inactive vertical Timer must collapse to zero main-axis height.")
    require(shell_update_indicator,
            "? ((ShellUpdates.showUpdate || ShellUpdates.isUpdating) ? 34 : 0)",
            "Inactive vertical update indicator must collapse to zero main-axis height.")

    require(util, "property bool vertical: false",
            "Utility buttons must expose an orientation-safe presentation switch.")
    require(util, "property bool compactRequested: false",
            "Utility buttons must expose pressure-driven compact state.")
    require(util, "readonly property real expandedMainAxisLength",
            "Utility buttons must expose their expanded main-axis size.")
    require(util, "Revealer {",
            "Pressure-compacted utilities must reveal inline on the Bar.")
    require(util, "columns: root.vertical ? 1",
            "Expanded utility controls must stack vertically in Left/Right Bar.")
    forbid(util, "StyledPopup {",
           "Utility expansion must remain inline and must not create a popup.")

    require(vertical, "readonly property real topPressure:",
            "Left/Right Bar must measure upper-half pressure.")
    require(vertical, "readonly property real bottomPressure:",
            "Left/Right Bar must measure lower-half pressure.")
    require(vertical, "compactRequested: root.verticalUtilitiesCompact",
            "Left/Right Utilities must compact only from real main-axis pressure.")
    require(vertical, "interactive: contentHeight > height + 0.5",
            "Overflowing vertical zones must remain reachable rather than overlap.")

    require(critical, "extraCondition: !root.barVertical",
            "Horizontal Bar loader must remain selected only for Top/Bottom.")
    require(critical, "extraCondition: root.barVertical",
            "Vertical Bar loader must remain selected only for Left/Right.")

    print("Bar orientation/module sync contract: OK")


if __name__ == "__main__":
    main()
