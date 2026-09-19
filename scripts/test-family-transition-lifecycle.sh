#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
overlay="$repo_root/FamilyTransitionOverlay.qml"
shell="$repo_root/shell.qml"

fail() {
    printf 'family transition lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

require() {
    local file="$1" needle="$2" message="$3"
    grep -Fq -- "$needle" "$file" || fail "$message"
}

reject() {
    local file="$1" needle="$2" message="$3"
    if grep -Fq -- "$needle" "$file"; then
        fail "$message"
    fi
}

require "$overlay" 'Component.onCompleted: if (GlobalStates.familyTransitionActive) root._beginTransition()' \
    'reloaded overlay must re-arm an in-flight family transition'
require "$overlay" 'id: watchdog' \
    'family transition must retain a watchdog'
require "$overlay" 'GlobalStates.familyTransitionActive = false' \
    'overlay must directly release the singleton transition flag'
require "$overlay" 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' \
    'visual transition must never take keyboard focus'
require "$overlay" 'mask: Region { item: emptyTransitionInput }' \
    'visual transition must remain pointer-click-through'
require "$overlay" 'active: root._active' \
    'native transition window must follow local presentation state rather than a stale singleton flag'
require "$overlay" 'visible: root._active' \
    'native transition window must unmap as soon as local presentation ends'
reject "$overlay" 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive' \
    'family transition must not restore exclusive input ownership'
require "$shell" 'if (_transitionInProgress && !GlobalStates.familyTransitionActive)' \
    'shell must recover stale local transition state'

printf 'family transition lifecycle guards: ok\n'
