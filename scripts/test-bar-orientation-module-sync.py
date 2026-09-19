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

    if vertical.count("required property string modelData") != 1:
        raise SystemExit(
            "VerticalModuleCell must declare required modelData exactly once; "
            "the Repeater delegate must not redeclare it."
        )

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
