#!/usr/bin/env bash
# Render production wave texture and field; prove finite motion and rest.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss wave rendering (Quickshell/display unavailable)\n'
    exit 0
fi
wave_test_root="$(mktemp -d)"
trap 'rm -rf -- "$wave_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$wave_test_root/$entry"
done
mkdir -p "$wave_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$wave_test_root/config/illogical-impulse/config.json"
cat > "$wave_test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-wave-runtime-test
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.abyss
import qs.modules.abyss.looks
ShellRoot {
    id: root
    property int step: 0
    property int restingRevision: -1
    property int captured: 0
    QtObject {
        id: audio
        property var points:[100,80,95,65,90,75,100,80]
        property real normalizationCeiling:100
        property bool audioSignalActive:false
    }
    function check(value,message): bool {
        if(value) return true
        console.error("WAVE_RUNTIME_FAIL",message);Qt.quit();return false
    }
    function capture(name): void {
        scene.grabToImage(result => { result.saveToFile(Quickshell.env("ABYSS_WAVE_OUTPUT")+"/"+name+".png");root.captured++ })
    }
    FloatingWindow {
        visible: true; implicitWidth: 420; implicitHeight: 260; color: "#071218"
        Item {
            id: scene; anchors.fill: parent
            AbyssField { id: field; anchors.fill: parent; waveTexture: waves.texture }
            AbyssWaveController { id: waves; outputWidth: scene.width; outputHeight: scene.height }
            AbyssSpectrumController { id:spectrum;waves:waves;audioSource:audio;playing:false;presented:waves.presented }
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if(root.step === 0) { Config.setNestedValue("abyss.quality","performance");Config.setNestedValue("abyss.waves.enabled",true) }
            if(root.step === 4) {
                if(!root.check(field.ready && waves.mode === "SLEEPING" && !waves.running,"ready and sleeping before input")) return
                root.restingRevision = waves.revision;root.capture("rest")
            }
            if(root.step === 6) {
                if(!root.check(waves.revision===root.restingRevision,"no idle texture updates")) return
                waves.impulse("top",210,100,1)
                if(!root.check(waves.running && waves.mode==="ACTIVE","interaction wakes solver")) return
            }
            if(root.step === 7) {
                if(!root.check(waves.simulation.displacement.some(v=>v>.1),"physical displacement")) return
                root.capture("moving")
            }
            if(root.step === 9) Config.setNestedValue("performance.reduceAnimations",true)
            if(root.step === 11) {
                if(!root.check(!waves.running && waves.mode==="SLEEPING" && waves.simulation.displacement.every(v=>v===0),"reduced motion clears simulation")) return
                root.restingRevision=waves.revision;root.capture("reduced")
            }
            if(root.step === 13) {
                if(!root.check(waves.revision===root.restingRevision,"reduced motion has no high-rate updates")) return
                Config.setNestedValue("performance.reduceAnimations",false)
                waves.impulse("left",100,60,1)
                waves.presented=false
                if(!root.check(!waves.running && waves.mode==="SLEEPING","hidden/fullscreen output cancels transient motion")) return
            }
            if(root.step === 15) {
                if(!root.check(root.captured===3,"all actual GPU captures completed")) return
                Config.setNestedValue("abyss.waves.enabled",false)
                Config.setNestedValue("abyss.spectrum.configured",true)
                Config.setNestedValue("abyss.spectrum.enabled",true)
                Config.setNestedValue("abyss.spectrum.strength",1)
                waves.presented=true;audio.audioSignalActive=true;spectrum.playing=true
            }
            if(root.step === 17) {
                if(!root.check(waves.audioAllowed && !waves.motionAllowed && waves.simulation.hasSpectrum && waves.simulation.displacement.some(v=>Math.abs(v)>.1),"audio drives field while interaction waves stay off")) return
                if(!root.check(!spectrum.held,"injected audio does not acquire an analyzer lease")) return
                root.capture("audio")
            }
            if(root.step === 19) {
                audio.audioSignalActive=false
                if(!root.check(!waves.simulation.hasSpectrum,"silence releases audio targets")) return
                spectrum.playing=false
            }
            if(root.step === 21) {
                if(!root.check(!spectrum.wanted && !waves.running && waves.simulation.displacement.every(v=>v===0),"paused playback restores flat field and stops updates")) return
                root.capture("paused")
                audio.audioSignalActive=true;spectrum.playing=true
            }
            if(root.step === 23) {
                Config.setNestedValue("performance.reduceAnimations",true)
                if(!root.check(!spectrum.wanted && !waves.running && waves.mode==="SLEEPING","reduced motion disables spectrum")) return
                root.capture("audioReduced")
            }
            if(root.step === 25) {
                if(!root.check(root.captured===6,"interaction and audio GPU captures completed")) return
                Config.setNestedValue("performance.reduceAnimations",false)
                waves.presented=false
                if(!root.check(!spectrum.wanted && !waves.running && waves.simulation.displacement.every(v=>v===0),"hidden output releases spectrum and restores rest")) return
                console.info("WAVE_RUNTIME_PASS");Qt.quit()
            }
            root.step++
        }
    }
}
QML
if ! env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=offscreen \
    QSG_RHI_BACKEND=opengl QT_QUICK_BACKEND=rhi ABYSS_WAVE_OUTPUT="$wave_test_root" \
    XDG_CONFIG_HOME="$wave_test_root/config" XDG_STATE_HOME="$wave_test_root/state" \
    XDG_CACHE_HOME="$wave_test_root/cache" timeout 8s qs -p "$wave_test_root" --no-color \
    > "$wave_test_root/runtime.log" 2>&1; then
    cat "$wave_test_root/runtime.log"; exit 1
fi
if ! rg -q 'WAVE_RUNTIME_PASS' "$wave_test_root/runtime.log" || rg -q 'WAVE_RUNTIME_FAIL|ReferenceError:|TypeError:|Binding loop|shader preparation failed' "$wave_test_root/runtime.log"; then
    cat "$wave_test_root/runtime.log"; exit 1
fi
python3 - "$wave_test_root" <<'PY'
from PIL import Image,ImageChops
from pathlib import Path
import sys
root=Path(sys.argv[1])
rest=Image.open(root/'rest.png').convert('RGB')
moving=Image.open(root/'moving.png').convert('RGB')
reduced=Image.open(root/'reduced.png').convert('RGB')
assert ImageChops.difference(rest,moving).crop((0,4,420,80)).getbbox(), 'solver must visibly change the actual field silhouette'
assert ImageChops.difference(rest,reduced).getbbox() is None, 'resting silhouette must restore after reduced motion'
assert ImageChops.difference(rest,Image.open(root/'audio.png').convert('RGB')).crop((0,4,420,80)).getbbox(), 'spectrum must move the actual field, without a second spectrum painter'
assert ImageChops.difference(rest,Image.open(root/'paused.png').convert('RGB')).getbbox() is None, 'paused audio restores the exact resting field'
assert ImageChops.difference(rest,Image.open(root/'audioReduced.png').convert('RGB')).getbbox() is None, 'reduced motion cancels audio deformation'
print('PASS: production GPU wave texture deforms silhouette, restores rest and stops idle/reduced/hidden updates')
PY
