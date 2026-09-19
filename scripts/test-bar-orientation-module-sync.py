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

    require(settings, 'visible: !root.isVertical',
            "Horizontal drag layout must not be presented as active for Left/Right Bar.")
    require(settings, 'Module visibility above stays synchronized with the active Bar',
            "Vertical Settings must explain the fixed-order visibility contract.")
    require(settings, "BarModuleOrderEditor {}",
            "Top/Bottom Bar must retain its existing drag layout editor.")

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

    required_vertical = {
        'leftSidebarButtonEnabled': 'root.moduleEnabled("leftSidebarButton", true)',
        'activeWindowEnabled': 'root.moduleEnabled("activeWindow", true)',
        'taskbarEnabled': 'root.moduleEnabled("taskbar", false)',
        'resourcesEnabled': 'root.moduleEnabled("resources", false)',
        'mediaEnabled': 'root.moduleEnabled("media", true)',
        'workspacesEnabled': 'root.moduleEnabled("workspaces", true)',
        'clockEnabled': 'root.moduleEnabled("clock", true)',
        'utilButtonsEnabled': 'root.moduleEnabled("utilButtons", false)',
        'batteryEnabled': 'root.moduleEnabled("battery", true)',
        'weatherEnabled': 'root.moduleEnabled("weather", true)',
        'sysTrayEnabled': 'root.moduleEnabled("sysTray", true)',
        'rightSidebarButtonEnabled': 'root.moduleEnabled("rightSidebarButton", true)',
    }
    for name, token in required_vertical.items():
        require(vertical, token,
                f"Vertical Bar no longer consumes canonical module state for {name}.")

    for token in (
        "visible: root.leftSidebarButtonEnabled",
        "visible: root.activeWindowEnabled",
        "visible: root.resourcesEnabled || root.mediaEnabled",
        "visible: root.workspacesEnabled",
        "visible: root.taskbarEnabled",
        "visible: root.utilButtonsEnabled",
        "visible: root.weatherEnabled",
        "visible: root.sysTrayEnabled",
        "visible: root.rightSidebarButtonEnabled",
    ):
        require(vertical, token,
                f"Vertical Bar module presentation is not bound to Settings: {token}")

    require(vertical, "visible: root.resourcesEnabled",
            "Vertical Resources must have an independent visibility binding.")
    require(vertical, "visible: root.mediaEnabled",
            "Vertical Media must have an independent visibility binding.")
    require(vertical, "visible: root.clockEnabled",
            "Vertical Clock must have an independent visibility binding.")
    require(vertical, "visible: root.batteryEnabled && Battery.available",
            "Vertical Battery must have an independent visibility binding.")
    forbid(vertical, 'visible: !(Config.options?.bar?.modules?.taskbar ?? false)',
           "Taskbar must not silently force Resources/Media off in Left/Right Bar.")
    forbid(vertical, 'visible: Config.options?.bar?.modules?.taskbar ?? false',
           "Vertical module visibility must go through the canonical module contract.")

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

    require(vertical, "Flickable { // Middle section",
            "Left/Right Bar must bound its middle module stack.")
    require(vertical, "middleAvailableHeight",
            "Left/Right Bar must reserve edge content before sizing its middle stack.")
    require(vertical, "compactRequested: root.verticalUtilitiesCompact",
            "Left/Right Utilities must compact only from real main-axis pressure.")
    require(vertical, "interactive: contentHeight > height + 0.5",
            "Overflowing middle modules must remain reachable rather than overlap.")

    require(critical, "extraCondition: !root.barVertical",
            "Horizontal Bar loader must remain selected only for Top/Bottom.")
    require(critical, "extraCondition: root.barVertical",
            "Vertical Bar loader must remain selected only for Left/Right.")

    print("Bar orientation/module sync contract: OK")


if __name__ == "__main__":
    main()
