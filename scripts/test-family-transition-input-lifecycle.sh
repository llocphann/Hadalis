#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
overlay="$repo_root/FamilyTransitionOverlay.qml"
shell="$repo_root/shell.qml"

fail() {
    printf 'family transition input lifecycle guard failed: %s\n' "$1" >&2
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

# The transition is decorative. It must never own keyboard or pointer input,
# because family/config reloads can outlive the animation signal wiring.
require "$overlay" 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' \
    'family transition overlay must not request exclusive keyboard focus'
reject "$overlay" 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive' \
    'family transition overlay must never trap keyboard focus'
require "$overlay" 'Item { id: emptyTransitionInput; width: 0; height: 0 }' \
    'family transition overlay needs an explicit zero-sized input item'
require "$overlay" 'mask: Region { item: emptyTransitionInput }' \
    'family transition overlay must be pointer click-through'
require "$overlay" 'active: root._active' \
    'native transition surface lifetime must follow local presentation state'
require "$overlay" 'visible: root._active' \
    'native transition surface must unmap as soon as presentation ends'

# The watchdog must be self-sufficient: signal connections can disappear while
# the family tree/config reloads, so input release cannot depend on the parent.
require "$overlay" 'GlobalStates.familyTransitionActive = false' \
    'watchdog fail-open path must clear the singleton transition state itself'
require "$shell" 'if (_transitionInProgress && !GlobalStates.familyTransitionActive)' \
    'shell must retain stale local transition recovery'

printf 'family transition input lifecycle guards: ok\n'
