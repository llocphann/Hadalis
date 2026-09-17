#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
common="$root/modules/common/perimeter"
styled="$root/modules/bar/StyledPopup.qml"
sidebar="$root/modules/sidebar/SidebarEdgeConnectors.qml"

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
grep -Fq 'property real connectorWidth: PerimeterTokens.connectorWidth' "$common/ConnectedSurfaceGeometry.qml" \
    || fail 'connected geometry must source neck width from PerimeterTokens'
grep -Fq 'readonly property real connectorWidth: 40' "$common/PerimeterTokens.qml" \
    || fail 'shared connector width token changed unexpectedly'
grep -Fq 'ConnectedSurfaceConnector' "$sidebar" \
    || fail 'left/right sidebar bridges must remain shared connected-surface consumers'

if grep -Fq 'qs.modules.perimeter' "$styled" || grep -Fq 'qs.modules.perimeter' "$sidebar"; then
    fail 'active connected surfaces must not import the retired broad perimeter module'
fi

printf 'PASS: shared connected-surface primitives remain the active popup/sidebar contract\n'
