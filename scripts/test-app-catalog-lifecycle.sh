#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/AppCatalog.qml"

fail() {
    printf 'app catalog lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

detect_block="$(sed -n '/id: _detectPmProc/,/function _refreshInstalled/p' "$service")"
installed_block="$(sed -n '/id: _installedProc/,/\/\/ ─── Install \/ Remove/p' "$service")"

[[ -n "$detect_block" ]] || fail 'package manager detection process block is missing'
[[ -n "$installed_block" ]] || fail 'installed package process block is missing'

assert_contains 'property bool startObserved: false' "$detect_block" 'package manager detection startup guard state is missing'
assert_contains 'onRunningChanged:' "$detect_block" 'package manager detection startup failure path is missing'
assert_contains 'root._detectedPm = "unknown"' "$detect_block" 'failed package manager detection must fail closed'
assert_contains 'root._flatpakAvailable = false' "$detect_block" 'failed package manager detection must clear flatpak capability'
assert_contains 'root._aurHelperAvailable = false' "$detect_block" 'failed package manager detection must clear AUR helper capability'
assert_contains 'root._detectedAurHelper = ""' "$detect_block" 'failed package manager detection must clear stale AUR helper'
assert_contains 'onStarted: _detectPmProc.startObserved = true' "$detect_block" 'package manager detection must distinguish a successful start'

assert_contains 'property bool startObserved: false' "$installed_block" 'installed package check startup guard state is missing'
assert_contains 'onRunningChanged:' "$installed_block" 'installed package check startup failure path is missing'
assert_contains 'root._installedRaw = ""' "$installed_block" 'failed installed package check must clear partial output'
assert_contains 'root.checkingInstalled = false' "$installed_block" 'failed installed package check must release checking state'
assert_contains 'onStarted: _installedProc.startObserved = true' "$installed_block" 'installed package check must distinguish a successful start'

start_guard_count="$(grep -Fc 'property bool startObserved: false' "$service")"
[[ "$start_guard_count" -ge 2 ]] || fail 'both package helper processes must retain startup guards'

printf 'app catalog helper lifecycle guards: ok\n'
