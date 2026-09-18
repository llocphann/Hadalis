#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"
media="$root/modules/bar/Media.qml"
weather="$root/modules/bar/weather/WeatherBar.qml"
styled_popup="$root/modules/bar/StyledPopup.qml"
connected_frame="$root/modules/common/perimeter/ConnectedSurfaceFrame.qml"
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

for file in "$critical" "$deferred" "$media" "$weather" "$styled_popup" "$connected_frame" "$join_flares" "$bar_context_menu" "$bar_taskbar_button" "$bar_content" "$vertical_bar_content" "$vertical_media" "$waffle_bar_popup" "$waffle_bar_content" "$overview" "$overview_dashboard"; do
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
done

grep -Fq 'property JsonObject screenEdge: JsonObject {' "$root/modules/common/Config.qml" \
    || fail 'Config schema must persist appearance.screenEdge values'
grep -Fq '"screenEdge": {' "$root/defaults/config.json" \
    || fail 'default config must include the Screen Edge object'
grep -Fq 'appearance.screenEdge.shadow.enabled' "$root/modules/settings/BarConfigHugOnly.qml" \
    || fail 'Bar Settings must expose Screen Edge shadow controls'
grep -Fq 'readonly property color shadowColor:' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge runtime must paint the configured inward shadow'
grep -Fq 'exclusiveZone: mapped ? root.thickness : 0' "$root/modules/screenCorners/ScreenEdges.qml" \
    || fail 'Screen Edge thickness must define the compositor layout boundary'
grep -Fq 'appearance?.screenEdge?.shadow?.enabled' "$root/modules/bar/Bar.qml" \
    || fail 'horizontal Bar shadow must share Screen Edge shadow settings'
grep -Fq 'appearance?.screenEdge?.shadow?.enabled' "$root/modules/verticalBar/VerticalBar.qml" \
    || fail 'vertical Bar shadow must share Screen Edge shadow settings'

grep -Fq 'connectorVisible: false' "$styled_popup" \
    || fail 'StyledPopup must not paint a connector stem'
grep -Fq 'readonly property real _popupScreenMargin: Math.max(0,' "$styled_popup" \
    || fail 'StyledPopup Screen Edge clamping must be placement-driven for every Bar module'
if grep -A28 -F 'id: directEdgeAttachment' "$styled_popup" \
    | grep -Fq 'connectAdjacentScreenEdge'; then
    fail 'StyledPopup direct-edge detection must not be gated by a module opt-in'
fi
grep -Fq 'joinLeft: root._attachmentEdge === "left"' "$styled_popup" \
    || fail 'StyledPopup must square its Bar-facing left edge'
grep -Fq '|| directEdgeAttachment.atLeft' "$styled_popup" \
    || fail 'StyledPopup must also square a touched left Screen Edge'
grep -Fq 'joinTop: root._attachmentEdge === "top"' "$styled_popup" \
    || fail 'StyledPopup must square its Bar-facing top edge'
grep -Fq '|| directEdgeAttachment.atTop' "$styled_popup" \
    || fail 'StyledPopup must also square a touched top Screen Edge'
grep -Fq 'shadowTop: !frame.joinTop' "$styled_popup" \
    || fail 'StyledPopup shadow must stop at every joined top edge'
grep -Fq 'shadowLeft: !frame.joinLeft' "$styled_popup" \
    || fail 'StyledPopup shadow must stop at every joined left edge'
grep -Fq 'property bool joinLeft: false' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must expose direct-edge join state'
grep -Fq 'topLeftRadius: (root.joinTop || root.joinLeft) ? 0 : surfaceRadius' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must remove radius from attached corners'
grep -Fq 'id: shadowClip' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must clip radius-following shadow at attached edges'
grep -Fq 'topLeftRadius: body.topLeftRadius' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame shadow source must follow the body corner silhouette'
grep -Fq 'layer.effect: MultiEffect {' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must derive shadow from the popup silhouette'
grep -Fq 'ConnectedSurfaceJoinFlares {' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must add concave shoulders at directly joined edge endpoints'
grep -Fq 'property real joinFlareRadius: PerimeterTokens.joinFlareRadius' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must source join flare size from shared perimeter tokens'
grep -Fq 'No stem is' "$join_flares" \
    || fail 'join flare primitive must remain a direct-union shoulder rather than a connector stem'
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
    'alternativeVisibleCondition:' \
    'root.barMediaPopupVisible && root.popupMode === "bar"' \
    'closeOnOutsideClick: true' \
    'keyboardFocus: true' \
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
if grep -Fq 'active: (root.volumePopupVisible || root.containsMouse)' "$vertical_media"; then
    fail 'VerticalMedia volume HUD must not override StyledPopup LazyLoader.active'
fi
for token in \
    'import qs.modules.common.perimeter' \
    'sourceComponent: PanelWindow {' \
    'ConnectedSurfaceGeometry {' \
    'connectorLength: 0' \
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
grep -Fq 'readonly property real bottomAttachmentY:' "$overview" \
    || fail 'Overview must derive the direct bottom Bar/Screen Edge boundary'
grep -Fq 'root.bottomAttachmentY - bodyBottomInColumn' "$overview" \
    || fail 'Overview must place the dashboard body directly on the bottom attachment boundary'
grep -Fq 'directBottomAttachment: true' "$overview" \
    || fail 'Overview must tell the dashboard surface that its bottom edge is joined'
grep -Fq 'property bool directBottomAttachment: false' "$overview_dashboard" \
    || fail 'OverviewDashboard must expose direct bottom attachment state'
grep -Fq 'joinBottom: root.directBottomAttachment' "$overview_dashboard" \
    || fail 'Overview dashboard shadow must stop at its joined bottom edge'
grep -Fq 'bottomLeftRadius: root.directBottomAttachment ? 0 : radius' "$overview_dashboard" \
    || fail 'Overview dashboard must square its joined bottom corners'

grep -Fq 'StyledPopup {' "$media" \
    || fail 'normal Media UX must stay on StyledPopup'
grep -Fq 'GlobalStates.openSidebarRight' "$weather" \
    || fail 'normal Weather click route must stay on right-sidebar Weather UX'

printf 'PASS: broad perimeter runtime/common compatibility is absent; supported shell routes remain authoritative\n'
