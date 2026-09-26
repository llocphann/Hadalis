#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Updates.qml"

fail() {
    printf 'update-service lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require_literal() {
    local literal="$1"
    local label="$2"
    grep -Fq -- "$literal" "$service" || fail "$label"
}

if grep -Fq -- 'checkAvailabilityProc' "$service"; then
    fail 'checkupdates availability must not use a separate helper process'
fi
if grep -Fq -- 'availabilityTimeout' "$service"; then
    fail 'removed availability helper must not retain a separate watchdog'
fi
if grep -Fq -- 'command -v checkupdates' "$service"; then
    fail 'checkupdates availability must be proven by the real checker process'
fi
require_literal 'if (checkUpdatesProc.running) return;' 'update refresh must deduplicate the real checker process'
require_literal 'onTriggered: root.refresh()' 'startup availability defer must run the real checker directly'
require_literal 'root.available = true' 'successful checkupdates spawn must mark the service available'
require_literal 'root.available = false' 'failed checkupdates spawn must fail availability closed'
require_literal 'id: updateCheckTimeout' 'missing checkupdates execution watchdog'
require_literal 'interval: 120000' 'update watchdog interval changed unexpectedly'
require_literal 'checkUpdatesProc.timedOut = true' 'update watchdog does not mark timeout state'
require_literal 'checkUpdatesProc.running = false' 'update watchdog does not terminate a stuck check'
require_literal 'if (exitCode === 2)' 'normal no-updates exit semantics were lost'

printf 'update-service lifecycle guards: ok\n'
