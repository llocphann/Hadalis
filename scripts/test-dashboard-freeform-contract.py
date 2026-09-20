#!/usr/bin/env python3
"""Regression contract for the freeform Dashboard canvas and adaptive modules."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} missing Dashboard freeform token: {token!r}")

def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} contains retired Dashboard token: {token!r}")

def main() -> None:
    content = read("modules/dashboard/DashboardContent.qml")
    canvas = read("modules/dashboard/DashboardCanvas.qml")
    grid = read("modules/dashboard/DashboardEditGrid.qml")
    header = read("modules/dashboard/DashboardHeader.qml")
    weather = read("modules/dashboard/DashWeather.qml")
    orbital = read("modules/bar/weather/OrbitalWeather.qml")
    calendar = read("modules/dashboard/DashCalendar.qml")
    month = read("modules/common/widgets/ObsidianMonthCalendar.qml")
    media = read("modules/dashboard/DashMedia.qml")
    config = read("modules/common/Config.qml")
    settings = read("modules/settings/DashboardConfig.qml")

    require(content, "DashboardCanvas {", "DashboardContent.qml")
    require(canvas, "import qs.modules.common.functions", "DashboardCanvas.qml")
    forbid(content, "component WidgetColumn:", "DashboardContent.qml")
    forbid(content, "dashboard.layout.", "DashboardContent.qml")

    for token in (
        'color: root.embeddedSurface ? "transparent" : Appearance.colors.colLayer0',
        'radius: root.embeddedSurface ? 0 : Appearance.rounding.large',
        "border.width: 0",
    ):
        require(content, token, "DashboardContent.qml")
    for token in (
        "ColorQuantizer {",
        "AdaptedMaterialScheme {",
        "ZzzPanelBackdrop {",
        "ZzzPlate {",
        "id: blurredWallpaper",
        "useWallpaperBackdrop",
        "wallpaperDominantColor",
    ):
        forbid(content, token, "DashboardContent.qml")

    for token in (
        'Config.options?.dashboard?.canvas?.widgets',
        'property bool editMode: false',
        'function beginMove(',
        'function beginResize(',
        'function updateInteraction(',
        'function finishInteraction(',
        'enabled: root.editMode',
        'enabled: !root.editMode',
        'DashboardEditGrid {',
        'Config.options?.dashboard?.canvas?.gridSize',
        'Config.options?.dashboard?.canvas?.gridStyle',
        'Config.options?.dashboard?.canvas?.snap',
    ):
        require(canvas, token, "DashboardCanvas.qml")

    for edge in ("n", "s", "e", "w", "nw", "ne", "sw", "se"):
        require(canvas, f'edge: "{edge}"', "DashboardCanvas.qml")

    for token in (
        'property string gridStyle: "dots"',
        'gridStyle === "lines"',
        'gridStyle === "cross"',
    ):
        require(grid, token, "DashboardEditGrid.qml")

    require(header, 'root.editMode ? "done" : "edit"', "DashboardHeader.qml")
    require(header, "onClicked: root.editModeRequested()", "DashboardHeader.qml")

    require(weather, "OrbitalWeather {", "DashWeather.qml")
    for token in (
        "function hourFromLabel(label): real",
        "function arcAngle(startAngle, endAngle, fraction): real",
        "function orbitAngleForHour(label): real",
    ):
        require(orbital, token, "OrbitalWeather.qml")

    require(calendar, "dashboardAdaptive: true", "DashCalendar.qml")
    for token in (
        "property bool autoWeekNumbers: false",
        "readonly property bool effectiveWeekNumbers:",
        "function isoWeekNumber(value): int",
        'text: Translation.tr("WK")',
    ):
        require(month, token, "ObsidianMonthCalendar.qml")

    require(media, "import qs.modules.mediaControls", "DashMedia.qml")
    require(media, "EqualizerPanel {", "DashMedia.qml")
    require(media, "active: root.presentationActive && root.visible", "DashMedia.qml")
    require(canvas, "presentationActive: root.presentationActive", "DashboardCanvas.qml")

    for token in (
        "property JsonObject canvas: JsonObject {",
        "property int gridSize: 24",
        "property bool snap: true",
        'property string gridStyle: "dots"',
        "property list<var> widgets:",
    ):
        require(config, token, "Config.qml")

    for token in (
        'title: Translation.tr("Canvas & grid")',
        'Config.setNestedValue("dashboard.canvas.snap", checked)',
        'Config.setNestedValue("dashboard.canvas.gridStyle", value)',
        'Config.setNestedValue("dashboard.canvas.gridSize", value)',
    ):
        require(settings, token, "DashboardConfig.qml")

    print("Dashboard freeform canvas contract: OK")

if __name__ == "__main__":
    main()
