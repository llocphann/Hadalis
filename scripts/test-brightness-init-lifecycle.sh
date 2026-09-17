#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Brightness.qml"

fail() {
    printf 'brightness init lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _finishInitialization(): void' \
    'monitor initialization must share a failure cleanup path'
require 'readonly property Process initProc: Process {' \
    'per-monitor initialization process is missing'
require 'property bool startObserved: false' \
    'brightness processes must track successful startup'
require 'property bool timedOut: false' \
    'brightness initialization must track watchdog expiry'
require 'console.warn("[Brightness] Failed to start monitor brightness initialization")' \
    'monitor initialization spawn failure must be explicit'
require 'initTimeout.restart()' \
    'monitor initialization must arm its watchdog after startup'
require 'property var initTimeout: Timer {' \
    'monitor initialization watchdog is missing'
require 'interval: 30000' \
    'monitor initialization watchdog interval changed unexpectedly'
require 'initProc.timedOut = true' \
    'watchdog must mark timed-out monitor initialization'
require 'initProc.running = false' \
    'watchdog must terminate timed-out monitor initialization'
require 'monitor._finishInitialization()' \
    'spawn/exit cleanup must release monitor ready state'

printf 'brightness monitor initialization lifecycle guards: ok\n'
