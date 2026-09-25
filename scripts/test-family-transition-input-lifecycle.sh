#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
overlay="$repo_root/FamilyTransitionOverlay.qml"
shell="$repo_root/shell.qml"
modules="$repo_root/modules/settings/ModulesConfig.qml"
settings_overlay="$repo_root/modules/settings/SettingsOverlay.qml"
settings_focus="$repo_root/modules/settings/SettingsFocus.qml"

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

# Settings must never bypass the shell transition lifecycle. The Material
# overlay is itself a fullscreen input owner, so close it before dispatching
# the family change or the new family can appear under an input-blocking layer.
reject "$modules" 'Config.setNestedValue("panelFamily",' \
    'settings must not write panelFamily directly'
require "$modules" 'GlobalStates.settingsOverlayOpen = false' \
    'settings family switch must release the fullscreen settings input surface'
require "$modules" 'Quickshell.shellPath("scripts/inir"), "panelFamily", "set", target' \
    'settings family switch must use the canonical shell IPC lifecycle'

require "$shell" 'if (GlobalStates.settingsOverlayOpen)' \
    'canonical family switch must close shared Settings overlays for every caller'

require "$shell" 'function _dismissOutgoingFamilyTransientInput(family: string): void' \
    'family switch must own cleanup of outgoing family-local input state'
for waffle_state in searchOpen waffleActionCenterOpen waffleNotificationCenterOpen waffleWidgetsOpen waffleClipboardOpen waffleTaskViewOpen waffleAltSwitcherOpen; do
    require "$shell" "GlobalStates.$waffle_state = false" \
        "Waffle family switch must dismiss $waffle_state before teardown"
done
for ii_state in controlPanelOpen dashboardOpen sidebarLeftOpen sidebarRightOpen mediaControlsOpen clipboardOpen altSwitcherOpen; do
    require "$shell" "GlobalStates.$ii_state = false" \
        "Material family switch must dismiss $ii_state before teardown"
done
require "$shell" 'root._dismissOutgoingFamilyTransientInput(' \
    'canonical family transition must invoke family-local input cleanup'

# Both fullscreen Settings variants may stay mapped during their exit animation,
# but must become pointer-transparent immediately when they stop owning Settings.
for settings_surface in "$settings_overlay" "$settings_focus"; do
    require "$settings_surface" 'readonly property bool acceptsInput: root.settingsOpen' \
        'Settings surface must expose an explicit input-ownership gate'
    require "$settings_surface" 'WlrLayershell.keyboardFocus: settingsPanel.acceptsInput' \
        'Settings keyboard focus must follow the same input-ownership gate'
    require "$settings_surface" 'mask: Region {' \
        'Settings fullscreen surface must define an explicit pointer input mask'
    require "$settings_surface" 'settingsPanel.acceptsInput ?' \
        'Settings pointer mask must collapse when the surface yields input'
done

printf 'family transition input lifecycle guards: ok\n'
