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
require_literal 'if (wifiStatus === "connected" || wifiStatus === "limited") {' 'Wi-Fi strength scans must be gated by associated states'
require_literal 'if (!updateNetworkStrength.running)' 'Wi-Fi strength refresh must not overlap an in-flight scan'
require_literal 'if (root.wifiStatus !== "connected" && root.wifiStatus !== "limited") {' 'late Wi-Fi strength results must not restore stale signal state'
require_literal 'property int _subscriberRestartDelayMs: 2000' 'Network subscriber retry must start with a bounded 2s recovery delay'
require_literal 'readonly property int _subscriberRestartMaxDelayMs: 60000' 'Network subscriber retry backoff must cap at 60s'
require_literal 'subscriberRestart.interval = root._subscriberRestartDelayMs' 'Network subscriber retry must use the current backoff delay'
require_literal 'root._subscriberRestartDelayMs * 2' 'Repeated nmcli monitor failures must exponentially back off'
require_literal 'id: subscriberHealthyTimer' 'Network subscriber must distinguish a healthy monitor from a successful spawn'
require_literal 'interval: 10000' 'Network subscriber must prove stability before resetting retry backoff'
require_literal 'subscriberHealthyTimer.restart()' 'Started nmcli monitor must arm the stability window'
require_literal 'if (subscriber.running)' 'Network retry backoff must reset only while the monitor remains alive'
require_literal 'root._subscriberRestartDelayMs = 2000' 'Healthy nmcli monitor must reset retry backoff'
require_literal 'subscriberHealthyTimer.stop()' 'Exited nmcli monitor must cancel the stability reset'
require_literal 'command: ["nmcli", "-t", "-f", "TYPE,STATE", "d", "status"]' 'Network device-state probe must invoke nmcli directly'
require_literal '["nmcli", "-t", "-f", "CONNECTIVITY", "g"]' 'Network connectivity probe must invoke nmcli directly'
require_literal 'property bool chaining: false' 'Network status probe must serialize its direct nmcli stages'
require_literal 'property bool refreshPending: false' 'Network status probe must coalesce monitor events while a snapshot is in flight'
require_literal 'root._applyConnectionTypeSnapshot(' 'Network status probe must apply one coherent two-stage snapshot'
if grep -Fq 'command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status' "$service"; then
    fail 'Network status updates must not spawn a shell around nmcli'
fi

update_block="$(sed -n '/function _doUpdate()/,/^    }/p' "$service")"
if grep -Fq 'updateNetworkStrength.running = true' <<<"$update_block"; then
    fail 'network monitor updates must not launch Wi-Fi scans before connection state is known'
fi

printf 'network lifecycle guards: ok\n'
