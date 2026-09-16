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
    local block
    block="$(sed -n "/id: ${process_id}$/,/^    }/p" "$service")"
    [[ -n "$block" ]] || fail "$process_id process block is missing"
    grep -Fq "${process_id}.startObserved = true" <<<"$block" \
        || fail "${process_id} must record successful startup"
    grep -Fq "${process_id}.startTimeout.restart()" <<<"$block" \
        || fail "${process_id} must restart its startup timeout after spawn"
}

require 'id: fetchProc' 'Hyprland state probe is missing'
require_started_block 'fetchProc'
require 'console.warn("[Hyprsunset] Hyprland state probe failed to start")' \
    'Hyprland state probe must handle spawn failure'
require 'id: niriFetchProc' 'Niri state probe is missing'
require_started_block 'niriFetchProc'
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

printf 'night-light service lifecycle guards: ok\n'
