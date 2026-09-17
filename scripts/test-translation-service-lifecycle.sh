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

assert_not_contains() {
    local needle="$1" text="$2" message="$3"
    if grep -Fq -- "$needle" <<<"$text"; then
        fail "$message"
    fi
}

service_text="$(cat "$service")"

assert_contains 'readonly property var availableLanguages: ["en_US"]' "$service_text" \
    'runtime must expose only canonical en_US'
assert_contains 'readonly property string languageCode: "en_US"' "$service_text" \
    'runtime languageCode must remain canonical en_US'
assert_contains 'path: `${Quickshell.shellPath("translations")}/en_US.json`' "$service_text" \
    'runtime must load the canonical en_US catalog directly'
assert_contains 'property bool isLoading: translationFileView.loadPending' "$service_text" \
    'runtime must preserve translation load state'
assert_contains 'root.translations?.[key] ?? key' "$service_text" \
    'missing English entries must continue to fall back to source strings'

for retired in \
    'TranslationScanner' \
    'scanGeneratedLanguagesProcess' \
    'availableGeneratedLanguages' \
    'allAvailableLanguages' \
    'isScanning' \
    'Process {'; do
    assert_not_contains "$retired" "$service_text" \
        "English-only runtime must not retain multilingual scanner machinery: $retired"
done

printf 'translation English-only lifecycle guards: ok\n'
