#!/usr/bin/env bash
# Lay out the real popup in a rendered Qt window through content-kind changes.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null; then
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
        visible: true; implicitWidth: 350; implicitHeight: 340
        AbyssPopupContent { id: popup; anchors.fill: parent }
    }
    Timer {
        interval: 350; running: true; repeat: true
        onTriggered: {
            const column = popup.contentItem.children[0]
            const loaders = Array.from(column.children).filter(c => c.active !== undefined && c.status !== undefined)
            if (root.step === 0) {
                popup.kind = "clock"
            } else if (root.step === 1 || root.step === 3 || root.step === 5) {
                const calendar = loaders.find(c => c.active && c.item && c.item.monthOffset !== undefined)
                if (!root.check(!!calendar,"calendar loaded")) return
                if (!root.check(calendar.y+calendar.height <= popup.height,"all six calendar rows fit the initial viewport")) return
                const cells = Array.from(calendar.item.children[1].children).filter(c => c.date !== undefined)
                if (!root.check(cells.length === 42,"six complete weeks")) return
                if (!root.check(loaders.every(c => c.active || !c.visible),"unloaded content leaves no stale layout space")) return
                if (!root.check(popup.contentHeight < 400,"content height is independent of previous media size")) return
                if (root.step === 1) popup.kind = "weather"
                else if (root.step === 3) Config.setNestedValue("appearance.typography.sizeScale",1.5)
                else {
                    if (!root.check(Appearance.fontSizeScale === 1.5,"actual typography scaling applied")) return
                    console.info("ABYSS_POPUP_LAYOUT_PASS");Qt.quit()
                }
            } else if (root.step === 2) {
                if (!root.check(loaders.every(c => !c.active && !c.visible),"weather excludes both cached loaders")) return
                popup.kind = "clock"
            }
            root.step++
        }
    }
}
QML
if ! QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$popup_test_root/config" XDG_STATE_HOME="$popup_test_root/state" XDG_CACHE_HOME="$popup_test_root/cache" timeout 8s qs -p "$popup_test_root" --no-color > "$popup_test_root/runtime.log" 2>&1; then
    cat "$popup_test_root/runtime.log"
    exit 1
fi
if ! rg -q 'ABYSS_POPUP_LAYOUT_PASS' "$popup_test_root/runtime.log" || rg -q 'ABYSS_POPUP_LAYOUT_FAIL|ReferenceError:|TypeError:|Binding loop' "$popup_test_root/runtime.log"; then
    cat "$popup_test_root/runtime.log"
    exit 1
fi
printf 'PASS: production popup excludes cached loader space; all six calendar rows fit after media/weather and font scaling\n'
