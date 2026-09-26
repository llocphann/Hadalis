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

forbid_literal() {
    local literal="$1"
    local label="$2"
    if grep -Fq -- "$literal" "$service"; then
        fail "$label"
    fi
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
require_literal 'const hasActiveLink = hasEthernet || wifiStatus === "connected" || wifiStatus === "limited"' 'active connection name must be demand-gated by link state'
require_literal 'if (!updateNetworkName.running)' 'active connection name query must not overlap'
require_literal 'root.networkName = ""' 'disconnected state must clear stale active connection name'
require_literal 'if (!updateNetworkStrength.running)' 'Wi-Fi signal query must be demand-gated and non-overlapping'
require_literal 'nmcli -t -f CONNECTIVITY g && nmcli radio wifi' 'radio state must share the main status process'
require_literal 'const radioState = lines.pop()' 'combined status parser must consume radio state'
require_literal 'if (!wifiStatusProcess.running)' 'failed combined status query must retain a radio-state fallback'
require_literal 'function _wifiNetworkKey(network): string' 'Wi-Fi scan reconciliation key helper is missing'
require_literal 'const existingByKey = new Map()' 'Wi-Fi scan reconciliation must index existing rows once'
require_literal 'const nextKeys = new Set()' 'Wi-Fi scan reconciliation must index incoming rows once'
forbid_literal 'rNetworks.filter(rn => !wifiNetworks.find' 'Wi-Fi scan reconciliation must not restore quadratic filter/find matching'

printf 'network lifecycle guards: ok\n'
