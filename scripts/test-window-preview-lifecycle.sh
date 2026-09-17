#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/WindowPreviewService.qml"
capture_script="$repo_root/scripts/capture-windows.sh"

fail() {
    printf 'window preview lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require_capture() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$capture_script" || fail "$message"
}

require 'console.warn("[WindowPreviewService] preview directory helper failed to start")' \
    'preview directory startup failure must continue initialization'
require 'console.warn("[WindowPreviewService] session marker reader failed to start")' \
    'session marker startup failure must recover'
require 'console.warn("[WindowPreviewService] session reset helper failed to start")' \
    'session reset startup failure must release session readiness'
require 'console.warn("[WindowPreviewService] preview cache scan failed to start")' \
    'cache scan startup failure must release session readiness'
require 'console.warn("[WindowPreviewService] capture process failed to start")' \
    'capture startup failure must be explicit'
require 'onStarted: captureProcess.startObserved = true' \
    'capture process must record successful startup'
require 'root.capturing = false' \
    'capture startup/exit cleanup must release the capture gate'
require 'Cliphist.suppressRefresh = false' \
    'capture startup/exit cleanup must release clipboard refresh suppression'
require 'root.captureComplete()' \
    'capture failure must notify consumers that the cycle ended'
require 'root._resumeRequestedCapture()' \
    'initialization failures must resume deferred capture requests'

require_capture 'capture_timeout_seconds="${INIR_WINDOW_PREVIEW_CAPTURE_TIMEOUT_SECONDS:-90}"' \
    'window preview capture must have a finite default lifetime'
require_capture 'INIR_CAPTURE_WINDOWS_TIMEOUT_ACTIVE' \
    'window preview timeout wrapper must guard against recursive re-entry'
require_capture 'exec "$timeout_bin" --signal=TERM --kill-after=5s "${capture_timeout_seconds}s" "$0" "$@"' \
    'window preview capture must execute under the timeout supervisor'

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 5 )); then
    fail "expected startup guards for init and capture processes, found $start_guard_count"
fi

printf 'window preview lifecycle guards: ok\n'
