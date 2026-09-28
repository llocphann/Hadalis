#!/usr/bin/env bash
# Rehost real network forms without opening another dialog or touching a radio.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
layout="$repo_root/modules/abyss/looks/AbyssLayout.js"
module="$repo_root/modules/abyss/bar/AbyssBarModule.qml"
tray="$repo_root/modules/bar/SysTray.qml"
tray_item="$repo_root/modules/bar/SysTrayItem.qml"
tray_service="$repo_root/services/TrayService.qml"
migration="$repo_root/sdata/migrations/053-retire-abyss-connectivity-modules.sh"

for token in '"wifi"' '"bluetooth"'; do
    grep -Fq "$token" "$layout" && {
        printf 'FAIL: retired connectivity Edge module remains in Abyss catalog: %s\n' "$token" >&2
        exit 1
    }
done
grep -Fq 'onHoverPopupRequested: kind => root.request(kind)' "$module"     || { printf 'FAIL: Abyss System Tray does not route connectivity hover into connected popup\n' >&2; exit 1; }
grep -Fq 'signal hoverPopupRequested(string kind)' "$tray"     || { printf 'FAIL: shared System Tray hover popup signal missing\n' >&2; exit 1; }
grep -Fq 'TrayService.connectivityKind(root.item)' "$tray_item"     || { printf 'FAIL: tray item does not classify connectivity icons\n' >&2; exit 1; }
grep -Fq 'root.hoverPopupRequested(root.abyssConnectivityKind)' "$tray_item"     || { printf 'FAIL: tray item does not request connectivity popup on Abyss hover\n' >&2; exit 1; }
grep -Fq 'function connectivityKind(item): string' "$tray_service"     || { printf 'FAIL: centralized connectivity tray classifier missing\n' >&2; exit 1; }
grep -Fq 'MIGRATION_ID="053-retire-abyss-connectivity-modules"' "$migration"     || { printf 'FAIL: retired connectivity module migration missing\n' >&2; exit 1; }

migration_tmp="$(mktemp -d)"
trap 'rm -rf -- "$migration_tmp"' EXIT
mkdir -p "$migration_tmp/inir"
cat > "$migration_tmp/inir/config.json" <<'JSON'
{"abyss":{"modules":{"placements":[{"id":"wifi","kind":"wifi"},{"id":"clock","kind":"clock"},{"id":"bluetooth","kind":"bluetooth"}],"outputLayouts":[{"outputName":"A","placements":[{"id":"bt-a","kind":"bluetooth"},{"id":"media","kind":"media"}]}]}}}
JSON
(
    export XDG_CONFIG_HOME="$migration_tmp"
    source "$migration"
    migration_check || { printf 'FAIL: connectivity migration did not detect retired modules\n' >&2; exit 1; }
    migration_apply || { printf 'FAIL: connectivity migration apply failed\n' >&2; exit 1; }
    migration_check && { printf 'FAIL: connectivity migration is not idempotent\n' >&2; exit 1; }
    jq -e '(.abyss.modules.placements | map(.kind)) == ["clock"]
        and (.abyss.modules.outputLayouts[0].placements | map(.kind)) == ["media"]'         "$XDG_CONFIG_HOME/inir/config.json" >/dev/null         || { printf 'FAIL: connectivity migration removed/preserved wrong placements\n' >&2; exit 1; }
)

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
            id: trayModule; width: 160; height: 32; outputName: "network-test"; kind: "tray"
            onRequest: kind=> { if(["wifi","bluetooth"].includes(kind)) root.requests++ }
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
                if(!root.check(trayModule.feature && trayModule.naturalSpan>=0,"System Tray module is usable")) return
                trayModule.feature.hoverPopupRequested(root.step===1 ? "wifi" : "bluetooth")
                if(!root.check(root.requests===(root.step===1 ? 1 : 2),"System Tray hover sends the matching popup request")) return
                if(root.step===1) { body.contentKind="bluetooth" }
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
printf 'PASS: Wi-Fi/Bluetooth forms, System Tray hover routing, retired Edge modules, migration, vertical placement and input release\n'
