#!/usr/bin/env bash
# Exercise the Utilities popup host without changing displays, audio devices or light state.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss Utilities popup runtime (Quickshell/Wayland unavailable)\n'
    exit 0
fi
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$test_root/$entry"
done
mkdir -p "$test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$test_root/config/illogical-impulse/config.json"
cat > "$test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-utilities-popup-test
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss.content

ShellRoot {
    id: root
    property int step: 0
    property bool finished: false
    property int dismissed: 0
    function check(ok,message): bool {
        if (ok) return true
        console.error("UTILITIES_POPUP_FAIL",message)
        root.finished = true
        return false
    }

    FloatingWindow {
        visible: true
        implicitWidth: 900
        implicitHeight: 720
        AbyssPopupContent {
            id: popup
            anchors.fill: parent
            kind: "utilities"
            outputName: "utilities-test"
            onCloseRequested: root.dismissed++
        }
    }

    Timer {
        interval: 350
        repeat: true
        running: !root.finished
        onTriggered: {
            if (!Config.ready) return
            const utility = popup.feature
            if (root.step === 0) {
                Config.setNestedValue("panelFamily","abyss")
            } else if (root.step === 1) {
                if (!root.check(utility !== null, "Utilities feature loads through AbyssPopupContent")) return
                if (!root.check(popup.desiredWidth >= 700 && popup.desiredHeight >= 560,
                    "Utilities reports a bounded four-page popup size")) return
                if (!root.check(utility.currentPage === 0 && utility.loadedPageCount > 0
                    && utility.loadedPageCount <= 3, "pages are lazy rather than all eagerly loaded")) return
                utility.currentPage = 1
            } else if (root.step === 2) {
                if (!root.check(utility.currentPage === 1 && utility.currentFeature !== null,
                    "Display mode page participates in horizontal navigation")) return
                utility.currentPage = 2
            } else if (root.step === 3) {
                if (!root.check(utility.currentPage === 2 && utility.currentFeature !== null,
                    "Sound output page loads without changing the default sink")) return
                if (!root.check(utility.loadedPageCount <= 3,
                    "lazy page window remains bounded while swiping")) return
                utility.closeRequested()
            } else if (root.step === 4) {
                if (!root.check(root.dismissed === 1, "Utilities close request propagates through popup content")) return
                console.info("UTILITIES_POPUP_PASS")
                root.finished = true
            }
            root.step++
        }
    }
}
QML
status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland \
    XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state" \
    XDG_CACHE_HOME="$test_root/cache" timeout 20s qs -p "$test_root" --no-color \
    > "$test_root/runtime.log" 2>&1 || status=$?
if [[ "$status" != 124 ]] || ! rg -q 'UTILITIES_POPUP_PASS' "$test_root/runtime.log" \
        || rg -q 'UTILITIES_POPUP_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log"; then
    cat "$test_root/runtime.log"
    exit 1
fi
printf 'PASS: Utilities popup lazy navigation, display/audio page hosting and close propagation\n'
