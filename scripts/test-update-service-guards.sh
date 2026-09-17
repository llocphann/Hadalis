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

require_literal 'id: availabilityTimeout' 'missing checkupdates availability watchdog'
require_literal 'interval: 5000' 'availability watchdog interval changed unexpectedly'
require_literal 'checkAvailabilityProc.timedOut = true' 'availability watchdog does not mark timeout state'
require_literal 'checkAvailabilityProc.running = false' 'availability watchdog does not terminate a stuck probe'
require_literal 'id: updateCheckTimeout' 'missing checkupdates execution watchdog'
require_literal 'interval: 120000' 'update watchdog interval changed unexpectedly'
require_literal 'checkUpdatesProc.timedOut = true' 'update watchdog does not mark timeout state'
require_literal 'checkUpdatesProc.running = false' 'update watchdog does not terminate a stuck check'
require_literal 'if (exitCode === 2)' 'normal no-updates exit semantics were lost'

printf 'update-service lifecycle guards: ok\n'
