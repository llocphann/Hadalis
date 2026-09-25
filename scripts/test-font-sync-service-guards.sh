#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/FontSyncService.qml"
helper="$repo_root/scripts/colors/sync-system-fonts.sh"

fail() {
    printf 'font-sync lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require_literal() {
    local file="$1"
    local literal="$2"
    local label="$3"
    grep -Fq -- "$literal" "$file" || fail "$label"
}

require_literal "$service" 'property bool startObserved: false' 'missing process-start guard state'
require_literal "$service" 'property bool timedOut: false' 'missing timeout state'
require_literal "$service" 'fontSyncTimeout.stop()' 'timeout is not cancelled on terminal process paths'
require_literal "$service" 'fontSyncTimeout.restart()' 'timeout is not armed after process start'
require_literal "$service" 'if (fontSyncProc.timedOut)' 'timeout exit is not reported distinctly'
require_literal "$service" 'id: fontSyncTimeout' 'missing font-sync watchdog timer'
require_literal "$service" 'interval: 30000' 'font-sync watchdog interval changed unexpectedly'
require_literal "$service" 'fontSyncProc.timedOut = true' 'watchdog does not mark timeout state'
require_literal "$service" 'fontSyncProc.running = false' 'watchdog does not terminate a stuck helper'
require_literal "$helper" 'flock -w 15 9' 'helper lock wait must remain bounded below the service watchdog'

printf 'font-sync lifecycle guards: ok\n'
