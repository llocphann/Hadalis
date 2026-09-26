#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/VoiceSearch.qml"

fail() {
    printf 'voice search lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

probe_block="$(sed -n '/id: localProbe/,/id: recordProc/p' "$service")"
record_block="$(sed -n '/id: recordProc/,/id: transcribeProc/p' "$service")"
transcribe_block="$(sed -n '/id: transcribeProc/,/IpcHandler {/p' "$service")"

[[ -n "$probe_block" ]] || fail 'local backend probe block is missing'
[[ -n "$record_block" ]] || fail 'voice recorder block is missing'
[[ -n "$transcribe_block" ]] || fail 'transcription block is missing'

assert_contains 'property bool startObserved: false' "$probe_block" 'local probe startup guard state is missing'
assert_contains 'onRunningChanged:' "$probe_block" 'local probe startup failure path is missing'
assert_contains 'root.localAvailable = false' "$probe_block" 'failed local probe must invalidate stale availability'
assert_contains 'root.detectedLocalExecutable = ""' "$probe_block" 'failed local probe must clear stale executable'
assert_contains 'root.detectedLocalModel = ""' "$probe_block" 'failed local probe must clear stale model'
assert_contains 'root._drainProbeQueue()' "$probe_block" 'failed local probe must drain a queued refresh'
assert_contains 'onStarted: localProbe.startObserved = true' "$probe_block" 'local probe must distinguish a successful start'
assert_contains 'root._tryStartPending()' "$probe_block" 'local probe completion must resume a pending first-use start'

assert_contains 'property bool initialized: false' "$(cat "$service")" 'voice search must begin uninitialized so backend probing stays off the boot path'
assert_contains 'function ensureInitialized(): void' "$(cat "$service")" 'voice search must expose an explicit lazy initialization entry point'
assert_contains 'root.initialized = true' "$(cat "$service")" 'backend refresh must mark voice search initialized'
assert_contains 'root.ensureInitialized()' "$(cat "$service")" 'voice search start must initialize backends on first use'
assert_contains 'function _tryStartPending(): void' "$(cat "$service")" 'first-use recording must wait for backend/keyring readiness'
if grep -Fq 'Component.onCompleted: root.refreshBackends()' "$service"; then
    fail 'voice search must not probe backends eagerly during singleton construction'
fi

assert_contains 'property bool startObserved: false' "$record_block" 'recorder startup guard state is missing'
assert_contains 'onRunningChanged:' "$record_block" 'recorder startup failure path is missing'
assert_contains 'if (root._cancelRequested)' "$record_block" 'recorder startup recovery must preserve cancellation semantics'
assert_contains 'root._notifyError(Translation.tr("Recording failed"))' "$record_block" 'recorder failed start must surface an error'
assert_contains 'onStarted: recordProc.startObserved = true' "$record_block" 'recorder must distinguish a successful start'

assert_contains 'property bool startObserved: false' "$transcribe_block" 'transcriber startup guard state is missing'
assert_contains 'onRunningChanged:' "$transcribe_block" 'transcriber startup failure path is missing'
assert_contains 'root._transcriptionOutput = ""' "$transcribe_block" 'transcriber failed start must clear stale stdout'
assert_contains 'root._transcriptionError = ""' "$transcribe_block" 'transcriber failed start must clear stale stderr'
assert_contains 'if (root._cancelRequested)' "$transcribe_block" 'transcriber startup recovery must preserve cancellation semantics'
assert_contains 'root._notifyError(Translation.tr("Transcription failed"))' "$transcribe_block" 'transcriber failed start must surface an error'
assert_contains 'onStarted: transcribeProc.startObserved = true' "$transcribe_block" 'transcriber must distinguish a successful start'

start_guard_count="$(grep -Fc 'property bool startObserved: false' "$service")"
[[ "$start_guard_count" -ge 3 ]] || fail 'all three voice helper processes must retain startup guards'

printf 'voice search helper lifecycle guards: ok\n'
