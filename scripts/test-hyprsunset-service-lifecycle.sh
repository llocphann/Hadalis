#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Hyprsunset.qml"

fail() {
    printf 'hyprsunset lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_text_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

hypr_block="$(sed -n '/id: fetchProc/,/\/\/ === Niri processes/p' "$service")"
niri_block="$(sed -n '/id: niriFetchProc/,/function toggle/p' "$service")"
[[ -n "$hypr_block" && -n "$niri_block" ]] || fail 'night-light state probe blocks are missing'

assert_text_contains 'property bool startObserved: false' "$hypr_block" 'Hyprland state probe startup guard is missing'
assert_text_contains 'property bool timedOut: false' "$hypr_block" 'Hyprland state probe timeout state is missing'
assert_text_contains 'hyprStateProbeTimeout.restart()' "$hypr_block" 'Hyprland state probe must arm its watchdog after start'
assert_text_contains 'hyprStateProbeTimeout.stop()' "$hypr_block" 'Hyprland state probe terminal paths must cancel the watchdog'
assert_text_contains 'if (fetchProc.timedOut)' "$hypr_block" 'Hyprland timeout must be distinguished from a normal exit'
assert_text_contains 'root._finishStateProbe(!fetchProc.timedOut' "$hypr_block" 'timed-out Hyprland probes must fail closed'
assert_text_contains 'id: hyprStateProbeTimeout' "$hypr_block" 'Hyprland state probe watchdog timer is missing'
assert_text_contains 'interval: 5000' "$hypr_block" 'Hyprland state probe watchdog interval changed unexpectedly'
assert_text_contains 'if (!fetchProc.running)' "$hypr_block" 'Hyprland watchdog must ignore an already-stopped process'
assert_text_contains 'fetchProc.timedOut = true' "$hypr_block" 'Hyprland watchdog does not mark timeout state'
assert_text_contains 'fetchProc.running = false' "$hypr_block" 'Hyprland watchdog does not terminate a stuck probe'

assert_text_contains 'property bool startObserved: false' "$niri_block" 'Niri state probe startup guard is missing'
assert_text_contains 'property bool timedOut: false' "$niri_block" 'Niri state probe timeout state is missing'
assert_text_contains 'niriStateProbeTimeout.restart()' "$niri_block" 'Niri state probe must arm its watchdog after start'
assert_text_contains 'niriStateProbeTimeout.stop()' "$niri_block" 'Niri state probe terminal paths must cancel the watchdog'
assert_text_contains 'if (niriFetchProc.timedOut)' "$niri_block" 'Niri timeout must be distinguished from a normal exit'
assert_text_contains 'root._finishStateProbe(!niriFetchProc.timedOut && exitCode === 0)' "$niri_block" 'timed-out Niri probes must fail closed'
assert_text_contains 'id: niriStateProbeTimeout' "$niri_block" 'Niri state probe watchdog timer is missing'
assert_text_contains 'interval: 5000' "$niri_block" 'Niri state probe watchdog interval changed unexpectedly'
assert_text_contains 'if (!niriFetchProc.running)' "$niri_block" 'Niri watchdog must ignore an already-stopped process'
assert_text_contains 'niriFetchProc.timedOut = true' "$niri_block" 'Niri watchdog does not mark timeout state'
assert_text_contains 'niriFetchProc.running = false' "$niri_block" 'Niri watchdog does not terminate a stuck probe'

assert_text_contains 'hyprStateProbeTimeout.stop()' "$(sed -n '/Component.onDestruction:/,$p' "$service")" 'Hyprland watchdog must stop during destruction'
assert_text_contains 'niriStateProbeTimeout.stop()' "$(sed -n '/Component.onDestruction:/,$p' "$service")" 'Niri watchdog must stop during destruction'

printf 'hyprsunset service lifecycle guards: ok\n'
