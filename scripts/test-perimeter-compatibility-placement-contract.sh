#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
screen_edges="$root/modules/screenCorners/ScreenEdges.qml"
sidebar="$root/modules/sidebar/SidebarHost.qml"
settings="$root/modules/settings/ShellLayoutConfig.qml"

fail() {
    printf 'FAIL: connected placement compatibility contract: %s\n' "$1" >&2
    exit 1
}

for file in "$screen_edges" "$sidebar" "$settings"; do
    [[ -f "$file" ]] || fail "missing ${file#$root/}"
done

grep -Fq 'Config.options?.appearance?.screenEdge?.width ?? 10' "$screen_edges" \
    || fail 'persistent Screen Edge width/default contract is missing'
if grep -Fq 'screenEdge?.enable' "$screen_edges"; then
    fail 'stale Screen Edge enable flag must not disable persistent edge chrome'
fi
for edge in top bottom left right; do
    grep -Fq "EdgeWindow { edge: \"$edge\" }" "$screen_edges" \
        || fail "persistent Screen Edge missing $edge output edge"
done

for token in \
    'required property string edge' \
    'readonly property bool isLeftEdge: root.edge === "left"' \
    'GlobalStates.sidebarLeftPresentationOutput' \
    'GlobalStates.sidebarRightPresentationOutput' \
    'id: sidebarBridgeGeometry' \
    'ConnectedSurfaceConnector {' \
    'PerimeterTokens.seamOverlap'; do
    grep -Fq "$token" "$sidebar" || fail "semantic SidebarHost bridge missing: $token"
done

grep -Fq 'visible: surfaceSection.sidebarRole' "$settings" \
    || fail 'Shell Layout must retain supported sidebar sizing controls'
grep -Fq 'text: Translation.tr("Width")' "$settings" \
    || fail 'Shell Layout must retain sidebar width setting'

printf 'PASS: persistent Screen Edge and semantic left/right SidebarHost placement remain supported\n'
