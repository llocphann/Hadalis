#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo_root/services/Translation.qml"

fail() {
    printf 'translation service lifecycle guard failed: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local needle="$1" text="$2" message="$3"
    grep -Fq -- "$needle" <<<"$text" || fail "$message"
}

scanner_block="$(sed -n '/component TranslationScanner: Process {/,/    Timer {/p' "$service")"
generated_block="$(sed -n '/id: scanGeneratedLanguagesProcess/,/^    }/p' "$service")"

[[ -n "$scanner_block" ]] || fail 'TranslationScanner component is missing'
assert_contains 'property var fallbackLanguages: ["en_US"]' "$scanner_block" 'bundled scanner fallback must retain en_US'
assert_contains 'property bool startObserved: false' "$scanner_block" 'scanner startup guard state is missing'
assert_contains 'onRunningChanged:' "$scanner_block" 'scanner startup failure path is missing'
assert_contains 'translationScanner.startObserved = false' "$scanner_block" 'new launch must reset startup observation'
assert_contains 'if (translationScanner.startObserved)' "$scanner_block" 'normal process completion must not be treated as a failed spawn'
assert_contains 'onStarted: translationScanner.startObserved = true' "$scanner_block" 'successful scanner start must be observed'

fallback_count="$(grep -Fc 'translationScanner.languagesScanned([...translationScanner.fallbackLanguages]);' <<<"$scanner_block")"
[[ "$fallback_count" -ge 2 ]] || fail 'failed spawn and nonzero exit must both publish fallback languages'

assert_contains 'fallbackLanguages: []' "$generated_block" 'generated scanner must fail closed to an empty generated catalog list'

printf 'translation scanner lifecycle guards: ok\n'
