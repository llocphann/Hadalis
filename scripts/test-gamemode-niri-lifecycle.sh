#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/GameMode.qml"

fail() {
    printf 'gamemode niri lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _finishNiriAnimationMutation(code: int, spawnFailed: bool): void' \
    'niri animation mutation must share one completion path'
require 'id: niriAnimProcess' 'niri animation process is missing'
require 'property bool startObserved: false' \
    'niri animation process must track successful startup'
require 'onStarted: niriAnimProcess.startObserved = true' \
    'niri animation process must mark successful startup'
require 'root._finishNiriAnimationMutation(-1, true)' \
    'niri animation spawn failure must execute cleanup'
require 'onExited: (code, status) => root._finishNiriAnimationMutation(code, false)' \
    'normal niri animation exit must use the same cleanup path'
require 'suppressClearTimer.restart()' \
    'niri animation cleanup must always release toast suppression'
require 'niriAnimProcess.rerunAfterExit = false' \
    'niri animation cleanup must drain queued reruns'

printf 'gamemode niri lifecycle guards: ok\n'
