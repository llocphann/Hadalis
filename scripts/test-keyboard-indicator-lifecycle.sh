#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/KeyboardIndicators.qml"
bar_indicator="$repo_root/modules/bar/KeyboardStatusIndicator.qml"
bar_status="$repo_root/modules/bar/BarStatusIndicators.qml"
bar_qmldir="$repo_root/modules/bar/qmldir"

fail() {
    printf 'keyboard indicator lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'id: evdevProbeProc' 'evdev capability probe is missing'
require 'onStarted: evdevProbeProc.startObserved = true' \
    'evdev probe must record successful startup'
require 'root._log("evdev probe failed to start")' \
    'evdev probe spawn failure must be handled'
require 'root._enableSysfsFallback();' \
    'evdev probe failure must retain the sysfs fallback path'

require 'id: evdevMonitorProc' 'evdev monitor is missing'
require 'onStarted: evdevMonitorProc.startObserved = true' \
    'evdev monitor must record successful startup'
require 'root._log("evdev monitor failed to start")' \
    'evdev monitor spawn failure must be handled'
require 'evdevRestartTimer.restart();' \
    'confirmed evdev mode must retry monitor startup instead of becoming inert'
require 'if (evdevProbeProc.startObserved || root._destroying)' \
    'probe startup guard must not run during destruction'
require 'if (evdevMonitorProc.startObserved || root._destroying)' \
    'monitor startup guard must not run during destruction'
require 'interval: (Config.options?.performance?.lowPower ?? false) ? 120000 : 30000' \
    'sysfs LED path rediscovery must remain low cadence'
require 'watchChanges: true' \
    'known LED paths must use file watching instead of fast rediscovery polling'

grep -Fq 'KeyboardIndicators.hasPanelIndicators' "$bar_indicator" \
    || fail 'Bar keyboard indicator must consume KeyboardIndicators'
grep -Fq 'KeyboardStatusIndicator {' "$bar_status" \
    || fail 'Bar status surface must use the Niri-backed keyboard indicator'
grep -Fq 'KeyboardStatusIndicator 1.0 KeyboardStatusIndicator.qml' "$bar_qmldir" \
    || fail 'Bar keyboard indicator must be exported through qmldir'
if grep -Fq 'HyprlandXkbIndicator' "$bar_status"; then
    fail 'retired HyprlandXkbIndicator reference remains in Bar status surface'
fi

printf 'keyboard indicator lifecycle guards: ok\n'
