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
    require(util, "columns: root.vertical ? 1",
            "Utility buttons must stack vertically in Left/Right Bar.")

    require(critical, "extraCondition: !root.barVertical",
            "Horizontal Bar loader must remain selected only for Top/Bottom.")
    require(critical, "extraCondition: root.barVertical",
            "Vertical Bar loader must remain selected only for Left/Right.")

    print("Bar orientation/module sync contract: OK")


if __name__ == "__main__":
    main()
