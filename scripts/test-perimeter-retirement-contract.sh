#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
common="$root/modules/common/perimeter"
qmldir="$common/qmldir"
styled="$root/modules/bar/StyledPopup.qml"
geometry="$common/ConnectedSurfaceGeometry.qml"
sidebar="$root/modules/sidebar/SidebarHost.qml"
overview="$root/modules/overview/Overview.qml"

fail() {
    printf 'FAIL: perimeter retirement contract: %s\n' "$1" >&2
    exit 1
}

for file in "$qmldir" "$styled" "$geometry" "$sidebar" "$overview"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

retired_files=(
    PerimeterConfig.qml
    PerimeterCutoverPolicy.qml
    PerimeterRuntimeHealth.qml
    ModuleRegistry.qml
    AnchorRegistry.qml
    SurfaceRouteController.qml
    PerimeterContext.qml
    PerimeterSlotModel.qml
    PerimeterModuleHost.qml
    PerimeterSlotHost.qml
    PerimeterOutputHost.qml
    AnchorPublisher.qml
    ConnectedSurfaceRouteState.qml
)
for file in "${retired_files[@]}"; do
    [[ ! -e "$common/$file" ]] || fail "retired common runtime helper still exists: $file"
    if grep -Fq "${file%.qml} " "$qmldir"; then
        fail "retired common runtime helper is still exported: $file"
    fi
done

for export in \
    'PerimeterTopology 1.0 PerimeterTopology.qml' \
    'PerimeterTokens 1.0 PerimeterTokens.qml' \
    'ConnectedSurfaceGeometry 1.0 ConnectedSurfaceGeometry.qml' \
    'ConnectedSurfaceConnector 1.0 ConnectedSurfaceConnector.qml' \
    'ConnectedSurfaceFrame 1.0 ConnectedSurfaceFrame.qml' \
    'ConnectedSurfaceContentHost 1.0 ConnectedSurfaceContentHost.qml' \
    'ConnectedSurfaceMask 1.0 ConnectedSurfaceMask.qml' \
    'ConnectedSurfaceIrisField 1.0 ConnectedSurfaceIrisField.qml' \
    'ConnectedSurfaceIrisFrame 1.0 ConnectedSurfaceIrisFrame.qml' \
    'ConnectedSurfaceBodyMask 1.0 ConnectedSurfaceBodyMask.qml'; do
    grep -Fq "$export" "$qmldir" || fail "supported perimeter export missing: $export"
done

grep -Fq 'PerimeterTopology.inwardDirectionForEdge(edge)' "$geometry" \
    || fail 'ConnectedSurfaceGeometry lost the supported edge utility'
grep -Fq 'property real connectorWidth: PerimeterTokens.connectorWidth' "$geometry" \
    || fail 'ConnectedSurfaceGeometry lost shared connector tokens'

for primitive in ConnectedSurfaceGeometry ConnectedSurfaceIrisFrame ConnectedSurfaceContentHost ConnectedSurfaceBodyMask; do
    grep -Fq "$primitive" "$styled" || fail "StyledPopup no longer uses supported primitive: $primitive"
done

grep -Fq 'ConnectedSurfaceConnector {' "$sidebar" \
    || fail 'SidebarHost lost its shared edge connector'
grep -Fq 'PerimeterTokens.seamOverlap' "$sidebar" \
    || fail 'SidebarHost lost shared seam geometry'
grep -Fq 'ConnectedSurfaceConnector {' "$overview" \
    || fail 'Overview lost its bottom Screen Edge connector'
grep -Fq 'PerimeterTokens.seamOverlap' "$overview" \
    || fail 'Overview lost shared seam geometry'

printf 'PASS: broad perimeter runtime/common helpers are retired; connected primitives remain supported\n'
