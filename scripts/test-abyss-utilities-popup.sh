#!/usr/bin/env bash
# Exercise the Utilities popup host without changing displays, audio devices or light state.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
layout="$repo_root/modules/abyss/looks/AbyssLayout.js"
quick_actions="$repo_root/modules/bar/UtilButtons.qml"
module="$repo_root/modules/abyss/bar/AbyssBarModule.qml"
migration="$repo_root/sdata/migrations/055-retire-abyss-utilities-module.sh"

grep -Fq '"utilities"' "$layout" && {
    printf 'FAIL: Utilities remains a standalone Abyss Edge module\n' >&2
    exit 1
}
grep -Fq 'showUtilitiesLauncher: true' "$module" \
    || { printf 'FAIL: Abyss Quick Actions does not enable the Utilities launcher\n' >&2; exit 1; }
grep -Fq 'signal utilitiesRequested()' "$quick_actions" \
    || { printf 'FAIL: shared Quick Actions lacks the opt-in Utilities launcher contract\n' >&2; exit 1; }
grep -Fq 'MIGRATION_ID="055-retire-abyss-utilities-module"' "$migration" \
    || { printf 'FAIL: retired Utilities module migration missing\n' >&2; exit 1; }

migration_tmp="$(mktemp -d)"
trap 'rm -rf -- "$migration_tmp"' EXIT
mkdir -p "$migration_tmp/inir"
cat > "$migration_tmp/inir/config.json" <<'JSON'
{"abyss":{"modules":{"placements":[{"id":"utilities","kind":"utilities"},{"id":"quick","kind":"utilButtons"}],"outputLayouts":[{"outputName":"A","placements":[{"id":"u-a","kind":"utilities"},{"id":"clock","kind":"clock"}]},{"outputName":"B","placements":[{"id":"u-b","kind":"utilities"}]}]}}}
JSON
(
    export XDG_CONFIG_HOME="$migration_tmp"
    source "$migration"
    migration_check || { printf 'FAIL: Utilities migration did not detect retired module\n' >&2; exit 1; }
    migration_apply || { printf 'FAIL: Utilities migration apply failed\n' >&2; exit 1; }
    migration_check && { printf 'FAIL: Utilities migration is not idempotent\n' >&2; exit 1; }
    jq -e '
        (.abyss.modules.placements | map(.kind)) == ["utilButtons"]
        and ((.abyss.modules.outputLayouts[0].placements | map(.kind) | sort) == ["clock","utilButtons"])
        and (.abyss.modules.outputLayouts[1].placements | map(.kind)) == ["utilButtons"]
        and (.abyss.modules.outputLayouts[0].placements[] | select(.kind=="utilButtons") | .id) == "utilButtons"
    ' "$XDG_CONFIG_HOME/inir/config.json" >/dev/null \
        || { printf 'FAIL: Utilities migration did not preserve/insert Quick Actions correctly\n' >&2; exit 1; }
)

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
    property real monitorWidth: 0
    property real monitorHeight: 0
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
                if (!root.check(popup.desiredWidth <= 640 && popup.desiredHeight <= 450,
                    "Monitor utility uses a content-sized footprint")) return
                root.monitorWidth = popup.desiredWidth
                root.monitorHeight = popup.desiredHeight
                if (!root.check(utility.currentPage === 0 && utility.loadedPageCount > 0
                    && utility.loadedPageCount <= 3, "pages are lazy rather than all eagerly loaded")) return
                utility.currentPage = 1
            } else if (root.step === 2) {
                if (!root.check(utility.currentPage === 1 && utility.currentFeature !== null,
                    "Display mode page participates in horizontal navigation")) return
                if (!root.check(popup.desiredWidth !== root.monitorWidth || popup.desiredHeight !== root.monitorHeight,
                    "Utilities footprint follows the active page")) return
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
printf 'PASS: Utilities lives in Quick Actions, migrates old Edge modules and uses content-sized lazy pages\n'
