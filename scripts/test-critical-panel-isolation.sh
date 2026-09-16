#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
critical="$root/modules/ii/critical/ShellIiCriticalPanels.qml"
deferred="$root/ShellIiPanels.qml"

fail() {
    printf 'FAIL: critical panel isolation contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$critical" ]] || fail 'missing modules/ii/critical/ShellIiCriticalPanels.qml'
[[ -f "$deferred" ]] || fail 'missing ShellIiPanels.qml'

# Critical composition may depend on perimeter policy/registry authority, but it
# must not import concrete presentation packages whose local type failures would
# make the entire critical root unavailable before LazyLoader activation runs.
# Match the import semantically rather than pinning exact line spelling so aliases,
# optional semicolons, or harmless whitespace cannot bypass this startup guard.
optional_import_re='^[[:space:]]*import[[:space:]]+qs\.modules\.(background|bar|dock|verticalBar)([[:space:];]|$)'
if offending_import="$(grep -En -m1 "$optional_import_re" "$critical" || true)"; [[ -n "$offending_import" ]]; then
    fail "critical root still imports optional presentation module: $offending_import"
fi

if grep -Eq 'component:[[:space:]]*(Background|Bar|VerticalBar|Dock|PerimeterRuntime)[[:space:]]*\{' "$critical"; then
    fail 'critical root still embeds a concrete presentation component'
fi

for source_path in \
    '../../perimeter/PerimeterRuntime.qml' \
    '../../background/Background.qml' \
    '../../bar/Bar.qml' \
    '../../verticalBar/VerticalBar.qml' \
    '../../dock/Dock.qml'; do
    grep -Fq "source: Qt.resolvedUrl(\"$source_path\")" "$critical" \
        || fail "critical root does not source-load $source_path"
    resolved="$(realpath -m "$(dirname -- "$critical")/$source_path")"
    [[ -f "$resolved" ]] || fail "critical source target is missing: $source_path"
done

grep -Fq 'component CriticalPanelLoader: LazyLoader {' "$critical" \
    || fail 'critical presentation loader no longer inherits LazyLoader'
grep -Fxq 'import qs.modules.perimeter' "$critical" \
    || fail 'critical perimeter feature registry authority import is missing'
grep -Fxq 'import qs.modules.common.perimeter' "$critical" \
    || fail 'critical perimeter cutover authority import is missing'

# The broader ii presentation subtree is deferred as a source URL as well. This
# keeps type-resolution failures inside optional/deferred panels from becoming a
# compile-time dependency of the shell entry path.
grep -Fq 'source: "modules/ii/ShellIiPanelsImpl.qml"' "$deferred" \
    || fail 'deferred ii presentation subtree is not source-loaded'
grep -Fq 'loading: root.perimeterFeaturesReady && GlobalStates.deferredPanelsReady' "$deferred" \
    || fail 'deferred ii presentation subtree lost its readiness gate'
grep -Fq 'activeAsync: root.perimeterFeaturesReady && GlobalStates.deferredPanelsReady' "$deferred" \
    || fail 'deferred ii presentation subtree lost its async readiness gate'
[[ -f "$root/modules/ii/ShellIiPanelsImpl.qml" ]] \
    || fail 'deferred ii presentation source target is missing'

printf 'PASS: critical presentation modules are source-isolated from startup\n'
