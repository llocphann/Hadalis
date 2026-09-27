#!/usr/bin/env bash
# Shared WindowDialog content must move into and out of the liquid host safely.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null; then printf 'SKIP: Abyss dialog host (Quickshell unavailable)\n'; exit 0; fi
abyss_dialog_test="$(mktemp -d)"
trap 'rm -rf -- "$abyss_dialog_test"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do ln -s "$repo_root/$entry" "$abyss_dialog_test/$entry"; done
mkdir -p "$abyss_dialog_test/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$abyss_dialog_test/config/illogical-impulse/config.json"
cat > "$abyss_dialog_test/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss
ShellRoot {
    id: root
    property int step: 0
    function check(ok, message): bool {
        if(ok) return true
        console.error("DIALOG_HOST_FAIL",message);Qt.quit();return false
    }
    AbyssSurfaceController { id: liquid; dialogHost: dialogHost }
    FloatingWindow {
        visible: true; implicitWidth: 1000; implicitHeight: 750
        AbyssBodyHost {
            id: original; anchors.fill: parent; edge: "left"; controller: liquid; identity: "owner"
            Item {
                id: originalHome; width: 500; height: 700
                WindowDialog {
                    id: dialog; anchors.fill: parent; backgroundWidth: 350; backgroundHeight: 450
                    onDismiss: show = false
                    WindowDialogTitle { text: "Shared form" }
                    StyledText { text: "One backend and one form" }
                }
            }
        }
        AbyssBodyHost {
            id: dialogHost; anchors.fill: parent; edge: "right"; identity: "dialog"; controller: liquid
            open: liquid.activeDialog !== null; embeddedItem: liquid.activeDialog
            span: 490; depth: 390
        }
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            if(root.step===0) { Config.setNestedValue("performance.reduceAnimations",true);dialog.show=true }
            if(root.step===1) {
                if(!root.check(liquid.activeDialog===dialog && dialog.parent===dialogHost.contentParent,"existing form reparented")) return
                if(!root.check(dialog.effectiveEmbedded && dialogHost.ready && dialogHost.inputBounds.width>300,"liquid content and input")) return
                dialog.dismiss()
                if(!root.check(liquid.activeDialog===null && dialog.parent===originalHome && dialogHost.inputBounds.width===0,"retained dialog restores parent and releases input")) return
            }
            if(root.step===2) dialog.show=true
            if(root.step===3) {
                if(!root.check(liquid.activeDialog===dialog,"retained form can reopen")) return
                dialog.show=false
                console.info("DIALOG_HOST_PASS");Qt.quit()
            }
            root.step++
        }
    }
}
QML
if ! dbus-run-session -- env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=offscreen \
 XDG_CONFIG_HOME="$abyss_dialog_test/config" XDG_STATE_HOME="$abyss_dialog_test/state" XDG_CACHE_HOME="$abyss_dialog_test/cache" \
 timeout 8s qs -p "$abyss_dialog_test" --no-color > "$abyss_dialog_test/runtime.log" 2>&1; then cat "$abyss_dialog_test/runtime.log";exit 1; fi
if ! rg -q DIALOG_HOST_PASS "$abyss_dialog_test/runtime.log" || rg -q 'DIALOG_HOST_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type|Type .* unavailable' "$abyss_dialog_test/runtime.log"; then cat "$abyss_dialog_test/runtime.log";exit 1; fi
printf 'PASS: shared dialog liquid embedding, retained reopen and immediate input release\n'
