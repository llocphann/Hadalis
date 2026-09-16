#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$root/services/deferred/EqualizerService.qml"
qmldir="$root/services/deferred/qmldir"
shell_root="$root/shell.qml"
media_module="$root/modules/perimeter/MediaModule.qml"
media_surface="$root/modules/perimeter/MediaConnectedSurface.qml"
media_popup="$root/modules/mediaControls/BarMediaPopup.qml"

fail() {
    printf 'FAIL: equalizer boundary contract: %s\n' "$1" >&2
    exit 1
}

for file in "$service" "$qmldir" "$shell_root" "$media_module" "$media_surface" "$media_popup"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done

grep -Fxq 'singleton EqualizerService 1.0 EqualizerService.qml' "$qmldir" \
    || fail 'EqualizerService is not exported from deferred services'
grep -Fq 'property bool enabled: false' "$service" \
    || fail 'equalizer capability is no longer disabled by default'

for token in \
    'readonly property string backendName:' \
    'readonly property bool backendAvailable:' \
    'readonly property bool available:' \
    'property string error:' \
    'property list<string> presets:' \
    'property string activePreset:' \
    'property var bands:' \
    'function applyPreset(' \
    'function setBandGain(' \
    'function reset(' \
    'function refresh('; do
    grep -Fq "$token" "$service" || fail "service contract missing $token"
done

grep -Fq 'target: root.enabled ? EasyEffects : null' "$service" \
    || fail 'disabled equalizer still subscribes to EasyEffects lifecycle'
grep -Fq 'root._cancelProcesses()' "$service" \
    || fail 'disabled equalizer cannot cancel backend processes'

# Phase 1 must remain opt-in and detached from shell startup.
if grep -Fq 'EqualizerService' "$shell_root"; then
    fail 'shell root eagerly references EqualizerService'
fi

# Presentation may consume EqualizerService in the future, but backend execution
# belongs to the service layer. Connected Media must not grow direct EasyEffects
# or subprocess control paths.
for file in "$media_module" "$media_surface" "$media_popup"; do
    if grep -Eq 'EasyEffects|socat|Quickshell\.execDetached|(^|[^A-Za-z])Process[[:space:]]*\{' "$file"; then
        fail "${file#"$root/"} bypasses the equalizer service boundary"
    fi
done

printf 'PASS: equalizer architecture boundary\n'
