#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]];then printf 'SKIP: app hover menus (Quickshell/Wayland unavailable)\n';exit 0;fi
menu_test_root="$(mktemp -d)"
trap 'rm -rf -- "$menu_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations;do ln -s "$repo_root/$entry" "$menu_test_root/$entry";done
mkdir -p "$menu_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$menu_test_root/config/illogical-impulse/config.json"
cat > "$menu_test_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.dock
import qs.modules.bar
ShellRoot {
    id:root;property int step:0;property bool finished:false
    function check(ok,message): bool { if(ok)return true;console.error("APP_HOVER_FAIL",message);finished=true;return false }
    QtObject {
        id:owner
        signal closeAllContextMenus()
        property bool contextMenuOpen:false
        property bool dragActive:false
        property bool buttonHovered:false
        property var lastHoveredButton:null
        property var toplevelsByUniqueId:({})
    }
    FloatingWindow {
        visible:true;implicitWidth:800;implicitHeight:600
        DockAppButton { id:dock;x:220;y:400;width:50;height:50;appListRoot:owner;appToplevel:({appId:"org.quickshell",originalAppId:"org.quickshell",uniqueId:"qa",toplevels:[]}) }
        BarTaskbarButton { id:bar;x:340;y:80;width:50;height:40;taskbarRoot:owner;appEntry:({appId:"org.quickshell",originalAppId:"org.quickshell",toplevels:[]}) }
    }
    Timer {
        interval:180;running:!root.finished;repeat:true
        onTriggered: {
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                Config.setNestedValue("performance.reduceAnimations",true)
                Config.setNestedValue("dock.hoverPreview",false)
                Config.setNestedValue("dock.hoverPreviewDelay",240)
                dock.buttonHovered=true
            } else if(root.step===3) {
                if(!root.check(owner.contextMenuOpen && GlobalStates.activeContextMenu?.model?.length>0,"hover opens mature Dock actions for an app without windows")) return
                dock.buttonHovered=false
            } else if(root.step===8) {
                if(!root.check(!owner.contextMenuOpen && GlobalStates.activeContextMenuCount===0,"Dock menu closes after its hover handoff grace")) return
                bar.buttonHovered=true
            } else if(root.step===11) {
                if(!root.check(owner.contextMenuOpen && GlobalStates.activeContextMenu?.model?.length>0,"hover opens mature taskbar actions")) return
                bar.buttonHovered=false
                owner.closeAllContextMenus()
                Config.setNestedValue("panelFamily","waffle")
                dock.buttonHovered=true
            } else if(root.step===14) {
                if(!root.check(!owner.contextMenuOpen && GlobalStates.activeContextMenuCount===0,"Waffle keeps its prior hover contract")) return
                console.info("APP_HOVER_PASS");root.finished=true
            }
            root.step++
        }
    }
}
QML
status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$menu_test_root/config" XDG_STATE_HOME="$menu_test_root/state" XDG_CACHE_HOME="$menu_test_root/cache" timeout 12s qs -p "$menu_test_root" --no-color > "$menu_test_root/runtime.log" 2>&1 || status=$?
if [[ "$status" != 124 ]] || ! rg -q APP_HOVER_PASS "$menu_test_root/runtime.log" || rg -q 'APP_HOVER_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|Cannot anchor|is not a type' "$menu_test_root/runtime.log";then cat "$menu_test_root/runtime.log";exit 1;fi
printf 'PASS: Dock/taskbar hover exposes actionable app menus, pointer-exit grace closes them, Waffle stays unchanged\n'
