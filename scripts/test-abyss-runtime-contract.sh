#!/usr/bin/env bash
# Exercise the production host's loading/input/retraction lifecycle in QML.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v qs >/dev/null; then
    printf 'SKIP: Abyss runtime contract (Quickshell unavailable)\n'
    exit 0
fi
abyss_test_root="$(mktemp -d)"
trap 'rm -rf -- "$abyss_test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$abyss_test_root/$entry"
done
mkdir -p "$abyss_test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$abyss_test_root/config/illogical-impulse/config.json"
cat > "$abyss_test_root/Content.qml" <<'QML'
import QtQuick
Item { property string outputName: ""; signal closeRequested() }
QML
cat > "$abyss_test_root/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss
ShellRoot {
    property int step: 0
    property bool failed: false
    function check(condition, message): bool {
        if (condition) return true
        failed = true
        console.error("ABYSS_RUNTIME_FAIL", message)
        Qt.quit()
        return false
    }
    Item {
        width: 1000; height: 700
        AbyssBodyHost {
            id: body
            anchors.fill: parent
            edge: "right"; outputName: "DP-test"
            along: 80; span: 450; depth: 300
            source: Qt.resolvedUrl("Content.qml")
        }
    }
    Timer {
        interval: 400; running: true; repeat: true
        onTriggered: {
            if (failed) return
            if (step === 0) {
                GlobalStates.shellEntryReady = true
                GlobalStates.deferredPanelsReady = false
                body.open = true
            } else if (step === 1) {
                if (!check(!body.ready && body.inputBounds.width === 0,"deferred gate")) return
                GlobalStates.deferredPanelsReady = true
            } else if (step === 2) {
                if (!check(body.ready && body.inputBounds.width > 0 && body.inputBounds.height > 0,"visible content input")) return
                if (!check(body.contentItem.item.outputName === "DP-test","output binding")) return
                body.open = false
                if (!check(body.inputBounds.width === 0 && body.inputBounds.height === 0,"immediate input release")) return
                if (!check(!body.contentItem.enabled,"disabled content while retracting")) return
            } else if (step === 4) {
                if (!check(!body.ready && body.record.surface.width === 0,"retracted host unload")) return
                Config.setNestedValue("performance.reduceAnimations",true)
                body.open = true
            } else if (step === 5) {
                if (!check(body.ready && body.inputBounds.width > 0,"reopen")) return
                body.open = false
                if (!check(body.inputBounds.width === 0,"reopen close input release")) return
                if (!check(body.progress === 0,"reduced motion closes synchronously")) return
            } else if (step === 7) {
                if (!check(!body.ready,"reopen unload")) return
                console.info("ABYSS_RUNTIME_PASS")
                Qt.quit()
            }
            step++
        }
    }
}
QML
if ! QT_QPA_PLATFORM=offscreen XDG_CONFIG_HOME="$abyss_test_root/config" XDG_STATE_HOME="$abyss_test_root/state" XDG_CACHE_HOME="$abyss_test_root/cache" timeout 12s qs -p "$abyss_test_root" --no-color > "$abyss_test_root/runtime.log" 2>&1; then
    cat "$abyss_test_root/runtime.log"
    exit 1
fi
if ! rg -q 'ABYSS_RUNTIME_PASS' "$abyss_test_root/runtime.log"; then
    cat "$abyss_test_root/runtime.log"
    exit 1
fi
printf 'PASS: production Abyss host deferred loading, output binding, immediate input release and unload/reopen\n'
