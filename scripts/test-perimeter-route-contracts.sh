#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
anchor_publisher="$root/modules/common/perimeter/AnchorPublisher.qml"
route_controller="$root/modules/common/perimeter/SurfaceRouteController.qml"
module_host="$root/modules/common/perimeter/PerimeterModuleHost.qml"
media_module="$root/modules/perimeter/MediaModule.qml"
weather_module="$root/modules/perimeter/WeatherModule.qml"

fail() {
    printf 'FAIL: perimeter route contract: %s\n' "$1" >&2
    exit 1
}

for file in "$anchor_publisher" "$route_controller" "$module_host" \
        "$media_module" "$weather_module"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

# Hidden/zero-area sources must withdraw anchor authority immediately.
grep -Fq '!root.sourceItem.visible' "$anchor_publisher" \
    || fail 'anchor publisher accepts hidden source items'
grep -Fq 'root.sourceItem.width <= 0 || root.sourceItem.height <= 0' "$anchor_publisher" \
    || fail 'anchor publisher accepts zero-area source items'
grep -Fq 'root._unregisterPublished()' "$anchor_publisher" \
    || fail 'anchor publisher cannot withdraw stale anchors'
grep -Fq 'Component.onDestruction: root._unregisterPublished()' "$anchor_publisher" \
    || fail 'destroyed anchor publisher can leave stale registry state'
grep -Fq 'function onVisibleChanged() { root.publish() }' "$anchor_publisher" \
    || fail 'anchor publisher does not react to source visibility changes'

# Slot movement, sibling reflow, and module resizing must republish output-local
# anchor geometry even when the source's own visible state is unchanged.
grep -Fq 'onContextLayoutRevisionChanged: publish()' "$anchor_publisher" \
    || fail 'anchor publisher ignores host layout revisions'
grep -Fq 'onEffectiveReferenceRectChanged: publish()' "$anchor_publisher" \
    || fail 'anchor publisher ignores slot movement in output-local coordinates'
for geometry_signal in onXChanged onYChanged onWidthChanged onHeightChanged; do
    grep -Fq "$geometry_signal: root._bumpAnchorLayoutRevision()" "$module_host" \
        || fail "module host no longer propagates $geometry_signal into anchor reflow"
done
grep -Fq 'layoutRevision: root.anchorLayoutRevision' "$module_host" \
    || fail 'module host layout revision is not exposed through perimeter context'

# Routes must fail closed when source geometry disappears.
grep -Fq 'function onRemoved(key) {' "$route_controller" \
    || fail 'route controller does not observe anchor removal'
grep -Fq 'root._onAnchorRemoved(key)' "$route_controller" \
    || fail 'anchor removal is not routed through fail-closed handling'
grep -Fq 'root.close(outputName, "source-hidden")' "$route_controller" \
    || fail 'route controller cannot close hidden sources'

# Perimeter connected surfaces must never survive or reopen during legacy fallback.
grep -Fq 'family === "perimeter" && !PerimeterCutoverPolicy.enabled' "$route_controller" \
    || fail 'perimeter route can open while cutover is inactive'
grep -Fq 'function _closePerimeterRoutesForFallback() {' "$route_controller" \
    || fail 'route controller cannot clear perimeter routes on fallback'
grep -Fq 'String(active?.family ?? "") === "perimeter"' "$route_controller" \
    || fail 'fallback cleanup is not scoped to perimeter routes'
grep -Fq 'target: PerimeterCutoverPolicy' "$route_controller" \
    || fail 'route controller does not observe cutover policy changes'
grep -Fq 'root._closePerimeterRoutesForFallback()' "$route_controller" \
    || fail 'cutover changes do not trigger perimeter route cleanup'

# Connected-surface callers must identify themselves as perimeter routes so the
# controller's cutover/family fail-safe cannot be bypassed by an implicit default
# route family.
for route_module in "$media_module" "$weather_module"; do
    request_block="$(sed -n '/function requestExpanded(): void {/,/^    }/p' "$route_module")"
    [[ -n "$request_block" ]] \
        || fail "$(basename "$route_module") is missing requestExpanded"
    grep -Fq 'SurfaceRouteController.toggle({' <<<"$request_block" \
        || fail "$(basename "$route_module") bypasses connected route controller"
    grep -Fq 'family: "perimeter"' <<<"$request_block" \
        || fail "$(basename "$route_module") can open a route outside perimeter fallback cleanup"
done

printf 'PASS: perimeter route contracts\n'
