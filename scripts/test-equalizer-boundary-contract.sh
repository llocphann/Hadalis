#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$root/services/deferred/EqualizerService.qml"
qmldir="$root/services/deferred/qmldir"
shell_root="$root/shell.qml"
media_popup="$root/modules/mediaControls/BarMediaPopup.qml"
equalizer_panel="$root/modules/mediaControls/EqualizerPanel.qml"
media_controls_root="$root/modules/mediaControls"

fail() {
    printf 'FAIL: equalizer boundary contract: %s\n' "$1" >&2
    exit 1
}

for file in "$service" "$qmldir" "$shell_root" "$media_popup" "$equalizer_panel"; do
    [[ -f "$file" ]] || fail "missing ${file#"$root/"}"
done
[[ -d "$media_controls_root" ]] || fail 'missing modules/mediaControls'

grep -Fxq 'singleton EqualizerService 1.0 EqualizerService.qml' "$qmldir"     || fail 'EqualizerService is not exported from deferred services'
grep -Fq 'property bool enabled: false' "$service"     || fail 'equalizer capability is no longer idle/disabled without consumers'

for token in     'readonly property var dspFrequencies:'     'readonly property var dspPresetCurves:'     'function registerConsumer('     'function unregisterConsumer('     'function setDspBandGain('     'function applyDspPreset('; do
    grep -Fq "$token" "$service" || fail "DSP service contract missing $token"
done

if grep -Fq 'EqualizerService' "$shell_root"; then
    fail 'shell root eagerly references EqualizerService'
fi

grep -Fq 'EqualizerPanel {' "$media_popup"     || fail 'Bar Media Popup does not host the DSP panel'
grep -Fq 'EqualizerService.registerConsumer()' "$equalizer_panel"     || fail 'DSP panel does not acquire the optional service on presentation'
grep -Fq 'EqualizerService.unregisterConsumer()' "$equalizer_panel"     || fail 'DSP panel does not release the optional service on teardown'
grep -Fq 'model: ["Flat", "Bass", "Treble", "Vocal",' "$equalizer_panel"     || fail 'Serpantinum DSP preset row is missing'
grep -Fq 'model: EqualizerService.dspBands' "$equalizer_panel"     || fail 'DSP panel is not driven by the service 10-band facade'

for token in \
    'property real eqLightningHighlight: 0.0' \
    'visible: true' \
    'interval: 33' \
    'running: root.active && lightningCanvas.visible' \
    'ctx.lineWidth = 5.5' \
    'ctx.lineWidth = 2.4' \
    'ctx.lineWidth = 1.0' \
    'function beginBandLightning(' \
    'function previewBandLightning(' \
    'function endBandLightning(' \
    'root.previewBandLightning(' \
    'root.applyPresetWithLightning(modelData)' \
    'property real eqPresetSweepProgress: -0.12' \
    'function triggerPresetSweep()' \
    'id: presetSweepAnim' \
    'property: "eqPresetSweepProgress"' \
    'from: -0.12' \
    'to: 1.16' \
    'duration: Appearance.animationsEnabled ? 860 : 1' \
    'const sweepTail = 0.22' \
    'const sweepLead = 0.035' \
    'id: bandRepeater' \
    'function lightningPoint()' \
    'handleItem.mapToItem(' \
    'bandRepeater.itemAt(i)' \
    'cursorShape: bandSlider.enabled' \
    'Qt.SizeVerCursor' \
    'Qt.ClosedHandCursor'; do
    grep -Fq "$token" "$equalizer_panel" \
        || fail "persistent DSP electricity contract missing $token"
done

for retired in \
    'eqLightningProgress' \
    'eqLightningFade' \
    'lightningPulse' \
    'ctx.lineWidth = 14' \
    'ctx.lineWidth = 7' \
    'ctx.lineWidth = 3.5' \
    'root.triggerEqLightning()\n        }\n    }\n\n    SequentialAnimation {\n        id: presetSweepAnim'; do
    if grep -Fq "$retired" "$equalizer_panel"; then
        fail "oversized/transient DSP lightning token returned: $retired"
    fi
done

# Presentation consumes only the facade. Backend/process/socket protocol remains
# service-owned, so Media Controls cannot grow a second Equalizer implementation.
backend_pattern='EasyEffects\\.|socat|EasyEffectsServer|equalizer-control\\.sh|load_preset:output:|set_property:output:equalizer|get_property:output:equalizer'
while IFS= read -r -d '' file; do
    if grep -Eq "$backend_pattern" "$file"; then
        fail "${file#"$root/"} references the equalizer backend/protocol directly"
    fi
done < <(find "$media_controls_root" -type f -name '*.qml' -print0)

printf 'PASS: Media DSP stays behind the EqualizerService boundary\n'
