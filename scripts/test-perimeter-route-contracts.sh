#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
anchor_publisher="$root/modules/common/perimeter/AnchorPublisher.qml"
route_controller="$root/modules/common/perimeter/SurfaceRouteController.qml"
module_host="$root/modules/common/perimeter/PerimeterModuleHost.qml"
media_module="$root/modules/perimeter/MediaModule.qml"
media_surface="$root/modules/perimeter/MediaConnectedSurface.qml"
weather_module="$root/modules/perimeter/WeatherModule.qml"

fail() {
    printf 'FAIL: perimeter route contract: %s\n' "$1" >&2
    exit 1
}

for file in "$anchor_publisher" "$route_controller" "$module_host" \
        "$media_module" "$media_surface" "$weather_module"; do
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
# route family. Callers publish source identity, but the controller alone owns the
# authoritative anchor lookup and geometry snapshot used for routing.
for route_module in "$media_module" "$weather_module"; do
    request_block="$(sed -n '/function requestExpanded(): void {/,/^    }/p' "$route_module")"
    [[ -n "$request_block" ]] \
        || fail "$(basename "$route_module") is missing requestExpanded"
    grep -Fq 'if (!anchorPublisher.publish())' <<<"$request_block" \
        || fail "$(basename "$route_module") does not fail closed when anchor publication fails"
    grep -Fq 'SurfaceRouteController.toggle({' <<<"$request_block" \
        || fail "$(basename "$route_module") bypasses connected route controller"
    grep -Fq 'family: "perimeter"' <<<"$request_block" \
        || fail "$(basename "$route_module") can open a route outside perimeter fallback cleanup"
    if grep -Fq 'AnchorRegistry.lookup(' <<<"$request_block"; then
        fail "$(basename "$route_module") duplicates controller-owned anchor lookup"
    fi
    if grep -Fq 'anchorRect:' <<<"$request_block"; then
        fail "$(basename "$route_module") passes caller-owned geometry into route ownership"
    fi
done

# Media keyboard focus belongs to the connected surface only while it owns the
# active route. The deferred handoff must re-check ownership so a close/route
# replacement between the signal and Qt.callLater cannot steal focus.
grep -Fq 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand' "$media_surface" \
    || fail 'media connected surface no longer uses on-demand keyboard focus'
media_focus_block="$(sed -n '/onRouteOwnedChanged: {/,/ConnectedSurfaceGeometry {/p' "$media_surface")"
[[ -n "$media_focus_block" ]] || fail 'media connected surface is missing route-owned focus handoff'
grep -Fq 'if (!root.routeOwned)' <<<"$media_focus_block" \
    || fail 'media connected surface can request focus after losing route ownership'
grep -Fq 'Qt.callLater(() => {' <<<"$media_focus_block" \
    || fail 'media connected surface focus handoff is not deferred until route activation settles'
grep -Fq 'if (root.routeOwned)' <<<"$media_focus_block" \
    || fail 'deferred media focus handoff does not re-check route ownership'
grep -Fq 'mediaPopup.forceActiveFocus()' <<<"$media_focus_block" \
    || fail 'owned media connected surface no longer hands keyboard focus to the popup'

printf 'PASS: perimeter route contracts\n'
