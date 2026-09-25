#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/LyricsService.qml"

fail() {
    printf 'lyrics lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_text_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

finish_block="$(sed -n '/function _finishLyricsProcess/,/onActiveChanged:/p' "$service")"
process_block="$(sed -n '/id: lyricsProc/,/Connections {/p' "$service")"
[[ -n "$finish_block" && -n "$process_block" ]] || fail 'lyrics process lifecycle blocks are missing'

assert_text_contains 'const requestId = root._runningRequestId' "$finish_block" 'shared cleanup must capture the running request before clearing it'
assert_text_contains 'root._runningRequestId = ""' "$finish_block" 'shared cleanup must release the running request id'
assert_text_contains 'root._runningTrackKey = ""' "$finish_block" 'shared cleanup must release the running track key'
assert_text_contains 'if (spawnFailed && requestId !== "")' "$finish_block" 'spawn failure must be distinguished from normal exit'
assert_text_contains 'root._publishFailure(requestId, "error")' "$finish_block" 'spawn failure must publish a terminal error for the active request'
assert_text_contains 'Qt.callLater(root._startPendingRequest)' "$finish_block" 'terminal cleanup must continue with the newest pending request'

assert_text_contains 'property bool startObserved: false' "$process_block" 'lyrics helper startup guard state is missing'
assert_text_contains 'onRunningChanged:' "$process_block" 'lyrics helper must handle a failed spawn'
assert_text_contains 'if (lyricsProc.running)' "$process_block" 'lyrics helper startup guard must reset for each launch attempt'
assert_text_contains 'if (lyricsProc.startObserved)' "$process_block" 'normal process termination must not be mistaken for startup failure'
assert_text_contains 'root._finishLyricsProcess(true)' "$process_block" 'failed spawn must use shared terminal cleanup'
assert_text_contains 'onStarted: lyricsProc.startObserved = true' "$process_block" 'successful startup must be observed explicitly'
assert_text_contains 'onExited: root._finishLyricsProcess(false)' "$process_block" 'normal exit must use shared terminal cleanup'

printf 'lyrics service lifecycle guards: ok\n'
