#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/AwwwBackend.qml"

fail() {
    printf 'awww lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local needle="$1"
    local message="$2"
    grep -Fq -- "$needle" "$service" || fail "$message"
}

require 'function _finishApply(exitCode: int, spawnFailed: bool): void' \
    'apply exit and startup-failure paths must share cleanup'
require 'root.lastError = "awww apply failed to start"' \
    'apply startup failure must be surfaced'
require 'applyProc._pendingSignature = ""' \
    'apply cleanup must release the pending signature'
require 'root._queuedStopAfterApply = false' \
    'apply cleanup must release queued stop state'
require 'applyProc.running = true' \
    'queued apply requests must remain restartable'

require 'console.warn("[AwwwBackend] capability probe failed to start")' \
    'probe startup failure must be explicit'
require 'root.probing = false' \
    'probe startup failure must release probing state'
require 'root._finishApply(-1, true)' \
    'apply startup failure must enter shared cleanup'
require 'root._finishPreview(true)' \
    'preview startup failure must enter shared cleanup'
require 'root.previewActive = false' \
    'failed preview startup must not leave a fake active preview'
require 'root._finishStop(true)' \
    'stop startup failure must enter shared cleanup'
require 'root.stoppedForNoOutputs = true' \
    'stop cleanup must release no-output stop state'
require 'root._drainPreviewQueue()' \
    'preview queue must be drainable after process cleanup'

start_guard_count="$(grep -Fc -- 'property bool startObserved: false' "$service")"
if (( start_guard_count < 4 )); then
    fail "expected startup guards on probe/apply/preview/stop, found $start_guard_count"
fi

printf 'awww backend lifecycle guards: ok\n'
