#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
screen_edges="$root/modules/screenCorners/ScreenEdges.qml"
sidebar="$root/modules/sidebar/SidebarEdgeConnectors.qml"
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
    'panelId: isLeftEdge ? "iiSidebarLeft" : "iiSidebarRight"' \
    'GlobalStates.sidebarLeftPresentationOutput' \
    'GlobalStates.sidebarRightPresentationOutput' \
    'BridgeWindow { edge: "left" }' \
    'BridgeWindow { edge: "right" }' \
    'PerimeterTokens.seamOverlap'; do
    grep -Fq "$token" "$sidebar" || fail "semantic sidebar bridge missing: $token"
done
if grep -Fq 'Config.options?.bar' "$sidebar" || grep -Fq 'barVertical' "$sidebar"; then
    fail 'sidebar edge connectors must stay independent of Bar placement/orientation'
fi

grep -Fq 'visible: surfaceSection.sidebarRole' "$settings" \
    || fail 'Shell Layout must retain supported sidebar sizing controls'
grep -Fq 'text: Translation.tr("Width")' "$settings" \
    || fail 'Shell Layout must retain sidebar width setting'

printf 'PASS: persistent Screen Edge and semantic left/right sidebar placement remain supported\n'
