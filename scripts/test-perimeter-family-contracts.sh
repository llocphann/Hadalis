#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell_root="$root/shell.qml"
policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
runtime_health="$root/modules/common/perimeter/PerimeterRuntimeHealth.qml"
runtime="$root/modules/perimeter/PerimeterRuntime.qml"
settings="$root/modules/settings/ShellLayoutConfig.qml"
route_controller="$root/modules/common/perimeter/SurfaceRouteController.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
ii_panels="$root/modules/ii/ShellIiPanelsImpl.qml"

fail() {
    printf 'FAIL: perimeter family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell_root" "$policy" "$runtime_health" "$runtime" "$settings" \
        "$route_controller" "$critical" "$ii_panels"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

# The policy must mirror the exact ii/Waffle loader boundary owned by shell.qml.
grep -Fq '(Config.options?.panelFamily ?? "ii") !== "waffle"' "$shell_root" \
    || fail 'ii family loader boundary changed'
grep -Fq 'readonly property bool familyActive:' "$policy" \
    || fail 'cutover policy does not expose family activity'
grep -Fq '(Config.options?.panelFamily ?? "ii") !== "waffle"' "$policy" \
    || fail 'cutover policy does not match ii family loader semantics'
grep -Fq '&& root.familyActive' "$policy" \
    || fail 'cutover can report active while ii family is unloaded'
grep -Fq 'return "inactive-family"' "$policy" \
    || fail 'inactive family fallback has no status reason'

# Request intent persists across family switches; runtime activity does not.
grep -Fq 'readonly property bool perimeterRequested: PerimeterCutoverPolicy.requested' "$settings" \
    || fail 'settings no longer preserves perimeter request intent'
grep -Fq 'readonly property bool perimeterActive: PerimeterCutoverPolicy.enabled' "$settings" \
    || fail 'settings no longer reports policy runtime state'

# A family switch must tear down already-open connected perimeter routes.
grep -Fq 'target: PerimeterCutoverPolicy' "$route_controller" \
    || fail 'route controller does not observe cutover activity'
grep -Fq 'root._closePerimeterRoutesForFallback()' "$route_controller" \
    || fail 'family fallback cannot close perimeter routes'

# PerimeterRuntime belongs in the critical ii tree, but presentation QML is
# intentionally deferred behind a URL boundary. Runtime activation must use the
# pre-cutover eligibility gate so it can establish the root readiness handshake;
# legacy Bar/Dock ownership remains until the final enabled gate becomes true.
grep -Fq 'readonly property bool activationEligible:' "$policy" \
    || fail 'cutover policy does not expose runtime activation eligibility'
grep -Fq 'readonly property bool runtimeReady: PerimeterRuntimeHealth.runtimeHostReady' "$policy" \
    || fail 'cutover policy does not consume the runtime-root handshake'
grep -Fq '&& root.runtimeReady' "$policy" \
    || fail 'final cutover does not require runtime readiness'
grep -Fq 'property bool runtimeHostReady: false' "$runtime_health" \
    || fail 'runtime health does not track root readiness'
grep -Fq 'PerimeterRuntimeHealth.setRuntimeHostReady(root.active && root.featuresReady)' "$runtime" \
    || fail 'perimeter runtime does not publish a successful root handshake'
grep -Fq 'Component.onDestruction: PerimeterRuntimeHealth.setRuntimeHostReady(false)' "$runtime" \
    || fail 'perimeter runtime does not clear root readiness on teardown'

runtime_block="$(grep -A3 -F 'active: Config.ready && root.perimeterActivationEligible' "$critical")"
[[ -n "$runtime_block" ]] || fail 'critical ii tree no longer gates perimeter runtime with activation eligibility'
grep -Fq 'source: Qt.resolvedUrl("../../perimeter/PerimeterRuntime.qml")' <<<"$runtime_block" \
    || fail 'critical runtime gate no longer resolves PerimeterRuntime behind a URL boundary'
grep -Fq 'extraCondition: !root.perimeterEnabled' "$critical" \
    || fail 'legacy critical chrome no longer waits for final perimeter cutover'
mapped_block="$(grep -A2 -F 'readonly property bool mapped: hostActive' "$runtime")"
grep -Fq '&& PerimeterCutoverPolicy.enabled' <<<"$mapped_block" \
    || fail 'connected perimeter chrome can map before final cutover'
if grep -Fq 'PerimeterRuntime' "$ii_panels"; then
    fail 'PerimeterRuntime moved into deferred ii panels'
fi

printf 'PASS: perimeter family contracts\n'
