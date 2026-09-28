#!/usr/bin/env bash
# Rehost real network forms without opening another dialog or touching a radio.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss network popup runtime (Quickshell/Wayland unavailable)\n'
    exit 0
fi
network_test_root="$(mktemp -d)"
trap 'rm -rf -- "$network_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$network_test_root/$entry"
done
mkdir -p "$network_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$network_test_root/config/illogical-impulse/config.json"
cat > "$network_test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-network-popup-test
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
import qs.modules.abyss.bar
import qs.modules.abyss.content
ShellRoot {
    id: root
    property int step: 0
    property bool finished: false
    property int dismissed: 0
    property int requests: 0
    function check(ok,message): bool {
        if(ok) return true
        console.error("NETWORK_POPUP_FAIL",message);root.finished=true;return false
    }
    AbyssSurfaceController {
        id: controller; outputName: "network-test"
        outputWidth: 960; outputHeight: 720
    }
    FloatingWindow {
        visible: true; implicitWidth: 960; implicitHeight: 720
        AbyssBodyHost {
            id: body; anchors.fill: parent
            identity: "networkPopup"; outputName: "network-test"; controller: controller
            edgeInsets: controller.edgeInsets
            edge: "top"; along: 100; span: 408; depth: 528
            stableContentSize: true; largeSurface: true
            source: Qt.resolvedUrl("modules/abyss/content/AbyssPopupContent.qml")
            contentKind: "wifi"
            onCloseRequested: { root.dismissed++;open=false }
        }
        AbyssBarModule {
            id: button; width: 36; height: 32; outputName: "network-test"; kind: "wifi"
            onRequest: kind=> { if(kind===button.kind) root.requests++ }
        }
    }
    Timer {
        interval: 350; running: !root.finished; repeat: true
        onTriggered: {
            if(!Config.ready) return
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                Config.setNestedValue("performance.reduceAnimations",true)
                GlobalStates.deferredPanelsReady=true;body.open=true
            } else if(root.step===1 || root.step===3) {
                const popup=body.contentItem.item,form=popup?.feature?.dialog
                if(!root.check(body.ready && body.inputBounds.width>0 && popup.desiredWidth===380 && popup.desiredHeight===500,"bounded network popup content loads")) return
                if(!root.check(form?.show && form.effectiveEmbedded && !form.liquidHosted && controller.activeDialog===null,"mature form reuses the popup rather than acquiring a dialog host")) return
                if(!root.check(button.feature && button.naturalSpan>0,"network Edge module is usable")) return
                button.feature.clicked()
                if(!root.check(root.requests===(root.step===1 ? 1 : 2),"module sends the matching popup request")) return
                if(root.step===1) { body.contentKind="bluetooth";button.kind="bluetooth" }
                else { form.dismiss() }
            } else if(root.step===4) {
                if(!root.check(root.dismissed===1 && !body.open && body.inputBounds.width===0,"Done dismisses the existing host and releases input")) return
                body.edge="right";body.span=528;body.depth=408;body.open=true
            } else if(root.step===5) {
                if(!root.check(body.inputBounds.x>=0 && body.inputBounds.y>=0 && body.inputBounds.x+body.inputBounds.width<=960 && body.inputBounds.y+body.inputBounds.height<=720,"popup can move to a vertical Edge")) return
                body.contentItem.item.enabled=false
                if(!root.check(!body.contentItem.item.feature.enabled,"layout preview disables connection controls")) return
                body.open=false
            } else if(root.step===6) {
                if(!root.check(!body.ready && controller.records.length===0,"closed popup unloads and releases the field")) return
                console.info("NETWORK_POPUP_PASS");root.finished=true
            }
            root.step++
        }
    }
}
QML
status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland \
    XDG_CONFIG_HOME="$network_test_root/config" XDG_STATE_HOME="$network_test_root/state" \
    XDG_CACHE_HOME="$network_test_root/cache" timeout 20s qs -p "$network_test_root" --no-color \
    > "$network_test_root/runtime.log" 2>&1 || status=$?
if [[ "$status" != 124 ]] || ! rg -q 'NETWORK_POPUP_PASS' "$network_test_root/runtime.log" \
        || rg -q 'NETWORK_POPUP_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$network_test_root/runtime.log"; then
    cat "$network_test_root/runtime.log"; exit 1
fi
printf 'PASS: Wi-Fi/Bluetooth forms, module requests, vertical placement, safe previews and unload/input release\n'
