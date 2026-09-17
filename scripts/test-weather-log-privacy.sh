#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Weather.qml"

fail() {
    printf 'weather log privacy guard failed: %s\n' "$1" >&2
    exit 1
}

grep -Fq -- 'function redactedLogLocationName' "$service" \
    || fail 'location-name redaction helper is missing'
grep -Fq -- 'console.warn("[Weather] No geocode results for:", root.redactedLogLocationName(root.configCity));' "$service" \
    || fail 'failed manual geocode log must redact the configured city'
grep -Fq -- 'console.info("[Weather] Location (fallback):", root.redactedLogLocationName(root.location.name));' "$service" \
    || fail 'fallback IP location log must redact the resolved location'

if grep -Fq -- 'console.warn("[Weather] No geocode results for:", root.configCity);' "$service"; then
    fail 'configured city is logged without redaction'
fi
if grep -Fq -- 'console.info("[Weather] Location (fallback):", root.location.name);' "$service"; then
    fail 'fallback location is logged without redaction'
fi

printf 'weather log privacy guards: ok\n'
