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
    ConnectedSurfaceJoinFlares.qml \
    ConnectedSurfaceRevealClip.qml \
    ConnectedSurfaceContentHost.qml \
    ConnectedSurfaceMask.qml \
    ConnectedSurfaceIrisField.qml \
    ConnectedSurfaceIrisFrame.qml \
    ConnectedSurfaceBodyMask.qml \
    IrisField.frag \
    IrisField.frag.qsb; do
    [[ -f "$common/$file" ]] || fail "missing shared primitive $file"
done

for primitive in ConnectedSurfaceGeometry ConnectedSurfaceIrisFrame ConnectedSurfaceRevealClip ConnectedSurfaceContentHost ConnectedSurfaceBodyMask; do
    grep -Fq "$primitive" "$styled" \
        || fail "StyledPopup must keep using $primitive"
done

grep -Fq 'mask: connectedMask' "$styled" \
    || fail 'StyledPopup must keep the shaped connected input mask'
grep -Fq 'progress: root.revealProgress' "$styled" \
    || fail 'StyledPopup must keep driving shared reveal geometry'
grep -Fq 'ConnectedSurfaceRevealClip {' "$styled" \
    || fail 'StyledPopup must clip translated pixels at the resting Bar/Screen Edge seam'
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
    'width: Math.max(0, root.effectiveSidebarWidth' \
    '- Appearance.sizes.elevationMargin)' \
    'rightMargin: root.isLeftEdge' \
    '? Appearance.sizes.elevationMargin' \
    ': 0' \
    'leftMargin: root.isLeftEdge' \
    '? 0' \
    ': Appearance.sizes.elevationMargin'; do
    grep -Fq -- "$token" "$sidebar" \
        || fail "SidebarHost must underlap the full attached Screen Edge band: $token"
done
if grep -Fq 'directEdgeInset' "$sidebar" \
        || grep -Fq 'screenEdgeThickness' "$sidebar"; then
    fail 'SidebarHost must not stop the body at the inner Screen Edge boundary'
fi
if grep -Fq 'id: sidebarBridgeGeometry' "$sidebar" \
        || grep -Fq 'ConnectedSurfaceConnector {' "$sidebar"; then
    fail 'SidebarHost must not retain a visible connector-shaped bridge'
fi

for token in \
    'import qs.modules.common.perimeter' \
    'readonly property real edgeDecorationMargin:' \
    'PerimeterTokens.joinFlareRadius' \
    'ConnectedSurfaceJoinFlares {' \
    'bodyItem: sidebarContentLoader' \
    'joinLeft: root.isLeftEdge' \
    'joinRight: !root.isLeftEdge'; do
    grep -Fq "$token" "$sidebar" \
        || fail "SidebarHost must render Caelestia-style Screen Edge endpoint flares: $token"
done

for token in \
    'import qs.modules.common.perimeter' \
    'readonly property bool bottomBarOwnsEdge:' \
    'Config.options?.bar?.screenList' \
    'readonly property real bottomAttachmentThickness:' \
    'readonly property real bottomAttachmentY:' \
    '- root.bottomAttachmentThickness' \
    'readonly property bool dashboardPresentationMode:' \
    'root.bottomAttachmentY - bodyBottomInColumn' \
    'popupPresented: root._presentedOpen'; do
    grep -Fq -- "$token" "$overview" \
        || fail "Overview dashboard must stay directly attached and popup-like: $token"
done
if grep -Fq 'ConnectedSurfaceConnector {' "$overview" \
        || grep -Fq 'overviewBottomConnectorGeometry' "$overview"; then
    fail 'Overview must not restore connector/stem geometry'
fi
for token in \
    'import qs.modules.common.perimeter' \
    'property bool directBottomAttachment: false' \
    'property bool popupPresented: true' \
    'property real revealProgress: 0' \
    'id: dashboardSurfaceLayer' \
    '(1 - root.revealProgress) * dashContainer.height' \
    'clip: root.directBottomAttachment' \
    'ConnectedSurfaceJoinFlares {' \
    'joinBottom: root.directBottomAttachment' \
    'blur: root.screenEdgeShadowSize' \
    'readonly property rect connectedSurfaceRect:'; do
    grep -Fq "$token" "$dashboard" \
        || fail "OverviewDashboard must behave like a bottom-connected popup: $token"
done

for token in \
    'import qs.modules.waffle.looks as WaffleLooks' \
    'readonly property bool waffleBarPanelEnabled:' \
    '(Config.options?.enabledPanels ?? []).includes("wBar")' \
    'readonly property string waffleBarEdge:' \
    'Config.options?.waffles?.bar?.screenList' \
    '? WaffleLooks.Looks.colors.bg0' \
    'function barOwnsEdge(outputName, edge)' \
    'GlobalStates.widgetEditMode' \
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
