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

require_literal 'import QtCore' 'missing QtCore StandardPaths support'
require_literal 'StandardPaths.findExecutable("checkupdates", [])' 'checkupdates availability must be resolved in-process through PATH'
require_literal 'onTriggered: root._refreshAvailability()' 'deferred availability check must use the in-process lookup'
if grep -Fq 'id: checkAvailabilityProc' "$service"; then
    fail 'checkupdates availability must not restore a shell process'
fi
if grep -Fq 'id: availabilityTimeout' "$service"; then
    fail 'in-process checkupdates availability must not retain a process watchdog'
fi
if grep -Fq 'command -v checkupdates' "$service"; then
    fail 'checkupdates availability must not restore command-v shell probing'
fi
require_literal 'id: updateCheckTimeout' 'missing checkupdates execution watchdog'
require_literal 'interval: 120000' 'update watchdog interval changed unexpectedly'
require_literal 'checkUpdatesProc.timedOut = true' 'update watchdog does not mark timeout state'
require_literal 'checkUpdatesProc.running = false' 'update watchdog does not terminate a stuck check'
require_literal 'if (exitCode === 2)' 'normal no-updates exit semantics were lost'

printf 'update-service lifecycle guards: ok\n'
