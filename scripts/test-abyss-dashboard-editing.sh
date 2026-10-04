#!/usr/bin/env bash
# Exercise shared widget resize/hide/restore through both Abyss Dashboard hosts.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]];then printf 'SKIP: Abyss Dashboard editing (Quickshell/Wayland unavailable)\n';exit 0;fi
dashboard_test_root="$(mktemp -d)"
trap 'rm -rf -- "$dashboard_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations;do ln -s "$repo_root/$entry" "$dashboard_test_root/$entry";done
mkdir -p "$dashboard_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$dashboard_test_root/config/illogical-impulse/config.json"
cat > "$dashboard_test_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
    id: root
    property bool finished: false
    property int step: 0
    property int hostIndex: 0
    property var canvas: null
    property var toolbar: null
    property var before: null
    property var canvasIdentity: null
    function check(ok,message): bool {
        if(ok) return true
        console.error("DASHBOARD_EDIT_FAIL",hostIndex,message);root.finished=true;return false
    }
    function find(item,predicate) {
        if(!item) return null
        if(predicate(item)) return item
        for(const child of item.children ?? []) { const found=find(child,predicate);if(found) return found }
        return null
    }
    FloatingWindow {
        visible:true;implicitWidth:1100;implicitHeight:800
        AbyssBodyHost {
            id: body;anchors.fill:parent;edge:"bottom";open:true;animatePresentation:false
            span:1060;depth:730;padding:20;largeSurface:true;stableContentSize:true
        }
    }
    Timer {
        interval:120;running:!root.finished;repeat:true
        onTriggered: {
            if(!Config.ready) return
            if(root.step===0) {
                Config.setNestedValue("performance.reduceAnimations",true)
                GlobalStates.deferredPanelsReady=true;GlobalStates.overviewOpen=true
                body.source=Qt.resolvedUrl("modules/abyss/content/"+(root.hostIndex===0 ? "AbyssDashboardContent" : "AbyssOverviewContent")+".qml")
            }
            else if(root.step===3) {
                root.canvas=root.find(body.contentItem.item,item=>typeof item.beginResize==="function")
                if(!root.check(root.canvas!==null,"mature canvas loaded")) return
                if(!root.check(!root.canvas._layoutHasOverlap(root.canvas._snapshotVisibleRects()),"default minimum-size cards project without overlap")) return
                if(!root.check(root.canvas.workspace.width===root.canvas.width && root.canvas.workspace.height===root.canvas.height,"workspace stays bounded by Dashboard dimensions")) return
                const fixedSize=[root.canvas.width,root.canvas.height]
                body.progress=.15
                if(!root.check(root.canvas.width===fixedSize[0] && root.canvas.height===fixedSize[1],"reveal clips the fixed-size canvas instead of repacking it")) return
                body.progress=1
                const entries=root.canvas.defaultEntries().map(p=>Object.assign({},p,{visible:p.id==="notes",x:.15,y:.15,w:.3,h:.35}))
                Config.setNestedValue("dashboard.canvas.widgets",entries)
                Config.setNestedValue("dashboard.canvas.snap",false)
                root.canvas.editMode=true;root.canvas.selectedId="notes"
                root.canvasIdentity=root.canvas
            }
            else if(root.step===5) {
                root.toolbar=root.find(body.contentItem.item,item=>item.canvasController===root.canvas && item.editing!==undefined)
                if(!root.check(root.toolbar!==null && root.toolbar.visible && root.toolbar.width>200 && root.toolbar.height>20,"editing toolbar has usable dimensions")) return
                const p=root.toolbar.mapToItem(body.contentItem,0,0)
                if(!root.check(p.x>=0 && p.y>=0 && p.x+root.toolbar.width<=body.contentItem.width+.5 && p.y+root.toolbar.height<=body.contentItem.height+.5,"toolbar stays inside field content/input clip: "+JSON.stringify([p.x,p.y,root.toolbar.width,root.toolbar.height,body.contentItem.width,body.contentItem.height]))) return
                root.before=root.canvas._rectPixels("notes")
                const end={x:root.before.x+root.before.width,y:root.before.y+root.before.height}
                root.canvas.beginResize("notes","se",end)
                root.canvas.updateInteraction({x:end.x+90,y:end.y+60})
                const preview=root.canvas._rectPixels("notes")
                if(!root.check(preview.width>root.before.width+60 && preview.height>root.before.height+30,"module resize previews larger usable dimensions")) return
                root.canvas.finishInteraction(true)
            }
            else if(root.step===7) {
                const saved=root.canvas._rectPixels("notes")
                if(!root.check(saved.width>root.before.width+60 && saved.height>root.before.height+30 && root.canvas===root.canvasIdentity,"module resize persists without replacing canvas")) return
                root.canvas.setWidgetVisible("notes",false)
            }
            else if(root.step===9) {
                if(!root.check(root.canvas.visibleIds.length===0 && root.canvas.hiddenIds.includes("notes") && root.toolbar.visible && root.toolbar.width>200,"empty Dashboard retains available-module controls")) return
                root.canvas.setWidgetVisible("notes",true)
            }
            else if(root.step===11) {
                if(!root.check(root.canvas.visibleIds.includes("notes") && root.canvas.geometryFor("notes").visible,"hidden module restores through same controller")) return
                const packed=root.canvas.defaultEntries().map(p=>Object.assign({},p,{visible:p.id==="notes",x:0,y:0,w:1,h:1}))
                root.canvas.commitEditMode()
                Config.setNestedValue("dashboard.canvas.widgets",packed)
                root.canvas.beginEditMode()
            }
            else if(root.step===13) {
                const before=JSON.stringify(Config.options.dashboard.canvas.widgets)
                root.canvas.setWidgetVisible("system",true)
                if(!root.check(root.canvas.visibleIds.length===1 && root.canvas.layoutMessage.length>0 && JSON.stringify(Config.options.dashboard.canvas.widgets)===before,"packed Add reports no room without changing any saved card")) return
                root.canvas.setWidgetVisible("notes",false)
                root.canvas.setWidgetVisible("system",true)
            }
            else if(root.step===15) {
                if(!root.check(root.canvas.visibleIds.includes("system") && !root.canvas.layoutMessage,"Add succeeds when space becomes available")) return
                root.canvas.editMode=false
                if(root.hostIndex===0) { root.hostIndex=1;root.step=0;return }
                console.info("DASHBOARD_EDIT_PASS");root.finished=true;return
            }
            root.step++
        }
    }
}
QML
runtime_status=0
dbus-run-session -- env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST \
 QT_QPA_PLATFORM=wayland \
 XDG_CONFIG_HOME="$dashboard_test_root/config" XDG_STATE_HOME="$dashboard_test_root/state" XDG_CACHE_HOME="$dashboard_test_root/cache" \
 timeout 20s qs -p "$dashboard_test_root" --no-color > "$dashboard_test_root/runtime.log" 2>&1 || runtime_status=$?
# The harness stays alive after its assertions; timeout owns its termination.
# An early crash/exit is a failure even if a success marker was emitted.
if [[ "$runtime_status" != 124 ]]; then cat "$dashboard_test_root/runtime.log";exit 1;fi
if ! rg -q DASHBOARD_EDIT_PASS "$dashboard_test_root/runtime.log" || rg -q 'DASHBOARD_EDIT_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type|Type .* unavailable' "$dashboard_test_root/runtime.log";then cat "$dashboard_test_root/runtime.log";exit 1;fi
printf 'PASS: both Abyss Dashboard hosts keep resize persistence and empty-layout restore controls inside content/input bounds\n'
