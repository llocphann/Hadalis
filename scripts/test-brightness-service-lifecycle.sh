#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Brightness.qml"

fail() {
    printf 'brightness lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_text_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

backlight_block="$(sed -n '/id: backlightDetectProc/,/id: ddcProc/p' "$service")"
ddc_block="$(sed -n '/id: ddcProc/,/id: setProc/p' "$service")"
[[ -n "$backlight_block" && -n "$ddc_block" ]] || fail 'brightness detection process blocks are missing'

assert_text_contains 'property bool timedOut: false' "$backlight_block" 'backlight probe timeout state is missing'
assert_text_contains 'property bool startObserved: false' "$backlight_block" 'backlight probe startup guard state is missing'
assert_text_contains 'backlightDetectTimeout.stop()' "$backlight_block" 'backlight probe terminal paths must cancel the watchdog'
assert_text_contains 'backlightDetectTimeout.restart()' "$backlight_block" 'backlight probe start must arm the watchdog'
assert_text_contains 'if (backlightDetectProc.timedOut)' "$backlight_block" 'backlight probe timeout must be distinguished from normal exit'
assert_text_contains 'id: backlightDetectTimeout' "$backlight_block" 'backlight probe watchdog timer is missing'
assert_text_contains 'interval: 5000' "$backlight_block" 'backlight probe watchdog interval changed unexpectedly'
assert_text_contains 'if (!backlightDetectProc.running)' "$backlight_block" 'backlight watchdog must ignore an already-stopped process'
assert_text_contains 'backlightDetectProc.timedOut = true' "$backlight_block" 'backlight watchdog does not mark timeout state'
assert_text_contains 'backlightDetectProc.running = false' "$backlight_block" 'backlight watchdog does not terminate a stuck probe'
assert_text_contains 'root.backlightDetectionReady = true' "$backlight_block" 'backlight terminal paths must release detection readiness'
assert_text_contains 'monitor.initialize()' "$backlight_block" 'backlight terminal paths must unblock monitor initialization'

assert_text_contains 'property bool timedOut: false' "$ddc_block" 'DDC timeout state is missing'
assert_text_contains 'property bool startObserved: false' "$ddc_block" 'DDC startup guard state is missing'
assert_text_contains 'ddcTimeout.stop()' "$ddc_block" 'DDC terminal paths must cancel the watchdog'
assert_text_contains 'ddcTimeout.restart()' "$ddc_block" 'DDC watchdog is not armed after process start'
assert_text_contains 'if (ddcProc.timedOut)' "$ddc_block" 'DDC timeout is not distinguished from a normal exit'
assert_text_contains 'else if (exitCode === 0)' "$ddc_block" 'timed-out DDC probes must not replace the last good monitor snapshot'
assert_text_contains 'id: ddcTimeout' "$ddc_block" 'DDC watchdog timer is missing'
assert_text_contains 'interval: 30000' "$ddc_block" 'DDC watchdog interval changed unexpectedly'
assert_text_contains 'if (!ddcProc.running)' "$ddc_block" 'DDC watchdog must ignore an already-stopped process'
assert_text_contains 'ddcProc.timedOut = true' "$ddc_block" 'DDC watchdog does not mark timeout state'
assert_text_contains 'ddcProc.running = false' "$ddc_block" 'DDC watchdog does not terminate a stuck probe'

printf 'brightness service lifecycle guards: ok\n'
