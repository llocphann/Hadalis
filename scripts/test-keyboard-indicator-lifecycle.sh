#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/KeyboardIndicators.qml"

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

printf 'keyboard indicator lifecycle guards: ok\n'
