#!/usr/bin/env bash
# Lay out the real popup in a rendered Qt window through content-kind changes.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss popup layout (Quickshell unavailable)\n'
    exit 0
fi
popup_test_root="$(mktemp -d)"
trap 'rm -rf -- "$popup_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$popup_test_root/$entry"
done
mkdir -p "$popup_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$popup_test_root/config/illogical-impulse/config.json"
cat > "$popup_test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-styled-popup-test
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.bar
import qs.modules.abyss
ShellRoot {
    id: root
    property int step: 0
    function check(value,message): bool {
        if(value) return true
        console.error("ABYSS_STYLED_POPUP_FAIL",message);Qt.quit();return false
    }
    AbyssSurfaceController { id: first; presentationItem: scene; popupHost: body; outputWidth:scene.width;outputHeight:scene.height }
    AbyssSurfaceController { id: second; presentationItem: scene; popupHost: body; outputWidth:scene.width;outputHeight:scene.height }
    FloatingWindow {
        id: window
        visible:true;implicitWidth:1200;implicitHeight:900
        Item {
            id: scene;anchors.fill:parent
            MouseArea {
                id: anchor
                x:900;y:100;width:32;height:80
                property var liquidController: first
                property string attachedEdge: "right"
            }
            AbyssBodyHost {
                id: body;anchors.fill:parent;identity:"styledPopup";edge:popup._attachmentEdge
                controller: anchor.liquidController
                open: popup.presentationActive && popup.requestedVisible
                embeddedItem: anchor.liquidController.activePopup?.contentItem ?? null
                span: embeddedItem?.implicitHeight+28 || 300
                depth: embeddedItem?.implicitWidth+28 || 500
                largeSurface:true
            }
        }
    }
    ClockCalendarPopup { id: popup;hoverTarget:anchor;hoverActivates:false;alternativeVisibleCondition:false }
    Timer {
        interval:350;running:true;repeat:true
        onTriggered: {
            if(root.step===0) popup.alternativeVisibleCondition=true
            else if(root.step===1) {
                if(!root.check(first.activePopup===popup && popup.presentationActive && !popup.active,"mature popup uses field without native popup")) return
                if(!root.check(popup._attachmentEdge==="right" && popup.presentationWindow===window,"actual module edge and window own presentation")) return
                if(!root.check(popup.contentItem.parent===body.contentParent && body.inputBounds.width>0,"mature content rehosted with local input")) return
                anchor.liquidController=second
                if(!root.check(first.activePopup===null && second.activePopup===popup,"output migration releases old ownership")) return
                popup.alternativeVisibleCondition=false
                if(!root.check(body.inputBounds.width===0,"semantic close releases input immediately")) return
            } else if(root.step===3) {
                if(!root.check(second.activePopup===null && !popup.presentationActive,"retract releases visual content")) return
                popup.alternativeVisibleCondition=true
            } else if(root.step===4) {
                if(!root.check(popup.contentItem.parent===body.contentParent && popup.presentationActive,"same popup reopens")) return
                second.presented=false
                if(!root.check(second.activePopup===null && !popup.presentationActive && body.inputBounds.width===0,"hidden output closes and releases popup")) return
                console.info("ABYSS_STYLED_POPUP_PASS");Qt.quit();return
            }
            root.step++
        }
    }
}
QML
if ! QT_QPA_PLATFORM=wayland XDG_CONFIG_HOME="$popup_test_root/config" XDG_STATE_HOME="$popup_test_root/state" XDG_CACHE_HOME="$popup_test_root/cache" timeout 8s qs -p "$popup_test_root" --no-color > "$popup_test_root/runtime.log" 2>&1; then
    cat "$popup_test_root/runtime.log"
    exit 1
fi
if ! rg -q 'ABYSS_STYLED_POPUP_PASS' "$popup_test_root/runtime.log" || rg -q 'ABYSS_STYLED_POPUP_FAIL|ReferenceError:|TypeError:|Binding loop' "$popup_test_root/runtime.log"; then
    cat "$popup_test_root/runtime.log"
    exit 1
fi
printf 'PASS: mature StyledPopup field ownership, actual edge, migration, input release and reopen\n'
