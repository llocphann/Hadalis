#!/usr/bin/env bash
# Exercise editor draft/cancel/save against actual QML Config and placement bindings.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then printf 'SKIP: Abyss editor (Quickshell unavailable)\n'; exit 0; fi
abyss_editor_test="$(mktemp -d)"
trap 'rm -rf -- "$abyss_editor_test"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do ln -s "$repo_root/$entry" "$abyss_editor_test/$entry"; done
mkdir -p "$abyss_editor_test/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$abyss_editor_test/config/illogical-impulse/config.json"
cat > "$abyss_editor_test/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
import qs.modules.abyss.bar
ShellRoot {
    id: root
    property int step: 0
    property string before: ""
    function check(ok,message): bool {
        if(ok) return true
        console.error("EDITOR_FAIL",message);Qt.quit();return false
    }
    AbyssSurfaceController { id: liquid }
    FloatingWindow {
        visible: true;implicitWidth:1000;implicitHeight:700
        AbyssBar {
            id: layer;anchors.fill:parent;outputName:"A";edge:"top"
            editing: editor.visible;draftPlacements: editor.visible?editor.draft:null
            draftOptions: editor.visible?editor.draftOptions:null
        }
        AbyssEdgeEditor {
            id: editor;anchors.fill:parent;outputName:"A";moduleLayer:layer;controller:liquid
            visible: GlobalStates.abyssEditing
        }
    }
    Timer {
        interval:200;running:true;repeat:true
        onTriggered: {
            if(root.step===0) {
                Config.setNestedValue("abyss.modules.configured",true)
                Config.setNestedValue("abyss.modules.placements",[{id:"clock",kind:"clock",edge:"top",position:.4}])
                Config.setNestedValue("abyss.modules.outputLayouts",[{outputName:"B",placements:[]}])
                root.before=JSON.stringify(Config.options.abyss.modules.placements)
                GlobalStates.abyssEditing=true
            }
            if(root.step===1) {
                editor.move("clock",editor.width*.6,10)
                editor.move("clock",editor.width-10,editor.height/2)
                if(!root.check(layer.layoutRecords[0].edge==="right","cross edge live placement")) return
                if(!root.check(JSON.stringify(Config.options.abyss.modules.placements)===root.before,"drag writes only draft")) return
                editor.finish(false)
            }
            if(root.step===2) {
                if(!root.check(layer.layoutRecords[0].edge==="top","Cancel restores saved presentation")) return
                GlobalStates.abyssEditing=true
            }
            if(root.step===3) {
                editor.move("clock",editor.width-10,editor.height/2);editor.gap=17
                editor.add("media");editor.change("enabled",false)
                editor.finish(true)
            }
            if(root.step===4) {
                const profiles=Array.from(Config.options.abyss.modules.outputLayouts)
                if(!root.check(profiles.length===2 && profiles[0].outputName==="B","Done merges latest output profiles")) return
                if(!root.check(layer.layoutRecords[0].edge==="right" && profiles[1].gap===17 && !profiles[1].placements[1].enabled,"persisted normalized edge, gap and disable")) return
                console.info("EDITOR_PASS");Qt.quit()
            }
            root.step++
        }
    }
}
QML
if ! dbus-run-session -- env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland \
 XDG_CONFIG_HOME="$abyss_editor_test/config" XDG_STATE_HOME="$abyss_editor_test/state" XDG_CACHE_HOME="$abyss_editor_test/cache" \
 timeout 8s qs -p "$abyss_editor_test" --no-color > "$abyss_editor_test/runtime.log" 2>&1; then cat "$abyss_editor_test/runtime.log";exit 1; fi
if ! rg -q EDITOR_PASS "$abyss_editor_test/runtime.log" || rg -q 'EDITOR_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type|Type .* unavailable' "$abyss_editor_test/runtime.log"; then cat "$abyss_editor_test/runtime.log";exit 1; fi
printf 'PASS: live editor draft, cross-edge projection, Cancel and per-output persistence\n'
