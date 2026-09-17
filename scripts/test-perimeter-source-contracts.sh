#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
feature_registry="$root/modules/perimeter/PerimeterFeatureRegistry.qml"

fail() {
    printf 'FAIL: perimeter source contract: %s\n' "$1" >&2
    exit 1
}

[[ -f "$feature_registry" ]] \
    || fail 'missing modules/perimeter/PerimeterFeatureRegistry.qml'

registration_count="$(grep -Ec '\{ moduleId: "[^"]+", source:' "$feature_registry" || true)"
resolved_count="$(grep -Ec 'source: Qt\.resolvedUrl\("[^"]+\.qml"\)' "$feature_registry" || true)"

[[ "$registration_count" -gt 0 ]] \
    || fail 'feature registry exposes no builtin module sources'
[[ "$registration_count" -eq "$resolved_count" ]] \
    || fail 'builtin feature registration bypasses local resolved QML sources'

mapfile -t feature_sources < <(
    sed -n 's/.*source: Qt\.resolvedUrl("\([^"]*\.qml\)").*/\1/p' "$feature_registry"
)
[[ "${#feature_sources[@]}" -eq "$registration_count" ]] \
    || fail 'could not resolve every builtin feature source path'

registry_dir="$(dirname -- "$feature_registry")"
for source in "${feature_sources[@]}"; do
    [[ -f "$registry_dir/$source" ]] \
        || fail "feature registry points to missing source: $source"
done

printf 'PASS: perimeter registered feature sources\n'
