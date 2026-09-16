#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
shell_root="$root/shell.qml"
policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
settings="$root/modules/settings/ShellLayoutConfig.qml"
route_controller="$root/modules/common/perimeter/SurfaceRouteController.qml"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
ii_panels="$root/modules/ii/ShellIiPanelsImpl.qml"

fail() {
    printf 'FAIL: perimeter family contract: %s\n' "$1" >&2
    exit 1
}

for file in "$shell_root" "$policy" "$settings" "$route_controller" \
        "$critical" "$ii_panels"; do
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
# intentionally deferred behind a URL boundary. The critical root must gate the
# loader with the same policy that disables legacy Bar/Dock ownership.
runtime_block="$(grep -A3 -F 'active: Config.ready && root.perimeterEnabled' "$critical")"
[[ -n "$runtime_block" ]] || fail 'critical ii tree no longer gates perimeter runtime'
grep -Fq 'source: Qt.resolvedUrl("../../perimeter/PerimeterRuntime.qml")' <<<"$runtime_block" \
    || fail 'critical cutover gate no longer resolves PerimeterRuntime behind a URL boundary'
if grep -Fq 'PerimeterRuntime' "$ii_panels"; then
    fail 'PerimeterRuntime moved into deferred ii panels'
fi

printf 'PASS: perimeter family contracts\n'
