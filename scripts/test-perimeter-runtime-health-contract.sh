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
grep -Fq 'function reportModuleFailure(' "$health" \
    || fail 'runtime health cannot record loader failures'
grep -Fq 'function clearModuleFailure(' "$health" \
    || fail 'runtime health cannot clear a recovered loader'
grep -Fq 'function hasMatchingFailure(' "$health" \
    || fail 'runtime health cannot match current placement fingerprints'
grep -Fq 'current.configRevision === configRevision' "$health" \
    || fail 'loader failures are not scoped to a stable config revision'

health_block="$(sed -n '/function _syncLoaderHealth()/,/^    }/p' "$host")"
[[ -n "$health_block" ]] || fail 'module host does not synchronize loader health'
grep -Fq 'moduleLoader.status === Loader.Error' <<<"$health_block" \
    || fail 'module host does not report Loader.Error'
grep -Fq 'PerimeterRuntimeHealth.reportModuleFailure(' <<<"$health_block" \
    || fail 'Loader.Error is not reported to runtime health'
grep -Fq 'moduleLoader.status === Loader.Ready' <<<"$health_block" \
    || fail 'module host does not recognize successful recovery'
grep -Fq 'PerimeterRuntimeHealth.clearModuleFailure(' <<<"$health_block" \
    || fail 'Loader.Ready does not clear its matching failure'
grep -Fq 'onStatusChanged: root._syncLoaderHealth()' "$host" \
    || fail 'module host does not observe loader status transitions'
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
grep -Fq '&& root.runtimeHealthy' "$policy" \
    || fail 'runtime loader health does not gate cutover enablement'
grep -Fq 'return "module-load-failure"' "$policy" \
    || fail 'loader fallback has no status reason'

printf 'PASS: perimeter runtime health contracts\n'
