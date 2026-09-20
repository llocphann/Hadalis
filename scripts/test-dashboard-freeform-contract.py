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
    toolbar = read("modules/dashboard/DashboardEditToolbar.qml")
    standalone = read("modules/dashboard/Dashboard.qml")
    overview = read("modules/overview/OverviewDashboard.qml")
    system = read("modules/dashboard/DashSystem.qml")
    calendar_widget = read("modules/sidebarRight/calendar/CalendarWidget.qml")
    weather = read("modules/dashboard/DashWeather.qml")
    orbital = read("modules/bar/weather/OrbitalWeather.qml")
    calendar = read("modules/dashboard/DashCalendar.qml")
    month = read("modules/common/widgets/ObsidianMonthCalendar.qml")
    media = read("modules/dashboard/DashMedia.qml")
    dash_card = read("modules/dashboard/DashCard.qml")
    config = read("modules/common/Config.qml")
    defaults = read("defaults/config.json")
    settings = read("modules/settings/DashboardConfig.qml")

    require(content, "DashboardCanvas {", "DashboardContent.qml")
    require(canvas, "import qs.modules.common.functions", "DashboardCanvas.qml")
    forbid(canvas, "id: editToolbar", "DashboardCanvas.qml")
    forbid(canvas, "showStandaloneEditButton", "DashboardCanvas.qml")
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
        'function _snapshotVisibleRects(',
        'function _resolveLayout(',
        'function _resolveNeighbour(',
        'function _resolveFeasibleLayout(',
        'function _layoutHasOverlap(',
        'function _persistPreviewLayout(',
        'A restored widget must join the same collision contract as drag/resize.',
        'case "system": return { width: 260, height: 180 }',
        'baselineRects: root._snapshotVisibleRects()',
        'root._applyPreviewRects(resolved)',
        'A dragged module is temporarily lifted out of the packed layout.',
        'Drop is the insertion point: resolve neighbours exactly',
        'function _snapRectForCommit(',
        'Pointer tracking ends before the final target is published.',
        'readonly property bool animateGeometry:',
        'readonly property real collisionGap: Math.max(8,',
        'enabled: root.editMode',
        'enabled: !root.editMode',
        'DashboardEditGrid {',
        'Config.options?.dashboard?.canvas?.gridSize',
        'Config.options?.dashboard?.canvas?.gridStyle',
        'Config.options?.dashboard?.canvas?.snap',
        'Config.options?.dashboard?.canvas?.autoAdjustSize',
        'readonly property bool autoAdjustSizeEnabled:',
        'state.kind === "resize"',
        '&& root.autoAdjustSizeEnabled',
        'allowResize',
    ):
        require(canvas, token, "DashboardCanvas.qml")

    for edge in ("n", "s", "e", "w", "nw", "ne", "sw", "se"):
        require(canvas, f'edge: "{edge}"', "DashboardCanvas.qml")

    for token in (
        "model: root._allIds",
        "root._entryFor(id).visible !== false",
        "root._entryFor(id).visible === false",
        "active: cardWrap.visible",
        "prevents Repeater/model churn",
    ):
        require(canvas, token, "DashboardCanvas.qml")
    forbid(canvas,
        "root.geometryFor(id).visible !== false",
        "DashboardCanvas visibility model")
    forbid(canvas,
        "model: root.visibleIds",
        "DashboardCanvas repeater model")

    move_start = canvas.index('if (state.kind === "move") {')
    move_end = canvas.index('const edge = String(state.edge ?? "")', move_start)
    move_block = canvas[move_start:move_end]
    require(move_block, "root._setPreview(state.id, {", "DashboardCanvas move block")
    forbid(move_block, "root._resolveFeasibleLayout(", "DashboardCanvas move block")
    forbid(move_block, "root._snap(", "DashboardCanvas move block")
    # Drag/drop may move neighbours but must never resize them; size adaptation
    # is exclusive to resize interactions and controlled by autoAdjustSize.
    resolve_start = canvas.index("function _candidateInRegion(")
    resolve_end = canvas.index("function _applyPreviewRects(", resolve_start)
    resolve_block = canvas[resolve_start:resolve_end]
    require(resolve_block, "allowResize", "DashboardCanvas collision resolver")
    require(resolve_block,
        "const width = allowResize", "DashboardCanvas collision resolver")
    require(resolve_block,
        "const heights = allowResize ?", "DashboardCanvas collision resolver")

    finish_start = canvas.index("function finishInteraction(commit)")
    finish_end = canvas.index("function _cycleGridSize()", finish_start)
    finish_block = canvas[finish_start:finish_end]
    require(finish_block, "root._resolveFeasibleLayout(", "DashboardCanvas drop block")
    require(finish_block, "root._persistPreviewLayout()", "DashboardCanvas drop block")
    require(finish_block, "root._snapRectForCommit(", "DashboardCanvas drop block")
    require(finish_block,
        'const allowResize = state.kind === "resize"',
        "DashboardCanvas drop block")
    require(finish_block,
        "&& root.autoAdjustSizeEnabled",
        "DashboardCanvas drop block")
    require(finish_block, "root._interaction = null", "DashboardCanvas drop block")
    require(finish_block, "Qt.callLater(() => {", "DashboardCanvas drop block")

    for token in (
        'property string gridStyle: "dots"',
        'gridStyle === "lines"',
        'gridStyle === "cross"',
    ):
        require(grid, token, "DashboardEditGrid.qml")

    require(header, 'root.editMode ? "done" : "edit"', "DashboardHeader.qml")
    require(header, "onClicked: root.editModeRequested()", "DashboardHeader.qml")

    for token in (
        "required property var canvasController",
        "visible: root.editing",
        "bottomLeftRadius: 0",
        "bottomRightRadius: 0",
        'Translation.tr("Edit widgets")',
        "id: editActions",
        "Layout.alignment: Qt.AlignHCenter",
        "focusPolicy: Qt.StrongFocus",
        'Config.setNestedValue(\n                    "dashboard.canvas.autoAdjustSize"',
        "border.width: tool.visualFocus ? 2 : (tool.toggled ? 1 : 0)",
    ):
        require(toolbar, token, "DashboardEditToolbar.qml")
    for source, text in (
        ("Dashboard.qml", standalone),
        ("OverviewDashboard.qml", overview),
    ):
        require(text, "DashboardEditToolbar {", source)
    require(overview,
        "x: Math.round(dashContainer.x", "OverviewDashboard.qml")
    require(overview,
        "y: Math.round(dashContainer.y - height + 1)", "OverviewDashboard.qml")
    require(standalone,
        "x: Math.round((parent.width - width) / 2)", "Dashboard.qml")
    require(standalone, "y: 0", "Dashboard.qml")

    require(canvas, "cursorShape: root.editMode", "DashboardCanvas.qml")
    require(canvas, ": Qt.ArrowCursor", "DashboardCanvas.qml")
    require(canvas, "width: corner ? 8 : (horizontal ? 24 : 6)", "DashboardCanvas.qml")
    require(canvas, "height: corner ? 8 : (vertical ? 24 : 6)", "DashboardCanvas.qml")
    require(canvas, "anchors.margins: -4", "DashboardCanvas.qml")

    for token in (
        "Behavior on x {",
        "Behavior on y {",
        "Behavior on width {",
        "Behavior on height {",
        "Appearance.animation.elementMoveFast.duration",
        "Appearance.animation.elementResize.duration",
        "&& cardWrap.animateGeometry",
    ):
        require(canvas, token, "DashboardCanvas.qml")

    for token in (
        "anchors.centerIn: parent",
        "width: Math.min(parent.width, 220)",
        "height: Math.min(parent.height, 104)",
    ):
        require(system, token, "DashSystem.qml")
    for token in (
        "ThinkFanService.refresh()",
        "ThinkFanService.applyProfile(",
        'Translation.tr("Fan")',
        'Translation.tr("RPM:")',
        'Translation.tr("Level:")',
        "ThinkFanService.fanRpm",
        "ThinkFanService.fanLevel",
    ):
        require(system, token, "DashSystem.qml")
    require(calendar_widget,
        "anchors.verticalCenter: root.dashboardAdaptive",
        "CalendarWidget.qml")
    require(month,
        "? Math.max(root.implicitWidth, root.width)",
        "ObsidianMonthCalendar.qml")

    for token in (
        "radius: Appearance.rounding.small",
        "Appearance.colors.colSurfaceContainerHigh",
        "border.width: 0",
        'border.color: "transparent"',
    ):
        require(dash_card, token, "DashCard.qml")
    for token in (
        "AngelPartialBorder {",
        "ZzzGraphicPlate {",
        "gradient: Gradient {",
    ):
        forbid(dash_card, token, "DashCard.qml")

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
        "property bool autoAdjustSize: true",
        'property string gridStyle: "dots"',
        "property list<var> widgets:",
    ):
        require(config, token, "Config.qml")

    require(defaults, '"autoAdjustSize": true', "defaults/config.json")

    for token in (
        'title: Translation.tr("Canvas & grid")',
        'Config.setNestedValue("dashboard.canvas.snap", checked)',
        'Config.setNestedValue(\n                        "dashboard.canvas.autoAdjustSize", checked)',
        'Config.setNestedValue("dashboard.canvas.gridStyle", value)',
        'Config.setNestedValue("dashboard.canvas.gridSize", value)',
    ):
        require(settings, token, "DashboardConfig.qml")

    print("Dashboard freeform canvas contract: OK")

if __name__ == "__main__":
    main()
