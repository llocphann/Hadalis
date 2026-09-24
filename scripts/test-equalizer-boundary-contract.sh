#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
service="$root/services/deferred/EqualizerService.qml"
qmldir="$root/services/deferred/qmldir"
shell_root="$root/shell.qml"
media_popup="$root/modules/mediaControls/BarMediaPopup.qml"
dashboard_media="$root/modules/dashboard/DashMedia.qml"
equalizer_panel="$root/modules/mediaControls/EqualizerPanel.qml"
media_controls_root="$root/modules/mediaControls"

fail() {
    printf 'FAIL: equalizer boundary contract: %s\n' "$1" >&2
    exit 1
}

for file in "$service" "$qmldir" "$shell_root" "$media_popup" "$dashboard_media" "$equalizer_panel"; do
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
grep -Fq 'import qs.modules.mediaControls' "$dashboard_media" || fail 'Dashboard Media does not import the shared media controls module'
grep -Fq 'EqualizerPanel {' "$dashboard_media" || fail 'Dashboard Media does not host the shared DSP panel'
grep -Fq 'property bool presentationActive:' "$dashboard_media" || fail 'Dashboard Media does not expose presentation lifecycle'
grep -Fq 'active: root.presentationActive && root.visible' "$dashboard_media" || fail 'Dashboard DSP lifecycle is not presentation-gated'
grep -Fq 'EqualizerService.registerConsumer()' "$equalizer_panel"     || fail 'DSP panel does not acquire the optional service on presentation'
grep -Fq 'EqualizerService.unregisterConsumer()' "$equalizer_panel"     || fail 'DSP panel does not release the optional service on teardown'
grep -Fq 'model: ["Flat", "Bass", "Treble", "Vocal",' "$equalizer_panel"     || fail 'Serpantinum DSP preset row is missing'
grep -Fq 'model: EqualizerService.dspBands' "$equalizer_panel"     || fail 'DSP panel is not driven by the service 10-band facade'

for token in \
    'readonly property int presetStripHeight:' \
    'Presets read as a compact mode strip' \
    'Layout.preferredHeight: root.presetStripHeight' \
    'colBackground: "transparent"' \
    'buttonRadius: height / 2'; do
    grep -Fq "$token" "$equalizer_panel" \
        || fail "compact DSP preset strip contract missing $token"
done

if grep -Fq 'columns: 4' "$equalizer_panel"; then
    fail 'DSP presets regressed to the old two-row button grid'
fi

for token in \
    'CavaProcess {' \
    'id: eqCava' \
    'active: root.active' \
    'sampleCount: 64' \
    'id: analyzerCanvas' \
    'const spectrum = eqCava.points ?? []' \
    'Number(eqCava.normalizationCeiling)' \
    'property real eqLightningHighlight: 0.0' \
    'property real eqPresetSweepProgress: -0.12' \
    'function triggerEqLightning(): void' \
    'function triggerPresetSweep(): void' \
    'function beginBandLightning(index, gain): void' \
    'function previewBandLightning(index, gain): void' \
    'function endBandLightning(index, gain): void' \
    'id: presetSweepAnim' \
    'id: eqLightningAnim' \
    'const sweepTail = 0.22' \
    'const sweepLead = 0.035' \
    'ctx.lineWidth = 5.5' \
    'ctx.lineWidth = 2.4' \
    'ctx.lineWidth = 1.0' \
    'id: bandRepeater' \
    'function curvePoint()' \
    'handleItem.mapToItem(' \
    'EqualizerService.setDspBandGain(' \
    'cursorShape: bandSlider.enabled' \
    'Qt.SizeVerCursor' \
    'root.applyPreset(modelData)' \
    'RowLayout {' \
    'Layout.alignment: Qt.AlignVCenter'; do
    grep -Fq "$token" "$equalizer_panel" \
        || fail "integrated electric CAVA/DSP graph contract missing $token"
done

for retired in \
    'id: lightningCanvas' \
    'ctx.bezierCurveTo('; do
    if grep -Fq "$retired" "$equalizer_panel"; then
        fail "retired detached/smooth DSP connector token returned: $retired"
    fi
done

slider_declarations="$(grep -Fc 'Slider {' "$equalizer_panel")"
[[ "$slider_declarations" -eq 1 ]] \
    || fail "DSP panel must expose one integrated graph Slider declaration, found $slider_declarations"

# Presentation consumes only the facade. Backend/process/socket protocol remains
# service-owned, so Media Controls cannot grow a second Equalizer implementation.
backend_pattern='EasyEffects\\.|socat|EasyEffectsServer|equalizer-control\\.sh|load_preset:output:|set_property:output:equalizer|get_property:output:equalizer'
while IFS= read -r -d '' file; do
    if grep -Eq "$backend_pattern" "$file"; then
        fail "${file#"$root/"} references the equalizer backend/protocol directly"
    fi
done < <(find "$media_controls_root" -type f -name '*.qml' -print0)

printf 'PASS: Bar and Dashboard Media DSP stay behind the EqualizerService boundary\n'
