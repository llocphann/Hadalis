#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/MaterialThemeLoader.qml"

fail() {
    printf 'material theme lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _finishGenerator(name: string, code: int, immediateReload: bool, spawnFailed: bool): void' \
    'generator exits and startup failures must share recovery'
require 'else if (code === 0)' \
    'force-apply must remain gated on confirmed successful generation'
require 'root.scheduleReload()' \
    'failed generators must preserve reload safety-net behavior'
require 'delayedExternalApply.restart()' \
    'failed generators must preserve external-apply recovery behavior'

require 'root._finishGenerator("scheme variant", -1, true, true)' \
    'scheme variant startup failure must enter shared recovery'
require 'root._finishGenerator("dark mode", -1, false, true)' \
    'dark-mode startup failure must enter shared recovery'
require 'root._finishGenerator("color invert", -1, false, true)' \
    'color-invert startup failure must enter shared recovery'
require 'root._finishGenerator("scheme variant", code, true, false)' \
    'scheme variant normal exit must use shared recovery'
require 'root._finishGenerator("dark mode", code, false, false)' \
    'dark-mode normal exit must use shared recovery'
require 'root._finishGenerator("color invert", code, false, false)' \
    'color-invert normal exit must use shared recovery'

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 3 )); then
    fail "expected startup guards on all three material generators, found $start_guard_count"
fi

printf 'material theme loader lifecycle guards: ok\n'
