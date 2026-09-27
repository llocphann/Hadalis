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
    property bool finished: false
    property string beforePositions: ""
    property string before: ""
    property var originalModule: null
    function check(ok,message): bool {
        if(ok) return true
        console.error("EDITOR_FAIL",message);root.finished=true;return false
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
        interval:200;running:!root.finished;repeat:true
        onTriggered: {
            if(!Config.ready) return
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                GlobalStates.deferredPanelsReady=true
                Config.setNestedValue("abyss.modules.configured",true)
                Config.setNestedValue("abyss.modules.placements",[{id:"clock",kind:"clock",edge:"top",position:.4}])
                Config.setNestedValue("abyss.modules.outputLayouts",[{outputName:"B",placements:[]}])
                root.before=JSON.stringify(Config.options.abyss.modules.placements)
                GlobalStates.abyssEditing=true
            }
            if(root.step===1) {
                root.originalModule=layer.itemForId("clock")
                if(!root.check(root.originalModule!==null,"mature module exists before drag")) return
                editor.move("clock",editor.width*.6,10)
                editor.move("clock",editor.width-10,editor.height/2)
                if(!root.check(layer.itemForId("clock")===root.originalModule,"drag preserves the mature module instance")) return
                if(!root.check(layer.layoutRecords[0].edge==="right","cross edge live placement")) return
                editor.move("clock",editor.width-10,40);editor.change("joinCorner",true)
                if(!root.check(layer.children.find(item=>item.kind==="clock")?.popupJoinedEdge==="top","near-corner draft reaches the actual module popup anchor")) return
                if(!root.check(JSON.stringify(Config.options.abyss.modules.placements)===root.before,"drag writes only draft")) return
                editor.finish(false)
            }
            if(root.step===2) {
                if(!root.check(layer.layoutRecords[0].edge==="top","Cancel restores saved presentation")) return
                if(!root.check(!layer.placements[0].joinCorner,"Cancel restores unchecked corner preference")) return
                GlobalStates.abyssEditing=true
            }
            if(root.step===3) {
                editor.move("clock",editor.width-10,editor.height/2);editor.gap=17
                editor.edgeSizes={top:1.1,right:1.25,bottom:1,left:1}
                editor.change("alignment","center");editor.change("joinCorner",true)
                if(!root.check(editor.selected.joinCorner,"corner option belongs to draft module")) return
                editor.add("media");editor.change("enabled",false)
                editor.finish(true)
            }
            if(root.step===4) {
                const profiles=Array.from(Config.options.abyss.modules.outputLayouts)
                if(!root.check(profiles.length===2 && profiles[0].outputName==="B","Done merges latest output profiles")) return
                if(!root.check(layer.layoutRecords[0].edge==="right" && profiles[1].gap===17 && !profiles[1].placements[1].enabled,"persisted normalized edge, gap and disable")) return
                if(!root.check(profiles[1].edgeSizes.right===1.25 && !profiles[1].placements[0].customSize && profiles[1].placements[0].alignment==="center" && profiles[1].placements[0].joinCorner,"Done persists shared edge sizes and grouped alignment")) return
                GlobalStates.abyssEditing=true
                editor.editingPopups=true
                root.beforePositions=JSON.stringify(Config.options.abyss.positions)
            }
            if(root.step===6) {
                if(!root.check(editor.previewHost.ready && editor.previewHost.contentItem.item.kind==="volume" && !editor.previewHost.contentItem.item.enabled,"actual IPC layout loads with safe preview controls")) return
                editor.movePreview(editor.width-8,editor.height*.3)
                if(!root.check(editor.previewHost.edge==="right" && editor.previewPosition.alignment==="custom" && JSON.stringify(Config.options.abyss.positions)===root.beforePositions,"preview drag updates only an output-local draft")) return
                editor.finish(false)
            }
            if(root.step===7) {
                if(!root.check(JSON.stringify(Config.options.abyss.positions)===root.beforePositions && editor.previewHost.inputBounds.width===0,"Cancel discards positions and releases preview input")) return
                GlobalStates.abyssEditing=true;editor.editingPopups=true
                editor.movePreview(editor.width*.25,8)
                Config.setNestedValue("abyss.positions",[{kind:"clock",outputName:"B",edge:"left",alignment:"end"}])
                editor.finish(true)
            }
            if(root.step===9) {
                const positions=Array.from(Config.options.abyss.positions)
                if(!root.check(positions.length===2 && positions.some(p=>p.kind==="clock" && p.outputName==="B" && p.edge==="left") && positions.some(p=>p.kind==="volume" && p.outputName==="A" && p.edge==="top" && p.alignment==="custom"),"Done merges position edits into latest config without overwriting another output")) return
                console.info("EDITOR_PASS");root.finished=true
            }
            root.step++
        }
    }
}
QML
status=0
dbus-run-session -- env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland \
 XDG_CONFIG_HOME="$abyss_editor_test/config" XDG_STATE_HOME="$abyss_editor_test/state" XDG_CACHE_HOME="$abyss_editor_test/cache" \
 timeout 20s qs -p "$abyss_editor_test" --no-color > "$abyss_editor_test/runtime.log" 2>&1 || status=$?
if [[ "$status" != 124 ]] || ! rg -q EDITOR_PASS "$abyss_editor_test/runtime.log" || rg -q 'EDITOR_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$abyss_editor_test/runtime.log";then cat "$abyss_editor_test/runtime.log";exit 1;fi
printf 'PASS: live module identity and placement, popup/IPC preview drag drafts, Cancel, latest-config merge and output isolation\n'
