#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Network.qml"

fail() {
    printf 'network lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require_literal() {
    local literal="$1"
    local label="$2"
    grep -Fq -- "$literal" "$service" || fail "$label"
}

require_literal 'property bool attempted: false' 'Wi-Fi rescan attempt state is missing'
require_literal 'property bool startObserved: false' 'Wi-Fi rescan startup guard is missing'
require_literal 'property bool timedOut: false' 'Wi-Fi rescan timeout state is missing'
require_literal 'rescanTimeout.restart()' 'Wi-Fi rescan watchdog is not armed after start'
require_literal 'id: rescanTimeout' 'Wi-Fi rescan watchdog timer is missing'
require_literal 'interval: 30000' 'Wi-Fi rescan watchdog interval changed unexpectedly'
require_literal 'rescanProcess.timedOut = true' 'Wi-Fi rescan watchdog does not mark timeout state'
require_literal 'rescanProcess.running = false' 'Wi-Fi rescan watchdog does not terminate a stuck nmcli process'
require_literal 'root.wifiScanning = false' 'Wi-Fi rescan terminal paths do not release scanning UI state'

printf 'network lifecycle guards: ok\n'
