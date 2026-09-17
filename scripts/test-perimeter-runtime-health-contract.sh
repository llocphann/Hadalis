#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"
common_qmldir="$root/modules/common/perimeter/qmldir"
styled="$root/modules/bar/StyledPopup.qml"
sidebar="$root/modules/sidebar/SidebarEdgeConnectors.qml"

fail() {
    printf 'FAIL: perimeter runtime retirement contract: %s\n' "$1" >&2
    exit 1
}

for file in "$critical" "$deferred" "$common_qmldir" "$styled" "$sidebar"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

for retired in PerimeterRuntime PerimeterFeatureRegistry PerimeterRuntimeHealth PerimeterCutoverPolicy; do
    if grep -Fq "$retired" "$critical" || grep -Fq "$retired" "$deferred"; then
        fail "active ii shell still depends on retired runtime authority: $retired"
    fi
done

for export in \
    'PerimeterTokens 1.0 PerimeterTokens.qml' \
    'ConnectedSurfaceGeometry 1.0 ConnectedSurfaceGeometry.qml' \
    'ConnectedSurfaceConnector 1.0 ConnectedSurfaceConnector.qml' \
    'ConnectedSurfaceFrame 1.0 ConnectedSurfaceFrame.qml' \
    'ConnectedSurfaceContentHost 1.0 ConnectedSurfaceContentHost.qml' \
    'ConnectedSurfaceMask 1.0 ConnectedSurfaceMask.qml'; do
    grep -Fq "$export" "$common_qmldir" \
        || fail "supported shared perimeter export missing: $export"
done

for primitive in ConnectedSurfaceGeometry ConnectedSurfaceFrame ConnectedSurfaceContentHost ConnectedSurfaceMask; do
    grep -Fq "$primitive" "$styled" \
        || fail "StyledPopup no longer uses supported primitive: $primitive"
done

grep -Fq 'ConnectedSurfaceConnector' "$sidebar" \
    || fail 'sidebar edge bridges no longer use the shared connector primitive'
grep -Fq 'PerimeterTokens.seamOverlap' "$sidebar" \
    || fail 'sidebar edge bridges no longer share perimeter geometry tokens'

printf 'PASS: retired perimeter runtime stays outside active shell; shared primitives remain supported\n'
