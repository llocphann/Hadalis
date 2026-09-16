#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
health="$root/modules/common/perimeter/PerimeterRuntimeHealth.qml"
host="$root/modules/common/perimeter/PerimeterModuleHost.qml"
policy="$root/modules/common/perimeter/PerimeterCutoverPolicy.qml"
qmldir="$root/modules/common/perimeter/qmldir"

fail() {
    printf 'FAIL: perimeter runtime health contract: %s\n' "$1" >&2
    exit 1
}

for file in "$health" "$host" "$policy" "$qmldir"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

grep -Fxq 'singleton PerimeterRuntimeHealth 1.0 PerimeterRuntimeHealth.qml' "$qmldir" \
    || fail 'runtime health registry is not exported'

report_block="$(sed -n '/function reportModuleFailure(/,/^    }/p' "$health")"
clear_block="$(sed -n '/function clearModuleFailure(/,/^    }/p' "$health")"
match_block="$(sed -n '/function hasMatchingFailure(/,/^    }/p' "$health")"
[[ -n "$report_block" ]] || fail 'runtime health cannot record loader failures'
[[ -n "$clear_block" ]] || fail 'runtime health cannot clear a recovered loader'
[[ -n "$match_block" ]] || fail 'runtime health cannot match current placement fingerprints'

for field in moduleId source configRevision; do
    grep -Eq "^[[:space:]]*${field}:" <<<"$report_block" \
        || fail "reported loader failures do not persist ${field}"
    grep -Fq "current.${field}" <<<"$clear_block" \
        || fail "failure clearing is not scoped by ${field}"
    grep -Fq "current.${field}" <<<"$match_block" \
        || fail "failure matching is not scoped by ${field}"
done

health_block="$(sed -n '/function _syncLoaderHealth()/,/^    }/p' "$host")"
[[ -n "$health_block" ]] || fail 'module host does not synchronize loader health'
grep -Fq 'Loader.Error' <<<"$health_block" \
    || fail 'module host does not report Loader.Error'
grep -Fq 'PerimeterRuntimeHealth.reportModuleFailure(' <<<"$health_block" \
    || fail 'Loader.Error is not reported to runtime health'
grep -Fq 'Loader.Ready' <<<"$health_block" \
    || fail 'module host does not recognize successful recovery'
grep -Fq 'PerimeterRuntimeHealth.clearModuleFailure(' <<<"$health_block" \
    || fail 'Loader.Ready does not clear its matching failure'
for fingerprint in root.outputName root.instanceId root.moduleId root.configRevision; do
    grep -Fq "$fingerprint" <<<"$health_block" \
        || fail "module host health updates omit ${fingerprint#root.}"
done
grep -Eq 'onStatusChanged:[[:space:]].*_syncLoaderHealth\(' "$host" \
    || fail 'module host status transitions do not synchronize loader health'
if grep -Eq 'Component\.onDestruction:.*clearModuleFailure|onActiveChanged:.*clearModuleFailure' "$host"; then
    fail 'fallback teardown can clear loader failure and create an enable/error loop'
fi

runtime_block="$(sed -n '/readonly property bool runtimeHealthy:/,/^    }/p' "$policy")"
[[ -n "$runtime_block" ]] || fail 'cutover policy has no runtime health gate'
grep -Fq 'PerimeterRuntimeHealth.failureKeys' <<<"$runtime_block" \
    || fail 'cutover health does not react to failure registry changes'
grep -Fq 'PerimeterConfig.slotInstanceIds(outputName, slotId)' <<<"$runtime_block" \
    || fail 'runtime health is not scoped to effective placement'
grep -Fq 'PerimeterRuntimeHealth.hasMatchingFailure(' <<<"$runtime_block" \
    || fail 'runtime health ignores current failure fingerprints'
for fingerprint in outputName instanceId moduleId source Config.revision; do
    grep -Fq "$fingerprint" <<<"$runtime_block" \
        || fail "cutover health matching omits ${fingerprint}"
done
grep -Fq '&& root.runtimeHealthy' "$policy" \
    || fail 'runtime loader health does not gate cutover enablement'
grep -Fq 'return "module-load-failure"' "$policy" \
    || fail 'loader fallback has no status reason'

printf 'PASS: perimeter runtime health contracts\n'
