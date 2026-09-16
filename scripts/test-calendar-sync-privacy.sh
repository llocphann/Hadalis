#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/CalendarSync.qml"

fail() {
    printf 'calendar privacy guard failed: %s\n' "$1" >&2
    exit 1
}

if grep -Eq '_log\([^\n]*source\.url' "$service"; then
    fail 'calendar subscription URL is written to debug logs'
fi

grep -Fq -- '_log("Fetching source:", source.name, "(URL redacted)")' "$service" \
    || fail 'fetch log must explicitly redact the calendar URL'
grep -Fq -- '"--compressed", "-H", "Accept: text/calendar", source.url]' "$service" \
    || fail 'calendar fetch must still use the configured subscription URL'

printf 'calendar sync privacy guards: ok\n'
