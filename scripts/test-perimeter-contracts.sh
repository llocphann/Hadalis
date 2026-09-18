#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
common="$root/modules/common/perimeter"
styled="$root/modules/bar/StyledPopup.qml"
sidebar="$root/modules/sidebar/SidebarHost.qml"
screen_edge="$root/modules/screenCorners/ScreenEdges.qml"
overview="$root/modules/overview/Overview.qml"
dashboard="$root/modules/overview/OverviewDashboard.qml"

fail() {
    printf 'FAIL: perimeter shared contract: %s\n' "$1" >&2
    exit 1
}

for file in \
    PerimeterTokens.qml \
    ConnectedSurfaceGeometry.qml \
    ConnectedSurfaceConnector.qml \
    ConnectedSurfaceFrame.qml \
    ConnectedSurfaceContentHost.qml \
    ConnectedSurfaceMask.qml; do
    [[ -f "$common/$file" ]] || fail "missing shared primitive $file"
done

for primitive in ConnectedSurfaceGeometry ConnectedSurfaceFrame ConnectedSurfaceContentHost ConnectedSurfaceMask; do
    grep -Fq "$primitive" "$styled" \
        || fail "StyledPopup must keep using $primitive"
done

grep -Fq 'mask: connectedMask' "$styled" \
    || fail 'StyledPopup must keep the shaped connected input mask'
grep -Fq 'progress: root.revealProgress' "$styled" \
    || fail 'StyledPopup must keep morphing through shared reveal geometry'
for token in \
    'readonly property real _barSurfaceThickness:' \
    'Appearance.sizes.verticalBarWidth' \
    'Appearance.sizes.barHeight' \
    'return Qt.rect(barX, mapped.y, thickness, target.height)' \
    'return Qt.rect(mapped.x, barY, target.width, thickness)'; do
    grep -Fq "$token" "$styled" \
        || fail "StyledPopup must keep control-centered tangent placement while attaching to the physical Bar edge: $token"
done
grep -Fq 'property real connectorWidth: PerimeterTokens.connectorWidth' "$common/ConnectedSurfaceGeometry.qml" \
    || fail 'connected geometry must source neck width from PerimeterTokens'
grep -Fq 'readonly property real connectorWidth: 40' "$common/PerimeterTokens.qml" \
    || fail 'shared connector width token changed unexpectedly'
for token in \
    'import qs.modules.common.perimeter' \
    'readonly property real directEdgeInset:' \
    'root.screenEdgeThickness - PerimeterTokens.seamOverlap' \
    'rightMargin: root.isLeftEdge' \
    'leftMargin: root.isLeftEdge'; do
    grep -Fq "$token" "$sidebar" \
        || fail "SidebarHost must directly overlap the left/right Screen Edge: $token"
done
if grep -Fq 'id: sidebarBridgeGeometry' "$sidebar" \
        || grep -Fq 'ConnectedSurfaceConnector {' "$sidebar"; then
    fail 'SidebarHost must not retain a visible connector-shaped bridge'
fi

for token in \
    'import qs.modules.common.perimeter' \
    'id: overviewBottomConnectorGeometry' \
    'readonly property string edge: "bottom"' \
    'readonly property bool bottomBarOwnsEdge:' \
    'Config.options?.bar?.screenList' \
    'readonly property real attachmentThickness:' \
    'root.bottomBarOwnsEdge ? Appearance.sizes.barHeight : edgeThickness' \
    'readonly property bool valid: root.iiFamily' \
    'PerimeterTokens.seamOverlap' \
    'ConnectedSurfaceConnector {' \
    'dashboard.connectedSurfaceRect'; do
    grep -Fq "$token" "$overview" \
        || fail "Overview dashboard must remain connected to the bottom Screen Edge: $token"
done
grep -Fq 'readonly property rect connectedSurfaceRect:' "$dashboard" \
    || fail 'OverviewDashboard must expose the visible dashboard surface geometry'
grep -Fq 'readonly property color connectedSurfaceColor:' "$dashboard" \
    || fail 'OverviewDashboard must expose its connector surface color'

for token in \
    'readonly property color edgeColor: Appearance.colors.colLayer0' \
    'function barOwnsEdge(outputName, edge)' \
    '&& !GlobalStates.widgetEditMode' \
    'Config.options?.bar?.screenList' \
    '&& !root.barOwnsEdge(outputName, edge)' \
    'readonly property bool adjacentBarOwned:' \
    '&& !adjacentBarOwned'; do
    grep -Fq "$token" "$screen_edge" \
        || fail "Screen Edge must suppress the Bar-owned edge/corners and share the Material Bar surface token: $token"
done

if grep -Fq 'qs.modules.perimeter' "$styled" || grep -Fq 'qs.modules.perimeter' "$sidebar"; then
    fail 'active connected surfaces must not import the retired broad perimeter module'
fi

printf 'PASS: shared connected-surface primitives remain the active popup/sidebar contract\n'
