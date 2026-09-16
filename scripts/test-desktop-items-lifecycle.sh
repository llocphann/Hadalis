#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/DesktopItems.qml"

fail() {
    printf 'desktop items lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

ensure_block="$(sed -n '/id: ensureStateDir/,/property int _idCounter/p' "$service")"
[[ -n "$ensure_block" ]] || fail 'state-directory helper process block is missing'

assert_contains 'property bool startObserved: false' "$ensure_block" 'state-directory helper must track whether startup succeeded'
assert_contains 'onRunningChanged:' "$ensure_block" 'state-directory helper startup failure path is missing'
assert_contains 'root._stateDirPending = false' "$ensure_block" 'startup failure must release the pending-directory gate'
assert_contains 'root.ready = true' "$ensure_block" 'startup failure must leave initialization in a terminal state'
assert_contains 'root.available = false' "$ensure_block" 'startup failure must fail closed instead of exposing writable state'
assert_contains 'process failed to start' "$ensure_block" 'startup failure must report a distinct bounded error'
assert_contains 'onStarted: ensureStateDir.startObserved = true' "$ensure_block" 'state-directory helper must distinguish successful startup from failed spawn'

# The normal exit path must retain the same gate release so both spawn failure
# and non-zero mkdir exit converge without leaving DesktopItems permanently pending.
pending_release_count="$(grep -Fc 'root._stateDirPending = false' <<<"$ensure_block")"
[[ "$pending_release_count" -ge 2 ]] || fail 'both startup-failure and normal-exit paths must release the pending-directory gate'

printf 'desktop items state-directory lifecycle guards: ok\n'
