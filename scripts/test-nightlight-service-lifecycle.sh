#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/NightLight.qml"

fail() {
    printf 'night-light lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'id: stateProbeProc' 'wlsunset state probe is missing'
require 'property bool startObserved: false' 'state probe startup guard is missing'
require 'property bool timedOut: false' 'state probe timeout state is missing'
require 'stateProbeTimeout.restart()' 'state probe must arm its watchdog after start'
require 'stateProbeTimeout.stop()' 'state probe terminal paths must cancel the watchdog'
require 'root._finishStateProbe(!stateProbeProc.timedOut && exitCode === 0)' \
    'timed-out probes must fail closed'
require 'id: stateProbeTimeout' 'state probe watchdog timer is missing'
require 'interval: 5000' 'state probe watchdog interval changed unexpectedly'
require 'stateProbeProc.timedOut = true' 'watchdog must mark timeout state'
require 'stateProbeProc.running = false' 'watchdog must terminate a stuck probe'
require 'if (root._pendingEnable)' \
    'state-probe completion must drain pending enable requests'
require 'root.stateKnown = true' \
    'state-probe completion must mark state as known'
require 'property bool _pendingDisable: false' \
    'night-light service must track pending authoritative disable requests'
require 'property bool _toggleAfterProbe: false' \
    'unknown-state toggles must defer inversion until the first state probe'
require 'property real manualOverrideUntilMs: 0' \
    'manual automatic-mode overrides must track the next schedule boundary'
require 'function _nextScheduleBoundaryMs()' \
    'manual override expiry must be derived from the configured schedule'
require 'Date.now() >= root.manualOverrideUntilMs' \
    'manual override must expire at the boundary'
require 'id: backendStopProc' \
    'night-light service must have an authoritative backend stop process'
require '["/usr/bin/pkill", "-TERM", "-x", "wlsunset"]' \
    'OFF requests must disable a detached wlsunset backend'
require 'root._applyManualDesiredState(!root.active)' \
    'unknown-state toggle must invert the probed backend state exactly once'
require 'function load(): void {' \
    'deferred shell initialization must explicitly initialize night-light state'
require 'root.reEvaluate()' \
    'night-light load path must evaluate the configured schedule'

if grep -Eqi -- 'hyprland|hyprsunset|hyprctl' "$service"; then
    fail 'Niri-only night-light service must not contain Hyprland backend residue'
fi

printf 'night-light service lifecycle guards: ok\n'
