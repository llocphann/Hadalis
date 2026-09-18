#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"
media="$root/modules/bar/Media.qml"
weather="$root/modules/bar/weather/WeatherBar.qml"
styled_popup="$root/modules/bar/StyledPopup.qml"
connected_frame="$root/modules/common/perimeter/ConnectedSurfaceFrame.qml"

fail() {
    printf 'FAIL: perimeter source retirement contract: %s\n' "$1" >&2
    exit 1
}

for file in "$critical" "$deferred" "$media" "$weather" "$styled_popup" "$connected_frame"; do
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
grep -Fq 'readonly property real directEdgeInset:' "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'SidebarHost must derive a direct Screen Edge body inset'
grep -Fq 'root.screenEdgeThickness - PerimeterTokens.seamOverlap' "$root/modules/sidebar/SidebarHost.qml" \
    || fail 'Sidebar body must overlap the inner Screen Edge boundary by the shared seam token'
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
grep -Fq 'joinLeft: directEdgeAttachment.atLeft' "$styled_popup" \
    || fail 'StyledPopup must square the body where it joins the left Screen Edge'
grep -Fq 'joinRight: directEdgeAttachment.atRight' "$styled_popup" \
    || fail 'StyledPopup must square the body where it joins the right Screen Edge'
grep -Fq 'joinTop: directEdgeAttachment.atTop' "$styled_popup" \
    || fail 'StyledPopup must square the body where it joins the top Screen Edge'
grep -Fq 'joinBottom: directEdgeAttachment.atBottom' "$styled_popup" \
    || fail 'StyledPopup must square the body where it joins the bottom Screen Edge'
grep -Fq 'property bool joinLeft: false' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must expose direct-edge join state'
grep -Fq 'topLeftRadius: (root.joinTop || root.joinLeft) ? 0 : surfaceRadius' "$connected_frame" \
    || fail 'ConnectedSurfaceFrame must remove rounded-card notches at joined corners'
grep -Fq 'shadowLeft: root._attachmentEdge !== "left"' "$styled_popup" \
    || fail 'StyledPopup must suppress duplicate shadow on an attached edge'
grep -Fq 'shadowRight: root._attachmentEdge !== "right"' "$styled_popup" \
    || fail 'StyledPopup must keep Screen Edge-compatible free-side shadow routing'
grep -Fq 'import qs.modules.common.perimeter' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
    || fail 'OSK must use shared perimeter seam tokens'
grep -Fq 'Math.max(0, screenEdgeThickness - PerimeterTokens.seamOverlap)' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
    || fail 'OSK body must overlap the Screen Edge directly'
if grep -Fq 'id: oskConnectorGeometry' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"; then
    fail 'OSK must not recreate a detached connector stem'
fi
if grep -Fq 'geometry: oskConnectorGeometry' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml"; then
    fail 'OSK must not render the retired connector geometry'
fi
grep -Fq 'screenEdgeShadowSize' "$root/modules/onScreenKeyboard/OnScreenKeyboard.qml" \
    || fail 'OSK shadow must share Screen Edge settings'

grep -Fq 'StyledPopup {' "$media" \
    || fail 'normal Media UX must stay on StyledPopup'
grep -Fq 'GlobalStates.openSidebarRight' "$weather" \
    || fail 'normal Weather click route must stay on right-sidebar Weather UX'

printf 'PASS: broad perimeter runtime/common compatibility is absent; supported shell routes remain authoritative\n'
