#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Hyprsunset.qml"

fail() {
    printf 'night-light lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require_started_block() {
    local process_id="$1"
    local timeout_id="$2"
    local block
    block="$(sed -n "/id: ${process_id}$/,/^    }/p" "$service")"
    [[ -n "$block" ]] || fail "$process_id process block is missing"
    grep -Fq "${process_id}.startObserved = true" <<<"$block" \
        || fail "$process_id must record successful startup"
    grep -Fq "${timeout_id}.restart()" <<<"$block" \
        || fail "$process_id must restart its state-probe timeout after spawn"
}

require 'id: fetchProc' 'Hyprland state probe is missing'
require_started_block 'fetchProc' 'hyprStateProbeTimeout'
require 'console.warn("[Hyprsunset] Hyprland state probe failed to start")' \
    'Hyprland state probe must handle spawn failure'
require 'id: niriFetchProc' 'Niri state probe is missing'
require_started_block 'niriFetchProc' 'niriStateProbeTimeout'
require 'console.warn("[Hyprsunset] Niri state probe failed to start")' \
    'Niri state probe must handle spawn failure'

fallback_count="$(grep -Fc -- 'root._finishStateProbe(false)' "$service")"
if (( fallback_count < 2 )); then
    fail "both state probes must settle unknown state on spawn failure"
fi

require 'if (root._pendingEnable)' \
    'state-probe completion must still drain pending enable requests'
require 'root.stateKnown = true' \
    'state-probe completion must mark state as known'
require 'property bool _pendingDisable: false' \
    'night-light service must track pending authoritative disable requests'
require 'property bool _toggleAfterProbe: false' \
    'unknown-state toggles must defer inversion until the first state probe'
require 'property real manualOverrideUntilMs: 0' \
    'manual automatic-mode overrides must track their next schedule boundary'
require 'function _nextScheduleBoundaryMs()' \
    'manual override expiry must be derived from the next configured schedule boundary'
require 'Date.now() >= root.manualOverrideUntilMs' \
    'manual override must expire at the boundary rather than on the next minute tick'
require 'id: backendStopProc' \
    'night-light service must have an authoritative backend stop process'
require '["/usr/bin/pkill", "-TERM", "-x", "wlsunset"]' \
    'Niri OFF requests must disable a legacy/detached wlsunset backend'
require '["/usr/bin/pkill", "-TERM", "-x", "hyprsunset"]' \
    'Hyprland OFF requests must stop a legacy/detached hyprsunset backend'
require 'root._applyManualDesiredState(!root.active)' \
    'unknown-state toggle must invert the probed backend state exactly once'

printf 'night-light service lifecycle guards: ok\n'
