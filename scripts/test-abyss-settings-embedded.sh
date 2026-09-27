#!/usr/bin/env bash
# Exercise the real mature card in an embedded surface with deep-link routing.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null; then printf 'SKIP: embedded Settings (Quickshell unavailable)\n'; exit 0; fi
settings_test_root="$(mktemp -d)"
trap 'rm -rf -- "$settings_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$settings_test_root/$entry"
done
mkdir -p "$settings_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$settings_test_root/config/illogical-impulse/config.json"
cat > "$settings_test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-settings-embedded-test
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
    id: root
    property int step: 0
    function check(value,message): bool {
        if(value) return true
        console.error("EMBEDDED_SETTINGS_FAIL",message);Qt.quit();return false
    }
    FloatingWindow {
        visible: true; implicitWidth: 1280; implicitHeight: 900
        AbyssBodyHost {
            id: body; anchors.fill: parent
            edge: "bottom"; largeSurface: true; span: 1150; depth: 800
            along: 65; source: Qt.resolvedUrl("modules/abyss/content/AbyssSettingsContent.qml")
            open: GlobalStates.settingsOverlayOpen
        }
    }
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            if(root.step===0) {
                Config.setNestedValue("panelFamily","abyss")
                Config.setNestedValue("settingsUi.overlayMode",false)
                Config.setNestedValue("performance.reduceAnimations",true)
                GlobalStates.deferredPanelsReady=true
                GlobalStates.openSettingsPage(10)
                if(!root.check(GlobalStates.settingsOverlayOpen,"Abyss opens embedded settings regardless of window preference")) return
            }
            if(root.step===3) {
                if(!root.check(body.ready,"mature Settings wrapper loaded")) return
                const card=Array.from(body.contentItem.item.children).find(c=>c.maxCardWidth!==undefined)
                if(!root.check(!!card && card.parent===body.contentItem.item,"same Settings card reparented into the liquid host")) return
                if(!root.check(card.width>1000 && card.height>700,"mature layout remains large and usable")) return
                if(!root.check(GlobalStates.settingsOverlayCurrentPage===10,"deep link survives page initialization")) return
                GlobalStates.openSettingsPage(1)
            }
            if(root.step===5) {
                if(!root.check(GlobalStates.settingsOverlayCurrentPage===1,"shared page navigation remains functional")) return
                GlobalStates.settingsOverlayOpen=false
                if(!root.check(body.inputBounds.width===0,"Settings closes with immediate input release")) return
            }
            if(root.step===7) { console.info("EMBEDDED_SETTINGS_PASS");Qt.quit() }
            root.step++
        }
    }
}
QML
if ! env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=offscreen \
    XDG_CONFIG_HOME="$settings_test_root/config" XDG_STATE_HOME="$settings_test_root/state" \
    XDG_CACHE_HOME="$settings_test_root/cache" timeout 10s qs -p "$settings_test_root" --no-color \
    > "$settings_test_root/runtime.log" 2>&1; then
    cat "$settings_test_root/runtime.log";exit 1
fi
if ! rg -q 'EMBEDDED_SETTINGS_PASS' "$settings_test_root/runtime.log" || rg -q 'EMBEDDED_SETTINGS_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign' "$settings_test_root/runtime.log"; then
    cat "$settings_test_root/runtime.log";exit 1
fi
printf 'PASS: mature Settings card embeds at original scale, consumes deep links, navigates and releases input\n'
