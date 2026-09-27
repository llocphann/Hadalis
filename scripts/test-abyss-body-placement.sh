#!/usr/bin/env bash
# Real host lifecycle: tiers, deferred content, hiding, input release and restore.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]];then printf 'SKIP: body placement (Quickshell/Wayland unavailable)\n';exit 0;fi
placement_test_root="$(mktemp -d)"
trap 'rm -rf -- "$placement_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations;do ln -s "$repo_root/$entry" "$placement_test_root/$entry";done
mkdir -p "$placement_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$placement_test_root/config/illogical-impulse/config.json"
cat > "$placement_test_root/Card.qml" <<'QML'
import QtQuick
Item { property var participant:null;property string draft:"unsaved note" }
QML
cat > "$placement_test_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
    id:root;property int step:0;property bool finished:false;property var retained:null;property var allocation:null
    function check(ok,message): bool { if(ok)return true;console.error("BODY_PLACEMENT_FAIL",message);finished=true;return false }
    AbyssSurfaceController { id:controller;outputWidth:win.width;outputHeight:win.height;edgeInsets:({left:16,right:16,top:16,bottom:16}) }
    FloatingWindow {
        id:win;visible:true;implicitWidth:1100;implicitHeight:800
        AbyssBodyHost {
            id:older;anchors.fill:parent;controller:controller;edge:"bottom";identity:"older"
            animatePresentation:false;largeSurface:true;span:900;depth:260;along:100
            edgeInsets:controller.edgeInsets;source:Qt.resolvedUrl("Card.qml")
        }
        AbyssBodyHost {
            id:newer;anchors.fill:parent;controller:controller;edge:"bottom";identity:"newer"
            animatePresentation:false;largeSurface:true;span:420;depth:200;along:340
            edgeInsets:controller.edgeInsets;source:Qt.resolvedUrl("Card.qml")
        }
    }
    Timer {
        interval:200;running:!root.finished;repeat:true
        onTriggered: {
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                Config.setNestedValue("performance.reduceAnimations",true)
                GlobalStates.deferredPanelsReady=true;older.open=true
            } else if(root.step===2) {
                root.retained=older.contentItem.item
                if(!root.check(older.ready && older.presented,"first real host loads")) return
                root.retained.draft="keep this draft";newer.open=true
            } else if(root.step===4) {
                if(!root.check(older.presented && newer.presented && older.inputBounds.y+older.inputBounds.height<newer.inputBounds.y,"same-place contents step inward without overlap")) return
                if(!root.check(older.contentParent.width===older.requestedRecord.content.width && older.contentParent.height===older.requestedRecord.content.height,"stacking retains readable dimensions")) return
                root.allocation=controller.bodyPlacements;newer.progress=.4
                if(!root.check(root.allocation===controller.bodyPlacements,"reveal frames do not repack peers")) return
                newer.progress=1;older.depth=win.height*.9
            } else if(root.step===6) {
                if(!root.check(!older.presented && newer.presented && older.inputBounds.width===0 && !older.contentParent.visible && !older.contentItem.enabled,"no room hides the older body and releases paint/input")) return
                if(!root.check(older.contentItem.item===root.retained && root.retained.draft==="keep this draft" && older.contentParent.width>800,"hidden state and useful content geometry survive")) return
                newer.open=false
            } else if(root.step===8) {
                if(!root.check(older.presented && older.inputBounds.width>0 && older.contentItem.item===root.retained,"closing newer restores older body without losing drafts")) return
                older.open=false
            } else if(root.step===10) {
                if(!root.check(!older.ready && controller.inputBounds.length===0,"semantic close unloads retained content and clears input")) return
                console.info("BODY_PLACEMENT_PASS");root.finished=true
            }
            root.step++
        }
    }
}
QML
status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$placement_test_root/config" XDG_STATE_HOME="$placement_test_root/state" XDG_CACHE_HOME="$placement_test_root/cache" timeout 15s qs -p "$placement_test_root" --no-color > "$placement_test_root/runtime.log" 2>&1 || status=$?
if [[ "$status" != 124 ]] || ! rg -q BODY_PLACEMENT_PASS "$placement_test_root/runtime.log" || rg -q 'BODY_PLACEMENT_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$placement_test_root/runtime.log";then cat "$placement_test_root/runtime.log";exit 1;fi
printf 'PASS: real body tiers, unchanged reveal allocation, constrained hide/input release, retained draft restoration and close unload\n'
