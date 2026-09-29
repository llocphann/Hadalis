#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]];then printf 'SKIP: Elastic Fill runtime (Quickshell/Wayland unavailable)\n';exit 0;fi
test_root="$(mktemp -d)";trap 'rm -rf -- "$test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations;do ln -s "$repo_root/$entry" "$test_root/$entry";done
mkdir -p "$test_root/config/illogical-impulse";cp "$repo_root/defaults/config.json" "$test_root/config/illogical-impulse/config.json"
cat >"$test_root/Card.qml"<<'QML'
import QtQuick
Item { property var participant: null }
QML
cat >"$test_root/shell.qml"<<'QML'
//@ pragma ShellId hadalis-abyss-elastic-fill-runtime-test
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
 id:root;property int step:0;property bool notesOpen:false;property bool sidebarOpen:false;property bool notesHover:false;property bool sidebarHover:false;property real expandedSidebarSpan:0;property real expandedNotesDepth:0
 function closeEnough(a,b):bool{return Math.abs(Number(a)-Number(b))<0.75}
 function sameRect(a,b):bool{return closeEnough(a.x,b.x)&&closeEnough(a.y,b.y)&&closeEnough(a.width,b.width)&&closeEnough(a.height,b.height)}
 function check(ok,message):bool{if(ok)return true;console.error("ELASTIC_FILL_RUNTIME_FAIL",message);Qt.quit();return false}
 AbyssSurfaceController{id:controller;outputWidth:viewport.width;outputHeight:viewport.height;edgeInsets:({left:16,right:16,top:16,bottom:16})}
 FloatingWindow{visible:true;implicitWidth:1200;implicitHeight:900
  Item{id:viewport;width:1200;height:900
   AbyssBodyHost{id:notes;anchors.fill:parent;controller:controller;identity:"elasticNotes";edge:"bottom";stackPolicy:"pyramid";elasticFillGroup:"quickNotesSidebar";elasticFillAnchor:true;elasticFillHovered:root.notesHover;open:root.notesOpen;animatePresentation:false;span:420;depth:300;along:-203;padding:14;edgeInsets:controller.edgeInsets;source:Qt.resolvedUrl("Card.qml")}
   AbyssBodyHost{id:sidebar;anchors.fill:parent;controller:controller;identity:"elasticSidebar";edge:"left";elasticFillGroup:"quickNotesSidebar";elasticFillHovered:root.sidebarHover;open:root.sidebarOpen;animatePresentation:false;span:630;depth:460;along:135;padding:20;edgeInsets:controller.edgeInsets;source:Qt.resolvedUrl("Card.qml")}
  }
 }
 Timer{interval:120;running:true;repeat:true;onTriggered:{
  if(!Config.ready)return
  if(root.step===0){Config.setNestedValue("panelFamily","abyss");GlobalStates.deferredPanelsReady=true;root.notesOpen=true}
  else if(root.step===2)root.sidebarOpen=true
  else if(root.step===5){if(!check(notes.placement?.visible&&sidebar.placement?.visible,"pair coexist"))return;if(!check(notes.placement.inward===0&&sidebar.placement.inward>0,"base order"))return;root.sidebarHover=true}
  else if(root.step===8){if(!check(sidebar.placement?.elasticFilled===true&&sidebar.placement?.elasticDirection==="bottom","sidebar fill"))return;if(!check(sameRect(sidebar.record.content,sidebar.placement.content),"sidebar exact"))return;root.expandedSidebarSpan=sidebar.visualPlacement.span;root.sidebarHover=false}
  else if(root.step===9){if(!check(sidebar.placement?.elasticFilled!==true&&sidebar.visualPlacement?.elasticLimits===true,"sidebar tail"))return;if(!check(sidebar.visualPlacement.span>sidebar.placement.span+0.5&&sidebar.visualPlacement.span<root.expandedSidebarSpan-0.5,"sidebar continuous"))return}
  else if(root.step===12){if(!check(sidebar.visualPlacement?.elasticLimits!==true&&sameRect(sidebar.record.content,sidebar.placement.content),"sidebar settle"))return;root.notesHover=true}
  else if(root.step===15){if(!check(notes.placement?.elasticFilled===true&&notes.placement?.elasticDirection==="top","notes fill"))return;if(!check(sameRect(notes.record.content,notes.placement.content),"notes exact"))return;root.expandedNotesDepth=notes.visualPlacement.depth;root.notesHover=false}
  else if(root.step===16){if(!check(notes.placement?.elasticFilled!==true&&notes.visualPlacement?.elasticLimits===true,"notes tail"))return;if(!check(notes.visualPlacement.depth>notes.placement.depth+0.5&&notes.visualPlacement.depth<root.expandedNotesDepth-0.5,"notes continuous"))return}
  else if(root.step===19){if(!check(notes.visualPlacement?.elasticLimits!==true&&sameRect(notes.record.content,notes.placement.content),"notes settle"))return;console.info("ELASTIC_FILL_RUNTIME_PASS");Qt.quit()}
  root.step++
 }}
}
QML
status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" XDG_CACHE_HOME="$test_root/cache" timeout 12s qs -p "$test_root" --no-color >"$test_root/runtime.log" 2>&1||status=$?
if [[ "$status" != 0 ]]||! rg -q ELASTIC_FILL_RUNTIME_PASS "$test_root/runtime.log"||rg -q 'ELASTIC_FILL_RUNTIME_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log";then cat "$test_root/runtime.log";exit 1;fi
printf 'PASS: Elastic Fill open-order coexistence and span/depth return tails\n'
