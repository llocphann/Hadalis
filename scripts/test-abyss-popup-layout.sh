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
//@ pragma ShellId hadalis-abyss-popup-layout-test
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.abyss.content
ShellRoot {
    id: root
    property int step: 0
    function check(value,message): bool {
        if (value) return true
        console.error("ABYSS_POPUP_LAYOUT_FAIL",message);Qt.quit();return false
    }
    FloatingWindow {
        visible: true; implicitWidth: 1200; implicitHeight: 900
        AbyssPopupContent { id: popup; width:desiredWidth; height:desiredHeight }
    }
    Timer {
        interval: 350; running: true; repeat: true
        onTriggered: {
            if(root.step===0) popup.kind="clock"
            else if(root.step===1 || root.step===6) {
                const calendar=popup.feature.contentItem.children.find(c=>c.calendarCells!==undefined)
                if(!root.check(calendar && calendar.calendarCells.length===42,"mature calendar keeps six weeks")) return
                if(!root.check(popup.desiredWidth>=600 && calendar.width===popup.width && calendar.height<=popup.height,"Events and Calendar retain full shared layout")) return
                if(root.step===6) { console.info("ABYSS_POPUP_LAYOUT_PASS");Qt.quit();return }
                popup.kind="resources"
            } else if(root.step===2) {
                if(!root.check(popup.feature.presentationActive && !popup.feature.active && popup.feature.thinkFanCanApply!==undefined,"shared resources/fan controls active without another popup host")) return
                popup.kind="battery"
            } else if(root.step===3) {
                if(!root.check(popup.desiredWidth>100 && popup.desiredHeight>50 && !popup.feature.active,"mature battery content-sized layout")) return
                popup.kind="weather"
            } else if(root.step===4) {
                if(!root.check(popup.desiredWidth===390 && popup.desiredHeight===300,"shared two-tab weather dimensions")) return
                popup.kind="media"
            } else if(root.step===5) {
                if(!root.check(popup.feature.tabCount!==undefined && popup.desiredHeight>0,"shared player tabs and Equalizer")) return
                Config.setNestedValue("appearance.typography.sizeScale",1.5)
                popup.kind="clock"
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
if ! rg -q 'ABYSS_POPUP_LAYOUT_PASS' "$popup_test_root/runtime.log" || rg -q 'ABYSS_POPUP_LAYOUT_FAIL|ReferenceError:|TypeError:|Binding loop' "$popup_test_root/runtime.log"; then
    cat "$popup_test_root/runtime.log"
    exit 1
fi
printf 'PASS: mature popup content/layout retained across Calendar, Resources, Battery, Weather and Media\n'
