#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"
media="$root/modules/bar/Media.qml"
weather="$root/modules/bar/weather/WeatherBar.qml"
styled_popup="$root/modules/bar/StyledPopup.qml"
connected_frame="$root/modules/common/perimeter/ConnectedSurfaceFrame.qml"
iris_frame="$root/modules/common/perimeter/ConnectedSurfaceIrisFrame.qml"
iris_field="$root/modules/common/perimeter/ConnectedSurfaceIrisField.qml"
iris_mask="$root/modules/common/perimeter/ConnectedSurfaceBodyMask.qml"
connected_geometry="$root/modules/common/perimeter/ConnectedSurfaceGeometry.qml"
corner_shadow="$root/modules/common/perimeter/PerimeterCornerShadow.qml"
join_flares="$root/modules/common/perimeter/ConnectedSurfaceJoinFlares.qml"
bar_context_menu="$root/modules/bar/BarContextMenu.qml"
bar_taskbar_button="$root/modules/bar/BarTaskbarButton.qml"
bar_content="$root/modules/bar/BarContent.qml"
vertical_bar_content="$root/modules/verticalBar/VerticalBarContent.qml"
vertical_media="$root/modules/verticalBar/VerticalMedia.qml"
waffle_bar_popup="$root/modules/waffle/bar/BarPopup.qml"
waffle_bar_content="$root/modules/waffle/bar/WaffleBarContent.qml"
overview="$root/modules/overview/Overview.qml"
overview_dashboard="$root/modules/overview/OverviewDashboard.qml"

fail() {
    printf 'FAIL: perimeter source retirement contract: %s\n' "$1" >&2
    exit 1
}

for file in "$critical" "$deferred" "$media" "$weather" "$styled_popup" "$connected_frame" "$connected_geometry" "$corner_shadow" "$join_flares" "$bar_context_menu" "$bar_taskbar_button" "$bar_content" "$vertical_bar_content" "$vertical_media" "$waffle_bar_popup" "$waffle_bar_content" "$overview" "$overview_dashboard"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

if [[ -e "$root/modules/perimeter" ]]; then
    fail 'retired broad perimeter implementation must be absent from the active source tree'
fi

# No tracked QML may revive the old module import or its retired common
# host/config/cutover/route compatibility objects.
unexpected="$(git -C "$root" grep -n -E \
    'import[[:space:]]+qs\.modules\.perimeter|PerimeterRuntime|PerimeterFeatureRegistry|PerimeterPresentationPolicy|PerimeterReservationPolicy|PerimeterConfig|PerimeterCutoverPolicy|PerimeterRuntimeHealth|AnchorRegistry|SurfaceRouteController|PerimeterContext|PerimeterSlotModel|PerimeterModuleHost|PerimeterSlotHost|PerimeterOutputHost|AnchorPublisher|ConnectedSurfaceRouteState' \
    -- '*.qml' || true)"
if [[ -n "$unexpected" ]]; then
    printf '%s\n' "$unexpected" >&2
    fail 'tracked QML still references retired perimeter runtime/common compatibility symbols'
fi

for target in \
    '../../screenCorners/ScreenEdges.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "source: Qt.resolvedUrl(\"$target\")" "$critical" \
        || fail "critical ii shell must source-load supported target $target"
done

if grep -Fq 'SidebarEdgeConnectors.qml' "$critical"; then
    fail 'critical shell must not load the retired standalone sidebar bridge window'
fi
grep -Fq 'width: Math.max(0, root.effectiveSidebarWidth' "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'SidebarHost must keep its visible body width tied to the host edge surface'
grep -Fq -- '- Appearance.sizes.elevationMargin)' "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'Sidebar body must reserve margin only on its free inward side'
if grep -Fq 'directEdgeInset' "$root/modules/sidebar/SidebarHost.qml" \
        || grep -Fq 'screenEdgeThickness' "$root/modules/sidebar/SidebarHost.qml"; then
    fail 'Sidebar body must extend through the full Screen Edge band to the physical edge'
fi
if grep -Fq 'id: sidebarBridgeGeometry' "$root/modules/sidebar/SidebarHost.qml"; then
    fail 'SidebarHost must not retain connector bridge geometry'
fi
if grep -Fq 'ConnectedSurfaceConnector {' "$root/modules/sidebar/SidebarHost.qml"; then
    fail 'SidebarHost must attach its body directly instead of rendering a connector stem'
fi

for token in \
    'readonly property real edgeDecorationMargin:' \
    'PerimeterTokens.joinFlareRadius' \
    'ConnectedSurfaceJoinFlares {' \
    'bodyItem: sidebarContentLoader' \
    'fillColor: sidebarContentLoader.item?.connectedSurfaceColor' \
    'joinLeft: root.isLeftEdge' \
    'joinRight: !root.isLeftEdge'; do
    grep -Fq "$token" "$root/modules/sidebar/SidebarHost.qml" \
        || fail "SidebarHost must own visible flared Screen Edge endpoints: $token"
done

grep -Fq 'root.screenEdgeShadowEnabled ? root.screenEdgeShadowSize + 2 : 0' \
    "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'SidebarHost must reserve native endpoint room for the configured Screen Edge shadow'

for sidebar_surface in \
    "$root/modules/sidebarLeft/SidebarLeftContent.qml" \
    "$root/modules/sidebarRight/SidebarRightContent.qml" \
    "$root/modules/sidebarRight/CompactSidebarRightContent.qml"; do
    grep -Fq 'border.width: 0 // Screen Edge seam owns the outer boundary' "$sidebar_surface" \
        || fail "${sidebar_surface#$root/} must not draw an outer border against Screen Edge"
    grep -Fq 'StyledRectangularShadow {' "$sidebar_surface" \
        || fail "${sidebar_surface#$root/} must derive its outer shadow from the rounded sidebar surface"
    grep -Fq 'joinLeft: root.attachedEdge === "left"' "$sidebar_surface" \
        || fail "${sidebar_surface#$root/} must stop shadow at a joined left Screen Edge"
    grep -Fq 'joinRight: root.attachedEdge === "right"' "$sidebar_surface" \
        || fail "${sidebar_surface#$root/} must stop shadow at a joined right Screen Edge"
    grep -Fq 'Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true' "$sidebar_surface" \
        || fail "${sidebar_surface#$root/} must share Screen Edge shadow enable state"
    grep -Fq 'readonly property color connectedSurfaceColor:' "$sidebar_surface" \
        || fail "${sidebar_surface#"$root/"} must expose its real surface color to host-owned flares"
done

grep -Fq 'property JsonObject screenEdge: JsonObject {' "$root/modules/common/Config.qml" \
    || fail 'Config schema must persist appearance.screenEdge values'
grep -Fq '"screenEdge": {' "$root/defaults/config.json" \
    || fail 'default config must include the Screen Edge object'
grep -Fq 'appearance.screenEdge.shadow.enabled' "$root/modules/settings/BarConfigHugOnly.qml" \
    || fail 'Bar Settings must expose Screen Edge shadow controls'
grep -Fq 'readonly property color shadowColor:' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge runtime must paint the configured inward shadow'
grep -Fq 'readonly property real leadingShadowInset:' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge runtime must expose explicit endpoint shadow insets'
grep -Fq 'parent.width - leadingShadowInset - trailingShadowInset' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'horizontal Screen Edge shadow width must derive from both endpoint insets'
grep -Fq 'parent.height - leadingShadowInset - trailingShadowInset' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'vertical Screen Edge shadow height must derive from both endpoint insets'
grep -Fq 'id: leadingCorner' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'horizontal Screen Edge must own its leading rounded endpoint'
grep -Fq 'id: trailingCorner' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'horizontal Screen Edge must own its trailing rounded endpoint'
grep -Fq 'bottom: edge === "bottom" ? edgeBand.top : undefined' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'bottom Screen Edge corners must attach directly to the bottom band like Hug Bar decorators'
grep -Fq 'function adjacentShadowInset(outputName, edge)' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge shadow junctions must centralize adjacent owner geometry'
grep -Fq 'PerimeterTokens.shadowSeamOverlap' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge straight/curved shadows must share the one-pixel tangent overlap'
grep -Fq 'barThickness + root.innerRadius - seam' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'visible Bar junction must reserve the curved corner box with tangent overlap'
grep -Fq 'if (Config.options?.bar?.autoHide?.enable ?? false)' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'auto-hide Bar junction must fall back to physical Screen Edge geometry'
grep -A12 -F 'id: leadingCorner' "$root/modules/screenCorners/ScreenEdges.qml" \
        | grep -Fq 'leftMargin: root.thickness' \
    || fail 'leading inverse corner must begin after the left Screen Edge band'
grep -A12 -F 'id: trailingCorner' "$root/modules/screenCorners/ScreenEdges.qml" \
        | grep -Fq 'rightMargin: root.thickness' \
    || fail 'trailing inverse corner must begin before the right Screen Edge band'
grep -Fq 'PerimeterCornerShadow {' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge inverse corners must use the shared perimeter corner shadow'
grep -Fq 'import qs.modules.common.perimeter' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge must import the shared perimeter corner shadow module'
grep -Fq 'PerimeterCornerShadow 1.0 PerimeterCornerShadow.qml' "$root/modules/common/perimeter/qmldir" \
    || fail 'shared perimeter corner shadow must be exported by the module'
grep -Fq 'Canvas {' "$corner_shadow" \
    || fail 'shared perimeter corner shadow must render a clipped quarter-disc'
grep -Fq 'ctx.createRadialGradient' "$corner_shadow" \
    || fail 'shared corner shadow must retain a radius-aware falloff'
grep -Fq 'ctx.arc(cx, cy, r, start, end, false)' "$corner_shadow" \
    || fail 'shared corner shadow must clip paint to the matching quarter-circle'
grep -Fq 'const inner = Math.max(0, r - extent)' "$corner_shadow" \
    || fail 'shared corner shadow inner falloff must derive from configured extent'
grep -Fq 'required property int corner' "$corner_shadow" \
    || fail 'shared corner shadow must follow the same RoundCorner orientation'
grep -Fq 'id: leadingCornerShadow' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'leading inverse corner must render its radial shadow'
grep -Fq 'id: trailingCornerShadow' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'trailing inverse corner must render its radial shadow'
if grep -Fq 'CornerSideShadow' "$root/modules/screenCorners/ScreenEdges.qml"; then
    fail 'axis-aligned corner shadow stitching must not return'
fi
grep -Fq '? root.thickness + Math.max(root.shadowExtent, root.innerRadius)' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'horizontal Screen Edge window must reserve visual-only room for its rounded endpoints'
if grep -Fq 'component InnerCornerWindow: PanelWindow' "$root/modules/screenCorners/ScreenEdges.qml"; then
    fail 'Screen Edge corners must not live in independent compositor surfaces'
fi
if grep -Fq 'hadalis:screen-edge-corner-' "$root/modules/screenCorners/ScreenEdges.qml"; then
    fail 'retired independent Screen Edge corner layer surfaces must stay absent'
fi
for shadow_source in \
    "$root/modules/screenCorners/ScreenEdges.qml" \
    "$root/modules/bar/Bar.qml" \
    "$root/modules/verticalBar/VerticalBar.qml" \
    "$styled_popup"; do
    grep -Fq 'Appearance.colors.colShadow' "$shadow_source" \
        || fail "${shadow_source#$root/} must use the shared themed perimeter shadow ink"
    if grep -Fq 'Appearance.m3colors.m3shadow' "$shadow_source"; then
        fail "${shadow_source#$root/} must not bypass the shared themed shadow source"
    fi
done
grep -Fq 'exclusiveZone: mapped ? root.thickness : 0' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge thickness must define the compositor layout boundary'
grep -Fq 'appearance?.screenEdge?.shadow?.enabled' "$root/modules/bar/Bar.qml" \
    || fail 'horizontal Bar shadow must share Screen Edge shadow settings'
grep -Fq 'appearance?.screenEdge?.shadow?.enabled' "$root/modules/verticalBar/VerticalBar.qml" \
    || fail 'vertical Bar shadow must share Screen Edge shadow settings'
grep -Fq 'readonly property real shadowTangentInset:' "$root/modules/bar/Bar.qml" \
    || fail 'horizontal Bar must centralize its straight/curved shadow tangent inset'
grep -Fq 'PerimeterTokens.shadowSeamOverlap' "$root/modules/bar/Bar.qml" \
    || fail 'horizontal Bar shadow tangent must overlap the curved shoulder by one pixel'
grep -A18 -F 'id: barEdgeShadow' "$root/modules/bar/Bar.qml" \
        | grep -Fq 'leftMargin: barRoot.shadowTangentInset' \
    || fail 'horizontal Bar straight shadow must use the shared curved-junction inset'
grep -A18 -F 'id: barEdgeShadow' "$root/modules/bar/Bar.qml" \
        | grep -Fq 'rightMargin: barRoot.shadowTangentInset' \
    || fail 'horizontal Bar straight shadow must use the shared curved-junction inset'
grep -Fq 'readonly property real shadowTangentInset:' "$root/modules/verticalBar/VerticalBar.qml" \
    || fail 'vertical Bar must centralize its straight/curved shadow tangent inset'
grep -Fq 'PerimeterTokens.shadowSeamOverlap' "$root/modules/verticalBar/VerticalBar.qml" \
    || fail 'vertical Bar shadow tangent must overlap the curved shoulder by one pixel'
for bar_source in "$root/modules/bar/Bar.qml" "$root/modules/verticalBar/VerticalBar.qml"; do
    grep -Fq 'id: autoHideScreenEdge' "$bar_source" \
        || fail "${bar_source#$root/} must keep a physical Screen Edge fallback while auto-hidden"
    grep -Fq 'visible: Config.options?.bar?.autoHide?.enable ?? false' "$bar_source" \
        || fail "${bar_source#$root/} auto-hide fallback must follow the Bar auto-hide setting"
    count=$(grep -Fc 'PerimeterCornerShadow {' "$bar_source")
    [ "$count" -ge 4 ] \
        || fail "${bar_source#$root/} must curve both Bar and auto-hide Screen Edge corner shadows"
done
grep -Fq 'readonly property bool showBarBackground: true' "$root/modules/bar/Bar.qml" \
    || fail 'horizontal Hug structural chrome must not disappear with legacy background state'
grep -Fq 'readonly property bool showBarBackground: true' "$root/modules/verticalBar/VerticalBar.qml" \
    || fail 'vertical Hug structural chrome must not disappear with legacy background state'
if grep -A8 -F 'id: barEdgeShadow' "$root/modules/bar/Bar.qml" | grep -Fq 'surfacePresented'; then
    fail 'horizontal Bar shadow must not blink behind a separate presentation-readiness gate'
fi
if grep -A8 -F 'id: barEdgeShadow' "$root/modules/verticalBar/VerticalBar.qml" | grep -Fq 'surfacePresented'; then
    fail 'vertical Bar shadow must not blink behind a separate presentation-readiness gate'
fi

grep -Fq 'ConnectedSurfaceIrisFrame {' "$styled_popup" \
    || fail 'StyledPopup must render its production silhouette through the iRiS split-composition frame'
grep -Fq 'ConnectedSurfaceBodyMask {' "$styled_popup" \
    || fail 'StyledPopup must use the body-only iRiS compositor mask'
if grep -Fq 'ConnectedSurfaceFrame {' "$styled_popup" \
        || grep -Fq 'ConnectedSurfaceMask {' "$styled_popup"; then
    fail 'StyledPopup must not retain the legacy flare/connector-strip renderer after iRiS cutover'
fi
grep -Fq 'ConnectedSurfaceRevealClip {' "$styled_popup" \
    || fail 'StyledPopup must slide underneath the Bar/Screen Edge through a fixed reveal clip'
grep -Fq 'hoverEnabled: root.active' "$styled_popup" \
    || fail 'StyledPopup must route hover ownership through the full iRiS body'
grep -Fq 'onBodyHoveredChanged: root._bodyHovered = bodyHovered' "$styled_popup" \
    || fail 'StyledPopup must keep popup hover state synchronized with the iRiS body'
grep -Fq 'property QtObject _hoverTransferTimerObject: Timer {' "$styled_popup" \
    || fail 'StyledPopup must debounce cross-window hover transfer before retracting'
grep -Fq 'property real offsetScale: 1' "$styled_popup" \
    || fail 'StyledPopup must use a Caelestia-style normalized offsetScale'
grep -Fq 'readonly property real revealProgress: 1 - root.offsetScale' "$styled_popup" \
    || fail 'StyledPopup reveal progress must be the inverse of offsetScale'
grep -Fq 'Behavior on offsetScale {' "$styled_popup" \
    || fail 'StyledPopup must animate the normalized offset scalar directly'
grep -Fq 'SurfaceMotion.duration' "$styled_popup" \
    || fail 'StyledPopup must use the immutable surface slide duration'
grep -Fq 'SurfaceMotion.easingType' "$styled_popup" \
    || fail 'StyledPopup must use the immutable monotonic surface easing'
grep -Fq 'readonly property real revealProgress: clamp(progress, 0, 1)' "$connected_geometry" \
    || fail 'connected geometry must clamp semantic reveal progress'
grep -Fq 'readonly property real motionProgress:' "$connected_geometry" \
    || fail 'connected geometry must preserve an unclamped spatial motion scalar'
grep -Fq '(1 - motionProgress) * crossBodyExtent' "$connected_geometry" \
    || fail 'connected geometry must preserve expressive spatial overshoot during translation'
grep -Fq 'root._screenEdgeThickness - PerimeterTokens.irisWeldDepth' "$styled_popup" \
    || fail 'StyledPopup tangent clamp must preserve the G2 weld under the physical frame'
grep -Fq 'seamOverlap: PerimeterTokens.irisWeldDepth' "$styled_popup" \
    || fail 'StyledPopup primary owner join must preserve the G2 weld depth'
grep -Fq 'visibleBodyRect: frame.visibleBodyRect' "$styled_popup" \
    || fail 'StyledPopup input must use the same external-owner clip as iRiS paint'
if grep -A28 -F 'id: directEdgeAttachment' "$styled_popup" \
    | grep -Fq 'connectAdjacentScreenEdge'; then
    fail 'StyledPopup direct-edge detection must not be gated by a module opt-in'
fi
grep -Fq 'joinLeft: root._attachmentEdge === "left"' "$styled_popup" \
    || fail 'StyledPopup must join its primary left owner'
grep -Fq '|| directEdgeAttachment.atLeft' "$styled_popup" \
    || fail 'StyledPopup must also join a touched left Screen Edge'
grep -Fq 'joinTop: root._attachmentEdge === "top"' "$styled_popup" \
    || fail 'StyledPopup must join its primary top owner'
grep -Fq '|| directEdgeAttachment.atTop' "$styled_popup" \
    || fail 'StyledPopup must also join a touched top Screen Edge'

for token in \
    'function clipExternalOwners(raw)' \
    'readonly property rect visibleBodyRect:' \
    'readonly property var ownerShape:' \
    'readonly property var frameStartShape:' \
    'readonly property var frameEndShape:' \
    'readonly property var popupShape:' \
    'readonly property bool needsEndJoinAux:' \
    'sourceItem: shadowTextureSource' \
    'hideSource: true' \
    'smooth: true' \
    'ConnectedSurfaceIrisField {' \
    'readonly property bool bodyHovered: bodyHover.hovered'; do
    grep -Fq "$token" "$iris_frame" \
        || fail "production iRiS frame contract missing: $token"
done
if grep -Fq 'ConnectedSurfaceJoinFlares' "$iris_frame" \
        || grep -Fq 'ConnectedSurfaceConnector' "$iris_frame"; then
    fail 'production iRiS frame must not recreate flare/connector patch geometry'
fi
grep -Fq 'fragmentShader: Qt.resolvedUrl("IrisField.frag.qsb")' "$iris_field" \
    || fail 'production iRiS field must resolve its locked shader inside the runtime module'
grep -Fq 'readonly property vector4d viewport:' "$iris_field" \
    || fail 'production iRiS field must preserve output-local viewport coordinates'
if grep -Fq '_sourceStrip' "$iris_mask" \
        || grep -Fq '_middleStrip' "$iris_mask" \
        || grep -Fq '_bodyStrip' "$iris_mask"; then
    fail 'production iRiS input mask must not retain connector-strip approximation'
fi

grep -Fq 'No stem is' "$join_flares" \
    || fail 'join flare primitive must remain a direct-union shoulder rather than a connector stem'
grep -Fq 'root.bodyItem.mapToItem(root, 0, 0)' "$join_flares" \
    || fail 'join flares must map nested body geometry into the flare host coordinate space'
grep -Fq 'import qs.modules.common.widgets' "$join_flares" \
    || fail 'join flares must reuse the common Hug corner primitive'
grep -Fq 'component Flare: Item {' "$join_flares" \
    || fail 'connected shoulders must compose fill and curved shadow in one flare item'
grep -Fq 'RoundCorner {' "$join_flares" \
    || fail 'connected shoulder fill must reuse the Hug RoundCorner primitive'
grep -Fq 'PerimeterCornerShadow {' "$join_flares" \
    || fail 'connected shoulder shadow must follow the same concave arc'
for token in \
    'property bool shadowEnabled: false' \
    'property real shadowExtent: 0' \
    'property color shadowColor: "transparent"'; do
    grep -Fq "$token" "$join_flares" \
        || fail "connected shoulders must expose live perimeter shadow state: $token"
done
for mapping in \
    'case "topLeft": return RoundCorner.CornerEnum.TopRight' \
    'case "topRight": return RoundCorner.CornerEnum.TopLeft' \
    'case "bottomLeft": return RoundCorner.CornerEnum.BottomRight' \
    'case "bottomRight": return RoundCorner.CornerEnum.BottomLeft' \
    'case "leftTop": return RoundCorner.CornerEnum.BottomLeft' \
    'case "leftBottom": return RoundCorner.CornerEnum.TopLeft' \
    'case "rightTop": return RoundCorner.CornerEnum.BottomRight' \
    'case "rightBottom": return RoundCorner.CornerEnum.TopRight'; do
    grep -Fq "$mapping" "$join_flares" \
        || fail "connected shoulder orientation drifted: $mapping"
done
if grep -Fq 'component Flare: Canvas {' "$join_flares"; then
    fail 'connected shoulders must not keep a second Canvas corner renderer'
fi
grep -Fq 'visible: root.reveal > 0.001 && root.radius > 0' "$join_flares" \
    || fail 'connected join flares must remain fully formed while the body slides'
if grep -Fq ') * root.reveal' "$join_flares"; then
    fail 'connected join flare radius must not shrink with reveal progress'
fi
grep -Fq 'root.joinTop && !root.joinLeft' "$join_flares" \
    || fail 'top flare must suppress itself when the adjacent Screen Edge is also joined'
for token in \
    'StyledPopup {' \
    'hoverTarget: root.anchorItem' \
    'alternativeVisibleCondition: root.active' \
    'closeOnOutsideClick: true'; do
    grep -Fq "$token" "$bar_context_menu" \
        || fail "BarContextMenu must use the shared connected popup path: $token"
done
grep -Fq 'BarContextMenu {' "$bar_taskbar_button" \
    || fail 'Bar taskbar right-click menu must use BarContextMenu'
if grep -Eq '^[[:space:]]*ContextMenu[[:space:]]*\{' "$bar_taskbar_button"; then
    fail 'Bar taskbar must not fall back to detached generic ContextMenu'
fi
for token in \
    'property var anchorRect: null' \
    'Number(root.anchorRect?.x ?? 0)' \
    'host.mapFromItem(target, localX, localY)'; do
    grep -Fq "$token" "$styled_popup" \
        || fail "StyledPopup must support source-local tangent sub-rect placement: $token"
done
grep -Fq 'anchorRect: root.anchorRect' "$bar_context_menu" \
    || fail 'BarContextMenu must forward source-local anchorRect into StyledPopup'
grep -Fq 'BarContextMenu {' "$bar_content" \
    || fail 'Bar background right-click menu must use the connected BarContextMenu'
grep -Fq 'root.barContextMenuSource = mouseArea' "$bar_content" \
    || fail 'Bar background menu must retain the real clicked Bar control as ownership anchor'
grep -Fq 'root.barContextMenuRect = Qt.rect(clickX, clickY, 1, 1)' "$bar_content" \
    || fail 'Bar background menu must place tangent geometry at the click point'
if grep -Eq '^[[:space:]]*ContextMenu[[:space:]]*\{' "$bar_content"; then
    fail 'BarContent must not keep a detached generic ContextMenu'
fi
grep -Fq 'Bar.BarContextMenu {' "$vertical_bar_content" \
    || fail 'Vertical Bar background right-click menu must use connected BarContextMenu'
grep -Fq 'root.barContextMenuSource = mouseArea' "$vertical_bar_content" \
    || fail 'Vertical Bar context menu must retain its real clicked Bar control'
if grep -Eq '^[[:space:]]*ContextMenu[[:space:]]*\{' "$vertical_bar_content"; then
    fail 'VerticalBarContent must not keep a detached generic ContextMenu'
fi
for token in \
    'Bar.StyledPopup {' \
    'hoverActivates: true' \
    'alternativeVisibleCondition:' \
    'root.barMediaPopupVisible && root.popupMode === "bar"' \
    'closeOnOutsideClick: root.barMediaPopupVisible' \
    'keyboardFocus: root.barMediaPopupVisible' \
    'mediaPopupContent.focusInitialControl()'; do
    grep -Fq "$token" "$vertical_media" \
        || fail "Vertical Media expanded popup must use shared connected surface: $token"
done
if grep -Fq 'PopupWindow {' "$vertical_media"; then
    fail 'VerticalMedia must not retain a detached PopupWindow'
fi
if grep -Fq 'sourceComponent: PanelWindow {' "$vertical_media"; then
    fail 'VerticalMedia must not own a private outside-click PanelWindow'
fi
if grep -Fq 'onWheel:' "$vertical_media" || grep -Fq 'volumePopupVisible' "$vertical_media"; then
    fail 'VerticalMedia must not retain wheel-driven volume behavior or HUD state'
fi
for token in \
    'import qs.modules.common.perimeter' \
    'sourceComponent: PanelWindow {' \
    'ConnectedSurfaceGeometry {' \
    'connectorLength: 0' \
    'ConnectedSurfaceRevealClip {' \
    'ConnectedSurfaceFrame {' \
    'connectorVisible: false' \
    'ConnectedSurfaceContentHost {' \
    'ConnectedSurfaceMask {' \
    'screen: root._anchorScreen' \
    'function updateAnchor()'; do
    grep -Fq "$token" "$waffle_bar_popup" \
        || fail "Waffle BarPopup must reuse shared connected-surface geometry: $token"
done
if grep -Fq 'sourceComponent: PopupWindow {' "$waffle_bar_popup"; then
    fail 'Waffle BarPopup must not retain detached PopupWindow presentation'
fi
if grep -Fq 'sourceEdgeMargin' "$waffle_bar_popup"; then
    fail 'Waffle BarPopup must not recreate the old visual-margin gap animation'
fi
grep -Fq 'property bool focusGrabRequested: false' "$waffle_bar_popup" \
    || fail 'Waffle BarPopup must keep explicit focus re-grab state'
grep -Fq 'frame.bodyHovered || popupHoverHandler.hovered' "$waffle_bar_popup" \
    || fail 'Waffle BarPopup hover ownership must include the complete connected body'
grep -Fq 'hoverEnabled: root.active' "$waffle_bar_popup" \
    || fail 'Waffle BarPopup must enable shared full-body hover tracking'
if grep -Eq 'focusGrab\.active[[:space:]]*=' "$waffle_bar_popup"; then
    fail 'Waffle BarPopup must not imperatively detach the focusGrab.active binding'
fi
for token in \
    'property var anchorRect: null' \
    'Number(root.anchorRect?.x ?? 0)' \
    'host.mapFromItem(target, localX, localY)'; do
    grep -Fq "$token" "$waffle_bar_popup" \
        || fail "Waffle BarPopup must support source-local tangent placement: $token"
done
grep -Fq 'root.contextMenuSource = barContextArea' "$waffle_bar_content" \
    || fail 'Waffle Bar background menu must keep the real Bar control as source anchor'
grep -Fq 'root.contextMenuRect = Qt.rect(mouse.x, mouse.y, 1, 1)' "$waffle_bar_content" \
    || fail 'Waffle Bar background menu must place tangent geometry at click point'
grep -Fq 'anchorItem: root.contextMenuSource ?? root' "$waffle_bar_content" \
    || fail 'Waffle Bar menu must anchor to the real clicked Bar surface'
if grep -Fq 'id: contextMenuAnchor' "$waffle_bar_content"; then
    fail 'Waffle Bar background menu must not retain a synthetic 1x1 anchor item'
fi
grep -Fq 'import qs.modules.common.perimeter' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
    || fail 'OSK must use shared perimeter join primitives'
for token in \
    'targetY = 0' \
    'targetY = ph - kh' \
    'y: parent ? parent.height - height : 0' \
    'ConnectedSurfaceJoinFlares {' \
    'flareRadius: PerimeterTokens.joinFlareRadius' \
    'joinTop: oskRoot.snappedEdge === "top"' \
    'joinBottom: oskRoot.snappedEdge === "bottom"'; do
    grep -Fq "$token" "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
        || fail "OSK must underlap and flare into the physical top/bottom Screen Edge: $token"
done
if grep -Fq 'screenAttachInset' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"; then
    fail 'OSK must not stop at the inner Screen Edge boundary'
fi
if grep -Fq 'id: oskConnectorGeometry' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"; then
    fail 'OSK must not recreate a detached connector stem'
fi
if grep -Fq 'geometry: oskConnectorGeometry' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"; then
    fail 'OSK must not render the retired connector geometry'
fi
grep -Fq 'screenEdgeShadowSize' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
    || fail 'OSK shadow must share Screen Edge settings'

if grep -Fq 'ConnectedSurfaceConnector {' "$overview"; then
    fail 'Overview must attach its dashboard body directly instead of rendering a connector stem'
fi
if grep -Fq 'overviewBottomConnectorGeometry' "$overview"; then
    fail 'Overview must not retain bottom connector geometry'
fi
for token in \
    'readonly property real bottomAttachmentY:' \
    '- root.bottomAttachmentThickness' \
    'readonly property bool dashboardPresentationMode:' \
    'root.dashboardPresentationMode ? 1' \
    'root.bottomAttachmentY - bodyBottomInColumn' \
    'popupPresented: root._presentedOpen'; do
    grep -Fq -- "$token" "$overview" \
        || fail "Overview must present Dashboard as a direct bottom popup: $token"
done
for token in \
    'property bool directBottomAttachment: false' \
    'property bool popupPresented: true' \
    'property real revealProgress: 0' \
    'id: dashboardSurfaceLayer' \
    '(1 - root.revealProgress) * dashContainer.height' \
    'clip: root.directBottomAttachment' \
    'ConnectedSurfaceJoinFlares {' \
    'flareRadius: PerimeterTokens.joinFlareRadius' \
    'joinBottom: root.directBottomAttachment' \
    'Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true' \
    'blur: root.screenEdgeShadowSize' \
    'bottomLeftRadius: root.directBottomAttachment ? 0 : radius' \
    'color: Appearance.colors.colLayer0' \
    'DashboardContent {' \
    'SearchWidget {' \
    'embeddedSurface: true'; do
    grep -Fq "$token" "$overview_dashboard" \
        || fail "OverviewDashboard popup contract missing: $token"
done

grep -Fq 'StyledPopup {' "$media" \
    || fail 'normal Media UX must stay on StyledPopup'
grep -Fq 'GlobalStates.openSidebarRight' "$weather" \
    || fail 'normal Weather click route must stay on right-sidebar Weather UX'

printf 'PASS: broad perimeter runtime/common compatibility is absent; supported shell routes remain authoritative\n'
