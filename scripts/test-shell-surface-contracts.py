#!/usr/bin/env python3
"""Regression checks for shell surface, dock, Waffle, and English-only contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    readme = read("README.md")
    check("### 2.1 Locked ownership contract — single Caelestia-style inverted frame" in readme
          and "Normal Bar mode owns only the Bar body" in readme
          and "`scripts/test-shell-surface-contracts.py` is the regression gate" in readme,
          "README must retain the maintainer-approved single-owner perimeter contract")

    styled_popup = read("modules/bar/StyledPopup.qml")
    for token in (
        "qs.modules.common.perimeter",
        "ConnectedSurfaceGeometry",
        "ConnectedSurfaceFrame",
        "ConnectedSurfaceRevealClip",
        "ConnectedSurfaceContentHost",
        "ConnectedSurfaceMask",
        "mask: connectedMask",
        "ExclusionMode.Ignore",
        "Appearance.colors.colLayer0",
        "PerimeterTokens.popupRadius",
        "geometry.revealProgress",
        "CompositorFocusGrab",
        "WlrKeyboardFocus.OnDemand",
        "requestedVisible",
        "_lingerVisible",
        "retractTimer",
        "progress: root.revealProgress",
        "property real offsetScale: 1",
        "readonly property real revealProgress: 1 - root.offsetScale",
        "Behavior on offsetScale",
        "|| root.popupHovered",
        "enabled: root.active",
    ):
        check(token in styled_popup, f"StyledPopup must preserve connected-perimeter contract: {token}")
    for edge in ("top", "bottom", "left", "right"):
        check(f'"{edge}"' in styled_popup,
              f"StyledPopup must preserve {edge} attachment handling")
    check("Appearance.colors.colSurfaceContainer" not in styled_popup,
          "Connected bar popups must use the owning bar surface family, not the detached popup-card material")
    check("root._anchorReady" in styled_popup
          and "root.requestedVisible || root._lingerVisible" in styled_popup,
          "Connected popout loader must require a real anchor and stay resident long enough to retract into it")
    check("cornerStyle" not in styled_popup,
          "Connected bar popouts must not branch on retired Classic Bar corner styles")
    check("Appearance.zzz.chromeAlt" not in styled_popup
          and "Appearance.regalia.barSurfaceFloating" not in styled_popup,
          "Connected bar popouts must use the Hug surface family only")

    perimeter_tokens = read("modules/common/perimeter/PerimeterTokens.qml")
    for token in (
        "readonly property real frameRadius: 25",
        "readonly property real smoothUnionRadius: 20",
        "readonly property real popupRadius: 28",
        "readonly property real joinFlareRadius: smoothUnionRadius",
        "readonly property real joinFlareCrossScale: 0.55",
    ):
        check(token in perimeter_tokens,
              f"Caelestia geometry token missing: {token}")

    geometry = read("modules/common/perimeter/ConnectedSurfaceGeometry.qml")
    for edge in ("top", "bottom", "left", "right"):
        check(f'edge === "{edge}"' in geometry,
              f"ConnectedSurfaceGeometry missing {edge} edge handling")
    for token in (
        "seamOverlap",
        "effectiveSeamOverlap",
        "devicePixelRatio",
        "function pixelScale()",
        "function snap(",
        "connectorSourceExtent",
        "connectorBodyExtent",
        "animatedTangentExtent",
        "animatedCrossExtent",
        "revealProgress",
        "motionProgress",
        "connectorRectForBody",
        "animatedBodyRect",
    ):
        check(token in geometry,
              f"ConnectedSurfaceGeometry missing seam/morph geometry contract: {token}")
    check("property real connectorWidth: PerimeterTokens.connectorWidth" in geometry,
          "ConnectedSurfaceGeometry must source popup connector width from the shared perimeter token")
    check("Math.max(Math.max(0, connectorWidth), anchorTangentExtent)" not in geometry,
          "Connected popup neck width must not expand or shrink with the source control width")
    check("(1 - motionProgress) * crossBodyExtent" in geometry,
          "Connected popup motion must translate the complete body with the expressive spatial scalar")
    check("readonly property real revealProgress: clamp(progress, 0, 1)" in geometry
          and "readonly property real motionProgress:" in geometry,
          "Connected popup must clamp semantic reveal while preserving spatial overshoot for translation")
    check("readonly property rect revealClipRect:" in geometry,
          "Connected popup reveal must expose a fixed resting-edge clip")
    check("readonly property rect visibleBodyRect:" in geometry,
          "Connected popup input must follow only the revealed body segment")
    check("crossBodyExtent * revealProgress" not in geometry,
          "Connected popup reveal must not shrink the body cross-axis")
    check("(bodyTangentExtent - connectorSourceExtent) * revealProgress" not in geometry,
          "Connected popup reveal must not expand from a narrow neck")
    check("bodyRect.width, bodyRect.height" in geometry,
          "Connected popup slide must preserve the full body size")
    check("tangentAnimationOffset" not in geometry
          and "tangentRevealDirection" not in geometry,
          "Connected popup slide must remain on the attachment axis like Caelestia wrappers")
    check("seamOverlap: 0" in styled_popup,
          "Bar popup must start exactly at the attachment boundary so the flat shoulder is fully visible")
    check("ConnectedSurfaceRevealClip {" in styled_popup
          and "opacity: 1" in styled_popup,
          "Connected popup must use pure slide-under clipping instead of staged fade/scale")

    content_host = read("modules/common/perimeter/ConnectedSurfaceContentHost.qml")
    for token in ("geometry.animatedBodyRect", "effectivePadding", "clip: true"):
        check(token in content_host,
              f"ConnectedSurfaceContentHost must centralize live padded body placement: {token}")

    connector = read("modules/common/perimeter/ConnectedSurfaceConnector.qml")
    check("Canvas {" in connector,
          "ConnectedSurfaceConnector must render a shaped shoulder rather than a rectangular stem")
    check("bezierCurveTo" in connector,
          "ConnectedSurfaceConnector must retain curved shoulder transitions")
    check("connectorSourceExtent" in connector,
          "ConnectedSurfaceConnector must narrow toward the real bar anchor")

    join_flares = read("modules/common/perimeter/ConnectedSurfaceJoinFlares.qml")
    for token in (
        "readonly property point bodyOrigin:",
        "root.bodyItem.mapToItem(root, 0, 0)",
        "root.bodyOrigin.x",
        "root.bodyOrigin.y",
    ):
        check(token in join_flares,
              f"Join flares must map nested body coordinates into their host: {token}")

    check("hoverEnabled: root.active" in styled_popup
          and "onBodyHoveredChanged: root._bodyHovered = bodyHovered" in styled_popup
          and "readonly property bool popupHovered: root._bodyHovered || root._contentHovered" in styled_popup,
          "StyledPopup hover bridge must track body and content without a seam-triggered retract")
    check("property QtObject _hoverTransferTimerObject: Timer {" in styled_popup
          and "interval: 90" in styled_popup
          and "hoverTransferTimer.restart()" in styled_popup,
          "StyledPopup must debounce the compositor leave/enter hand-off across Bar and popup windows")

    round_corner = read("modules/common/widgets/RoundCorner.qml")
    check("PathCubic {" in round_corner
          and "PathAngleArc {" not in round_corner
          and "readonly property real _k: 0.5522847498307936" in round_corner,
          "Screen Edge/Bar inverse corners must use the shared circular cubic geometry")
    for token in (
        "RoundCorner.CornerEnum.TopLeft",
        "RoundCorner.CornerEnum.TopRight",
        "RoundCorner.CornerEnum.BottomLeft",
        "RoundCorner.CornerEnum.BottomRight",
    ):
        check(token in round_corner,
              f"RoundCorner must preserve all four orientations: {token}")
    check("id: shadowCanvas" in round_corner
          and "ctx.arc(" in round_corner
          and "property real shadowExtent: 0" in round_corner,
          "RoundCorner must carry the inward shadow around the circular arc")

    screen_edge = read("modules/screenCorners/ScreenEdges.qml")
    check("Config.options?.appearance?.screenEdge?.width ?? 10" in screen_edge,
          "Screen Edge must default to 10px while remaining user-adjustable")
    check("screenEdge?.radius" not in screen_edge
          and "PerimeterTokens.frameRadius" not in screen_edge
          and "RoundCorner {" not in screen_edge
          and "readonly property int rounding: 25" in screen_edge
          and "readonly property int outerPadding: 50" in screen_edge,
          "Screen Edge must use Caelestia's 25px inner rounding and 50px outer frame padding")
    check("screenEdge?.enable" not in screen_edge,
          "Screen Edge must not be disabled by stale persisted enable flags")
    check("!GlobalStates.screenLocked" in screen_edge and "!fullscreenCovered" in screen_edge,
          "Screen Edge must stay mapped normally and hide only for lock/fullscreen coverage")
    check("mask: Region { item: emptyFrameInput }" in screen_edge
          and "mask: Region { item: emptyReservationInput }" in screen_edge,
          "Screen Edge frame and reservation surfaces must remain completely click-through")
    for retired_shadow in (
        "id: edgeShadow",
        "shadowEnabled",
        "shadowExtent",
        "shadowOpacity",
        "shadowColor",
        "screenEdge?.shadow",
        "GradientStop",
        "MultiEffect",
    ):
        check(retired_shadow not in screen_edge,
              f"Physical Screen Edge must remain shadow-free: {retired_shadow}")
    check("component FrameWindow: PanelWindow" in screen_edge
          and "component ReservationWindow: PanelWindow" in screen_edge
          and "implicitHeight: horizontal ? root.thickness : 1" in screen_edge
          and "implicitWidth: horizontal ? 1 : root.thickness" in screen_edge,
          "One full-screen frame must own paint while transparent thin windows reserve work-area space")
    check("exclusiveZone: 0" not in screen_edge
          and screen_edge.count("exclusionMode: ExclusionMode.Ignore") == 1,
          "Full-screen Screen Edge frame must ignore reservations without resetting itself to normal exclusion mode")
    check("exclusiveZone: mapped ? root.thickness : 0" in screen_edge,
          "Transparent Screen Edge reservation windows must reserve the configured physical edge thickness")
    check("const iiOwned = !root.waffleFamily" in screen_edge
          and "!(Config.options?.bar?.autoHide?.enable ?? false)" in screen_edge,
          "Auto-hide ii Bar must hand physical edge ownership to ScreenEdges.qml")
    for retired_geometry in (
        "PERIMETER-CORNER-LOCK",
        "id: leadingCorner",
        "id: trailingCorner",
        "RoundCorner.CornerEnum",
        "PathCubic",
        "RadialGradient",
    ):
        check(retired_geometry not in screen_edge,
              f"Screen Edge must not restore retired corner implementations: {retired_geometry}")
    check("import QtQuick.Shapes" in screen_edge
          and "component FrameWindow: PanelWindow" in screen_edge
          and "fillRule: ShapePath.OddEvenFill" in screen_edge
          and "preferredRendererType: Shape.CurveRenderer" in screen_edge,
          "Physical Screen Edge must be one antialiased odd-even frame geometry")
    check("SCREEN-EDGE-GEOMETRY-LOCK (maintainer approved 2026-09-19)" in screen_edge,
          "Approved Screen Edge four-corner geometry lock marker must remain present")
    check(screen_edge.count("Shape {") == 1
          and screen_edge.count("ShapePath {") == 1
          and screen_edge.count("PathMove {") == 1
          and screen_edge.count("direction: PathArc.Clockwise") == 4,
          "Screen Edge must keep one and only one painted inverted-frame path")
    for locked_geometry in (
        "readonly property int rounding: 25",
        "readonly property int outerPadding: 50",
        "readonly property real innerLeft: t",
        "readonly property real innerTop: t",
        "readonly property real innerRight: frameShape.width - t",
        "readonly property real innerBottom: frameShape.height - t",
        "startX: -root.outerPadding",
        "startY: -root.outerPadding",
        "x: frameShape.width + root.outerPadding",
        "y: frameShape.height + root.outerPadding",
        "x: framePath.innerLeft + framePath.r",
        "x: framePath.innerRight - framePath.r",
        "x: framePath.innerRight",
        "x: framePath.innerLeft",
        "y: framePath.innerTop",
        "y: framePath.innerBottom",
        "radiusX: framePath.r",
        "radiusY: framePath.r",
    ):
        check(locked_geometry in screen_edge,
              f"Approved Screen Edge corner geometry changed: {locked_geometry}")
    check("PathMove {" in screen_edge
          and screen_edge.count("direction: PathArc.Clockwise") == 4
          and "x: framePath.innerLeft + framePath.r" in screen_edge
          and "y: framePath.innerTop" in screen_edge,
          "Screen Edge inner workspace hole must be one closed 25px rounded rectangle")
    check("component CornerWindow: PanelWindow" not in screen_edge
          and "CornerWindow {" not in screen_edge
          and "component EdgeWindow: PanelWindow" not in screen_edge
          and "Rectangle {" not in screen_edge,
          "Screen Edge must not reconstruct the frame from painted edge/corner overlays")
    check('FrameWindow {}' in screen_edge,
          "Each output must have exactly one painted Screen Edge frame")
    for edge in ("top", "bottom", "left", "right"):
        check(f'ReservationWindow {{ edge: "{edge}" }}' in screen_edge,
              f"Screen Edge must retain transparent {edge} work-area reservation")

    sidebar_host = read("modules/sidebar/SidebarHost.qml")
    for token in (
        "GlobalStates.sidebarLeftPresentationOutput",
        "GlobalStates.sidebarRightPresentationOutput",
        "PanelWindow {",
        "width: Math.max(0, root.effectiveSidebarWidth",
        "- Appearance.sizes.elevationMargin)",
        "rightMargin: root.isLeftEdge",
        "? Appearance.sizes.elevationMargin",
        ": 0",
        "leftMargin: root.isLeftEdge",
        "? 0",
        ": Appearance.sizes.elevationMargin",
    ):
        check(token in sidebar_host,
              f"Sidebar physical-edge underlap contract missing: {token}")
    for retired in (
        "ConnectedSurfaceConnector",
        "sidebarBridgeGeometry",
        "directEdgeInset",
        "screenEdgeThickness",
    ):
        check(retired not in sidebar_host,
              f"Sidebar must not stop at an inner-edge inset or restore a connector: {retired}")
    check('property: "animTranslateX"' in sidebar_host
          and 'property: "animTranslateY"' in sidebar_host
          and "Appearance.animation?.elementMove?.duration ?? 500" in sidebar_host
          and "Appearance.animation?.elementMove?.bezierCurve" in sidebar_host,
          "Sidebar slide translation must use the default-spatial motion token")

    osk = read("modules/onScreenKeyboard/OnScreenKeyboard.qml")
    for token in (
        "targetY = 0",
        "targetY = ph - kh",
        "y: parent ? parent.height - height : 0",
        "ConnectedSurfaceJoinFlares {",
        "flareRadius: PerimeterTokens.joinFlareRadius",
        'joinTop: oskRoot.snappedEdge === "top"',
        'joinBottom: oskRoot.snappedEdge === "bottom"',
    ):
        check(token in osk,
              f"OSK physical Screen Edge attachment contract missing: {token}")
    check("screenAttachInset" not in osk,
          "OSK must not stop at the inner Screen Edge boundary")
    check("Appearance.animation.elementMove.duration" in osk
          and "Appearance.animation.elementMove.bezierCurve" in osk,
          "OSK attached-edge slide must use the default-spatial motion token")
    for token in (
        "property bool _oskResident:",
        "property real _oskRevealProgress:",
        "readonly property real revealOffsetY:",
        "transform: Translate { y: oskRoot.revealOffsetY }",
        "progress: root._oskRevealProgress",
    ):
        check(token in osk,
              f"OSK must stay resident and slide through its attached edge: {token}")

    for token in (
        "tangentRevealDirection",
        "tangentAnimationOffset",
        "bodyRect.x + tangentAnimationOffset",
        "bodyRect.y + tangentAnimationOffset",
    ):
        check(token not in geometry,
              f"Connected popup slide must stay on the attachment axis like Caelestia: {token}")

    check("PerimeterCornerShadow" not in screen_edge
          and "adjacentShadowInset" not in screen_edge
          and "shadowSeamOverlap" not in screen_edge,
          "Rejected curved perimeter-shadow stitching must stay removed from Screen Edge")

    for token in (
        "id: sidebarEdgeFlares",
        "tracksBodyTranslation",
        "JoinFlares maps bodyItem through mapToItem()",
    ):
        check(token in sidebar_host,
              f"Sidebar Screen Edge shoulders must follow the mapped body once: {token}")
    sidebar_flare_start = sidebar_host.index("id: sidebarEdgeFlares")
    sidebar_flare_end = sidebar_host.index("ShellEditSurfaceFrame", sidebar_flare_start)
    sidebar_flare_block = sidebar_host[sidebar_flare_start:sidebar_flare_end]
    check("transform: Translate" not in sidebar_flare_block,
          "Sidebar flares must not double-apply the Loader translation after mapToItem()")
    check("shadowEnabled:" not in sidebar_flare_block
          and "shadowExtent:" not in sidebar_flare_block
          and "shadowColor:" not in sidebar_flare_block,
          "Sidebar Caelestia shoulders must remain fill-only; body shadow owns depth")
    check("PerimeterTokens.joinFlareRadius" in sidebar_host
          and "root.screenEdgeShadowEnabled ? root.screenEdgeShadowSize + 2 : 0" in sidebar_host,
          "Sidebar native host must reserve room for the larger of flare and configured Screen Edge shadow")

    media_popup = read("modules/mediaControls/BarMediaPopup.qml")
    check("EqualizerPanel {" in media_popup,
          "Bar media popup must retain the Equalizer panel")
    check("No active player" not in media_popup
          and "Make sure your player has MPRIS support" not in media_popup,
          "Bar media popup must not append an inactive-player text card below Equalizer")

    compact_sidebar = read("modules/sidebarRight/CompactSidebarRightContent.qml")
    check("import qs.modules.mediaControls" in compact_sidebar
          and "EqualizerPanel {" in compact_sidebar
          and "active: root.panelVisible" in compact_sidebar,
          "Compact right Sidebar Media section must render the shared Equalizer below the player")

    resources_popup = read("modules/bar/ResourcesPopup.qml")
    check('Translation.tr("RPM:")' in resources_popup
          and 'Translation.tr("Speed:")' not in resources_popup,
          "ThinkFan inline metric must use the compact RPM label")
    check('String(ThinkFanService.fanRpm)' in resources_popup,
          "ThinkFan RPM value must not repeat the RPM unit after the RPM label")

    for settings_path in (
        "modules/settings/SettingsOverlay.qml",
        "modules/settings/SettingsFocus.qml",
    ):
        settings_surface = read(settings_path)
        for token in (
            "import qs.modules.common.perimeter",
            "PolkitService.active ? WlrLayer.Top : WlrLayer.Overlay",
            "y: settingsPanel.height - height",
            "ConnectedSurfaceJoinFlares {",
            "joinBottom: true",
            "bottomLeftRadius: 0",
            "bottomRightRadius: 0",
        ):
            check(token in settings_surface,
                  f"{settings_path} must be a bottom-connected popup below Polkit: {token}")

    settings_overlay = read("modules/settings/SettingsOverlay.qml")
    settings_focus = read("modules/settings/SettingsFocus.qml")
    check("1600" in settings_overlay
          and "settingsPanel.width * 0.90" in settings_overlay
          and "settingsPanel.height * 0.92" in settings_overlay,
          "Rail Settings overlay must use the enlarged bottom-connected footprint")
    check("1560" in settings_focus
          and "settingsPanel.width * 0.88" in settings_focus
          and "settingsPanel.height * 0.92" in settings_focus,
          "Focus Settings overlay must use the enlarged bottom-connected footprint")
    for settings_surface in (settings_overlay, settings_focus):
        check("Appearance.animation.elementMove.duration" in settings_surface
              and "Appearance.animation.elementMove.bezierCurve" in settings_surface,
              "Connected Settings overlays must use the Caelestia-style default-spatial slide")
        check("Appearance.colors.colShadow" in settings_surface
              and "screenEdge?.shadow?.size" in settings_surface
              and "screenEdge?.shadow?.opacity" in settings_surface,
              "Connected Settings overlays must share the Screen Edge shadow contract")
        flare_start = settings_surface.index("ConnectedSurfaceJoinFlares {")
        flare_end = settings_surface.index("Rectangle {", flare_start)
        settings_flare = settings_surface[flare_start:flare_end]
        check("shadowEnabled:" not in settings_flare
              and "shadowExtent:" not in settings_flare
              and "shadowColor:" not in settings_flare,
              "Connected Settings Caelestia shoulders must stay fill-only")

    dashboard = read("modules/overview/OverviewDashboard.qml")
    check("Rectangle {\n        id: dashContainer" in dashboard
          and "color: Appearance.colors.colLayer0" in dashboard
          and "GlassBackground {\n        id: dashContainer" not in dashboard
          and "readonly property bool useWallpaperBackdrop: false" in dashboard,
          "Dashboard connected body must be a plain solid Material surface without glass tint")
    check("Appearance.animation.elementMove.duration" in dashboard
          and "Appearance.animation.elementMove.bezierCurve" in dashboard,
          "Dashboard connected slide must use the default-spatial motion token")
    check("Appearance.colors.colShadow" in dashboard
          and "Appearance.m3colors.m3shadow" not in dashboard,
          "Dashboard connected shadow must use the same themed shadow ink as Screen Edge and Bar")
    check("import qs.modules.mediaControls" in dashboard
          and "EqualizerPanel {" in dashboard
          and "id: dashboardEqualizer" in dashboard,
          "Dashboard Media must expose the shared Equalizer DSP panel")
    overview_runtime = read("modules/overview/Overview.qml")
    check("opacity: root.dashboardPresentationMode" in overview_runtime
          and '? 0 : (root._presentedOpen ? 1 : 0)' in overview_runtime,
          "Dashboard popup mode must not inherit the full-screen Overview scrim")

    critical_panels = read("modules/ii/critical/ShellIiCriticalPanels.qml")
    check('../../screenCorners/ScreenEdges.qml' in critical_panels,
          "ii critical shell must load persistent Screen Edge chrome")
    check('../../sidebar/SidebarEdgeConnectors.qml' not in critical_panels,
          "ii critical shell must not recreate the retired standalone sidebar bridge window")
    check("PerimeterRuntime.qml" not in critical_panels,
          "Full iiPerimeter runtime must not be booted by the critical shell")

    frame = read("modules/common/perimeter/ConnectedSurfaceFrame.qml")
    check("property real connectorBorderWidth: 0" in frame,
          "ConnectedSurfaceFrame must default the connector outline off at the seam")
    check("strokeWidth: root.connectorBorderWidth" in frame,
          "ConnectedSurfaceFrame must route connector outline width through its seam policy")
    check("ConnectedSurfaceJoinFlares {" in frame
          and "flareRadius: root.joinFlareRadius" in frame,
          "ConnectedSurfaceFrame must preserve the circular direct-edge shoulder contract")
    check("opacity: root.geometry.progress" not in frame,
          "ConnectedSurfaceFrame must morph geometry instead of fading the whole surface")
    check("property bool hoverEnabled: false" in frame
          and "readonly property bool bodyHovered: bodyHover.hovered" in frame
          and "HoverHandler {" in frame,
          "ConnectedSurfaceFrame must expose body-scoped hover ownership for popup hand-off")
    generic_shadow = read("modules/common/widgets/StyledRectangularShadow.qml")
    check("property color color: Appearance.colors.colShadow" in generic_shadow,
          "Shared rectangular shadow must use the proven themed shell shadow source")
    check("cached: true" in generic_shadow,
          "Shared rectangular shadow must retain the prior stable cached renderer")

    join_flares = read("modules/common/perimeter/ConnectedSurfaceJoinFlares.qml")
    for token in (
        "component Flare: Canvas {",
        "const k = 0.5522847498",
        'corner === "topLeft"',
        'corner === "topRight"',
        'corner === "bottomLeft"',
        'corner === "bottomRight"',
        'corner === "leftTop"',
        'corner === "leftBottom"',
        'corner === "rightTop"',
        'corner === "rightBottom"',
        "root.bodyItem.mapToItem(root, 0, 0)",
        "visible: root.reveal > 0.001 && root.radius > 0",
    ):
        check(token in join_flares,
              f"Restored Caelestia Canvas shoulder contract missing: {token}")
    check("component Flare: RoundCorner" not in join_flares
          and "PerimeterCornerShadow" not in join_flares
          and "property bool shadowEnabled" not in join_flares
          and "property real shadowExtent" not in join_flares
          and "property color shadowColor" not in join_flares,
          "Rejected RoundCorner/corner-shadow flare rewrite must stay reverted")
    check("root.radius * Math.max(0.20, Math.min(1, root.crossScale))" in join_flares
          and "width: root.radius" in join_flares
          and "height: root.depth" in join_flares,
          "Bar popup shoulder must keep Caelestia's broad tangent / compressed cross-axis contact")
    check(") * root.reveal" not in join_flares,
          "Caelestia shoulder radius must stay fully formed during reveal")

    mask = read("modules/common/perimeter/ConnectedSurfaceMask.qml")
    for token in ("_sourceStrip", "_middleStrip", "_bodyStrip", "connectorSourceExtent"):
        check(token in mask,
              f"ConnectedSurfaceMask must track the flared connector rather than its full bounding box: {token}")
    check("item: root.active ? root.connectorItem" not in mask,
          "ConnectedSurfaceMask must not make the transparent connector bounding box fully interactive")

    bar_runtime = read("modules/bar/Bar.qml")
    vertical_bar_runtime = read("modules/verticalBar/VerticalBar.qml")
    bar_content = read("modules/bar/BarContent.qml")
    vertical_bar_content = read("modules/verticalBar/VerticalBarContent.qml")
    for runtime in (bar_runtime, vertical_bar_runtime):
        check("PerimeterCornerShadow" not in runtime
              and "shadowTangentInset" not in runtime
              and "shadowSeamOverlap" not in runtime,
              "Rejected curved Bar shadow stitching must stay reverted")
    for runtime in (bar_runtime, vertical_bar_runtime):
        for retired_geometry in (
            "id: roundDecorators",
            "ScreenEdgeContact",
            "id: barEdgeShadow",
            "id: autoHideScreenEdge",
            "autoHideEdgeBand",
            "edgeShadowEnabled",
            "edgeShadowExtent",
            "edgeShadowOpacity",
            "edgeShadowColor",
            "screenEdgeThickness",
            "inwardDecoratorAllowance",
            "screenEdge?.shadow",
            "screenEdge?.radius",
            "PerimeterTokens.frameRadius",
            "RoundCorner {",
            "surfacePresented",
        ):
            check(retired_geometry not in runtime,
                  f"Bar runtime must not retain physical Screen Edge geometry/shadow: {retired_geometry}")
        check("readonly property bool showBarBackground: true" in runtime,
              "Supported Hug Bar chrome must remain structurally present")
        check("Appearance.animation.elementMove.duration" in runtime
              and "Appearance.animation.elementMove.bezierCurve" in runtime,
              "Bar auto-hide slide must use the default-spatial motion token")
    check("visible: !gameModeMinimal" in bar_content,
          "Horizontal Hug body must not disappear because of legacy showBackground state")
    check("visible: !root.gameModeMinimal && !root.isIslands" in vertical_bar_content,
          "Vertical Hug body must not disappear because of legacy showBackground state")
    check("Config.options?.bar?.cornerStyle" not in bar_content,
          "Horizontal Hug body must ignore persisted retired cornerStyle at runtime")
    check("Config.options?.bar?.cornerStyle" not in vertical_bar_content,
          "Vertical Hug body must ignore persisted retired cornerStyle at runtime")
    check("(Config.options?.bar?.cornerStyle ?? 0) === 0" not in vertical_bar_runtime,
          "Vertical Hug shoulders must not depend on legacy cornerStyle state")

    media = read("modules/bar/Media.qml")
    check("PopupWindow" not in media,
          "Bar Media must not restore detached PopupWindow surfaces")
    check(media.count("StyledPopup {") >= 2,
          "Bar Media wheel HUD and expanded controls must both use StyledPopup")
    check("BarMediaPopup {" in media,
          "Bar Media must preserve its expanded control content inside the connected surface")
    check("keyboardFocus: true" in media,
          "Expanded Media connected popout must preserve keyboard focus")

    taskbar_preview = read("modules/bar/BarTaskbarPreview.qml")
    check("StyledPopup {" in taskbar_preview,
          "Taskbar window previews must use the connected bar popout shell")
    check("PopupWindow {" not in taskbar_preview,
          "Taskbar window previews must not restore the detached PopupWindow shell")
    check("GlassBackground {" not in taskbar_preview,
          "Taskbar window previews must not draw a second floating card inside the connected shell")
    check("anchorItem" in taskbar_preview and "previewOpen" in taskbar_preview,
          "Taskbar preview must preserve real button anchoring and hover lifecycle")

    tray = read("modules/bar/SysTray.qml")
    check("alternativeVisibleCondition: root.trayOverflowOpen" in tray,
          "Tray overflow must use the shared connected visibility lifecycle")
    check("active: root.trayOverflowOpen" not in tray,
          "Tray overflow must not bypass the retract lifecycle by overriding LazyLoader.active")

    check(not (ROOT / "modules/bar/ClockWidgetTooltip.qml").exists(),
          "Retired ClockWidgetTooltip must not return as a standalone hover surface")

    connected_bar_popouts = {
        "modules/bar/TimerIndicatorTooltip.qml": "StyledPopup {",
        "modules/bar/ShellUpdateIndicator.qml": "StyledPopup {",
        "modules/bar/BatteryPopup.qml": "StyledPopup {",
        "modules/bar/ResourcesPopup.qml": "StyledPopup {",
    }
    for path, connected_shell in connected_bar_popouts.items():
        source = read(path)
        check(connected_shell in source,
              f"{path} must use the shared connected bar popout shell")
        check("PopupWindow" not in source,
              f"{path} must not restore a detached PopupWindow surface")

    bar_runtime = read("modules/bar/Bar.qml")
    check('Config.setNestedValue("bar.cornerStyle", 0)' in bar_runtime,
          "Classic Bar startup must normalize persisted legacy corner styles to Hug")
    config_qml = read("modules/common/Config.qml")
    defaults_json = read("defaults/config.json")
    appearance_qml = read("modules/common/Appearance.qml")
    shell_layout = read("services/ShellLayoutController.qml")
    check("property int cornerStyle: 0" in config_qml,
          "Classic Bar schema default must be Hug")
    check('"cornerStyle": 0' in defaults_json,
          "Classic Bar persisted default must be Hug")
    check("property int material: 0" in config_qml
          and '"material": 0' in defaults_json,
          "Material global-style compatibility corner must resolve to Hug")
    check("Config.options?.bar?.cornerStyle" not in appearance_qml,
          "Shared Bar sizing must not branch on retired cornerStyle")
    check("Config.options?.bar?.cornerStyle" not in shell_layout,
          "Shell layout reservation must not branch on retired cornerStyle")
    for retired_runtime_token in ("effectiveCornerStyle", "floatStyleShadow", "barFillInner"):
        check(retired_runtime_token not in bar_runtime,
              f"Classic Bar runtime must not retain retired corner-style branch: {retired_runtime_token}")

    bar_settings = read("modules/settings/BarConfigHugOnly.qml")
    quick_settings = read("modules/settings/QuickConfigHugOnly.qml")
    check('Translation.tr("Corner style")' in bar_settings
          and 'Translation.tr("Float shadow")' in bar_settings,
          "Public Bar settings must suppress retired corner-style and float-shadow controls")
    check('Translation.tr("Bar style")' in quick_settings,
          "Quick settings must suppress the retired Bar style selector")
    check("_hugUiReady" not in bar_settings
          and "opacity: root._hugUiReady" not in bar_settings
          and "onTriggered: root._applyHugOnlyUi(root)" in bar_settings,
          "Public Bar settings must remain visible while the compatibility pruning pass runs")
    check("_hugUiReady" not in quick_settings
          and "opacity: root._hugUiReady" not in quick_settings
          and "onTriggered: root._applyHugOnlyUi(root)" in quick_settings,
          "Quick settings must remain visible while the Hug compatibility pruning pass runs")
    check('Config.options?.appearance?.screenEdge?.width ?? 10' in bar_settings
          and 'Config.setNestedValue("appearance.screenEdge.width", value)' in bar_settings,
          "Bar settings must expose persistent Screen Edge width with a 10px default")
    check('appearance.screenEdge.radius' not in bar_settings
          and 'Translation.tr("Border radius (px)")' not in bar_settings,
          "Bar settings must not expose retired Screen Edge radius while square baseline is active")
    check('appearance.screenEdge.shadow' not in bar_settings
          and 'Translation.tr("Screen edge shadow")' not in bar_settings
          and 'Translation.tr("Shadow size (px)")' not in bar_settings
          and 'Translation.tr("Shadow opacity (%)")' not in bar_settings,
          "Public Bar settings must not expose retired physical Screen Edge shadow controls")

    dock_config = read("modules/settings/DockConfig.qml")
    dock_config_lower = dock_config.lower()
    for legacy_style in ('value: "pill"', 'value: "macos"', 'value: "island"', 'value: "m3"'):
        check(legacy_style not in dock_config_lower,
              f"Dock settings must not expose legacy style option {legacy_style}")
    check('panelFamily !== "waffle"' in dock_config,
          "Waffle must remain a separate panel family rather than a Dock style")
    check("Dock uses the Panel surface style." in dock_config,
          "Dock settings must describe Panel as the canonical surface style")

    settings_registry = read("modules/settings/SettingsPageRegistry.qml")
    check('Config.setNestedValue("dock.style", "panel")' in settings_registry,
          "Legacy Dock styles must normalize to Panel")
    check('Config.setNestedValue("language.ui", "en_US")' in settings_registry,
          "Legacy UI locales must normalize to canonical en_US")
    check('Config.setNestedValue("bar.cornerStyle", 0)' in settings_registry,
          "Legacy Classic Bar corner styles must normalize to Hug")
    check('Config.setNestedValue("bar.showBackground", true)' in settings_registry,
          "Legacy transparent Classic Bar state must normalize to the structural Hug surface")
    check("_migrateLegacyScreenEdgeShadow" in settings_registry
          and 'Config.setNestedValue("appearance.screenEdge.shadow.size", 15)' in settings_registry
          and 'Config.setNestedValue("appearance.screenEdge.shadow.opacity", 0.70)' in settings_registry,
          "Legacy 12px/24% Screen Edge shadow must migrate to the Caelestia 15px/70% baseline")
    check('Config.setNestedValue("sidebar.style", "panel")' in settings_registry
          and 'Config.setNestedValue("sidebar.cardStyle", false)' in settings_registry,
          "Legacy Sidebar Island/Card values must normalize to Panel/non-card")
    check('component: "modules/settings/BarConfigHugOnly.qml"' in settings_registry,
          "Public Bar settings must route through the Hug-only facade")
    bar_hug_config = read("modules/settings/BarConfigHugOnly.qml")
    check('text === Translation.tr("Show background")' in bar_hug_config,
          "Hug-only Bar settings must hide the retired transparent-background toggle")
    check('component: "modules/settings/QuickConfigHugOnly.qml"' in settings_registry,
          "Public Quick settings must route through the Hug-only facade")
    check('entry.label !== Translation.tr("Corner style")' in settings_registry,
          "Settings search must not expose the retired Bar corner-style selector")
    settings_registry_data = read("modules/settings/SettingsPageRegistryData.qml")
    check('label: Translation.tr("Bar background")' not in settings_registry_data,
          "Settings search source must not retain the retired Bar background toggle")
    check('label: Translation.tr("Sidebar style")' not in settings_registry_data,
          "Settings search source must not retain the retired Sidebar surface selector")
    check('label: Translation.tr("Screen edge shadow")' not in settings_registry_data,
          "Settings search source must not expose retired physical Screen Edge shadow controls")

    for connected_shadow_path in (
        "modules/sidebarLeft/SidebarLeftContent.qml",
        "modules/sidebarRight/SidebarRightContent.qml",
        "modules/sidebarRight/CompactSidebarRightContent.qml",
        "modules/onScreenKeyboard/OnScreenKeyboard.qml",
    ):
        connected_shadow_source = read(connected_shadow_path)
        check("ColorUtils.applyAlpha(Appearance.colors.colShadow" in connected_shadow_source
              and "Appearance.m3colors.m3shadow" not in connected_shadow_source,
              f"{connected_shadow_path} must use the same themed shadow ink as Screen Edge and Bar")

    osk_shadow = read("modules/onScreenKeyboard/OnScreenKeyboard.qml")
    check("visible: root._oskResident" in osk_shadow
          and "root.screenEdgeShadowEnabled" in osk_shadow
          and "root.screenEdgeShadowSize > 0" in osk_shadow
          and "root.screenEdgeShadowOpacity > 0" in osk_shadow,
          "OSK connected shadow must remain resident through the whole enter/exit slide")

    sidebars_config = read("modules/settings/SidebarsConfig.qml")
    check('Translation.tr("Use Card style")' not in sidebars_config
          and 'Translation.tr("Island")' not in sidebars_config
          and 'Config.setNestedValue("sidebar.style"' not in sidebars_config,
          "Sidebar General settings must not expose Island or Card surface choices")

    shell = read("shell.qml")
    check("DevNavigation.registerSettingsPages(SettingsPageRegistry.pages)" in shell,
          "Shell startup must materialize SettingsPageRegistry so legacy config normalization runs without opening Settings")

    settings_sources = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / "modules/settings").glob("*.qml")
    )
    check("connectedPerimeter" not in settings_sources,
          "Connected Perimeter must not gain a user-facing settings key")

    translation = read("services/Translation.qml")
    check('availableLanguages: ["en_US"]' in translation,
          "Translation runtime must expose only en_US")
    check('languageCode: "en_US"' in translation,
          "Translation runtime languageCode must stay canonical en_US")
    check('Quickshell.shellPath("translations")' in translation and '/en_US.json' in translation,
          "Translation runtime must load the canonical en_US catalog")
    locale_files = sorted(path.name for path in (ROOT / "translations").glob("*.json"))
    check(locale_files == ["en_US.json"],
          f"Only translations/en_US.json is allowed; found {locale_files}")

    general_config = read("modules/settings/GeneralConfigCore.qml")
    check("Interface Language" not in general_config,
          "English-only settings must not reintroduce an Interface Language selector")
    check("Generate translations" not in general_config,
          "English-only settings must not reintroduce translation generation UI")

    if failures:
        print("Shell surface contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Shell surface contracts: OK")


if __name__ == "__main__":
    main()
