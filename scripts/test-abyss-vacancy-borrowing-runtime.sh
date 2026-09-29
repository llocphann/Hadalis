#!/usr/bin/env bash
# Exercise the real Abyss host/controller path with production semantic roles and
# ShellLayoutController's physical sidebar swap assignment.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
perimeter="$repo_root/modules/abyss/AbyssPerimeter.qml"
body_host="$repo_root/modules/abyss/AbyssBodyHost.qml"

for token in     'vacancyRole: "featureSidebar"'     'vacancyRole: "systemSidebar"'     'presentationKind === "quickNotes"'     'presentationKind === "notificationCenter"'; do
    grep -Fq "$token" "$perimeter"         || { printf 'FAIL: production vacancy wiring missing: %s\n' "$token" >&2; exit 1; }
done
for token in     'property bool vacancyHovered: root.vacancyRole.length > 0'     'id: vacancyBodyHover'     'parent: contentFrame'     'enabled: root.vacancyRole.length > 0'; do
    grep -Fq "$token" "$body_host"         || { printf 'FAIL: final-body vacancy hover wiring missing: %s\n' "$token" >&2; exit 1; }
done
if grep -Fq 'vacancyHovered:' "$perimeter"; then
    printf 'FAIL: production perimeter overrides final-body vacancy hover\n' >&2
    exit 1
fi

if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss vacancy borrowing runtime (Quickshell/Wayland unavailable)\n'
    exit 0
fi

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$test_root/$entry"
done
mkdir -p "$test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$test_root/config/illogical-impulse/config.json"

cat > "$test_root/Content.qml" <<'QML'
import QtQuick
Item {
    property string outputName: ""
    signal closeRequested()
}
QML

cat > "$test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-vacancy-borrowing-runtime
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss

ShellRoot {
    id: root
    property int step: 0
    property bool finished: false
    property bool featureOpen: false
    property bool notesOpen: false
    property bool featureHover: false
    property bool notesHover: false
    property var featureBase: null
    property var notesBase: null

    function check(ok, message): bool {
        if (ok) return true
        console.error("ABYSS_VACANCY_RUNTIME_FAIL", message)
        root.finished = true
        Qt.quit()
        return false
    }
    function near(a, b): bool {
        return Math.abs(Number(a) - Number(b)) < 1.25
    }
    function samePlacement(a, b): bool {
        return a && b
            && near(a.along,b.along) && near(a.inward,b.inward)
            && near(a.span,b.span) && near(a.depth,b.depth)
    }

    AbyssSurfaceController {
        id: controller
        outputName: "DP-vacancy"
        presentationItem: scene
        outputWidth: scene.width
        outputHeight: scene.height
        edgeInsets: ({left:16,right:16,top:16,bottom:16})
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1200
        implicitHeight: 900

        Item {
            id: scene
            anchors.fill: parent

            AbyssBodyHost {
                id: feature
                anchors.fill: parent
                identity: "leftPanel"
                controller: controller
                outputName: controller.outputName
                edge: ShellLayoutController.sidebarAssignments().featureSidebar
                vacancyRole: "featureSidebar"
                vacancyHovered: root.featureHover
                open: root.featureOpen
                edgeInsets: controller.edgeInsets
                along: 136
                span: 608
                depth: 458
                source: Qt.resolvedUrl("Content.qml")
            }

            AbyssBodyHost {
                id: notes
                anchors.fill: parent
                identity: "styledPopup0"
                controller: controller
                outputName: controller.outputName
                edge: "bottom"
                vacancyRole: "quickNotes"
                vacancyHovered: root.notesHover
                open: root.notesOpen
                edgeInsets: controller.edgeInsets
                along: 30
                span: 418
                depth: 298
                source: Qt.resolvedUrl("Content.qml")
            }
        }
    }

    Timer {
        interval: 420
        running: !root.finished
        repeat: true
        onTriggered: {
            if (!Config.ready) return
            if (root.step === 0) {
                GlobalStates.deferredPanelsReady = true
                root.featureOpen = true
            } else if (root.step === 1) {
                root.notesOpen = true
            } else if (root.step === 2) {
                const baseFeature=controller.baseBodyPlacements.leftPanel
                const baseNotes=controller.baseBodyPlacements.styledPopup0
                if (!root.check(baseFeature?.visible && baseNotes?.visible,
                        "production allocator must place both semantic members")) return
                root.featureBase=Object.assign({},baseFeature)
                root.notesBase=Object.assign({},baseNotes)
                if (!root.check(controller.bodyPlacements.leftPanel?.vacancyBorrowed === true
                        && controller.bodyPlacements.styledPopup0?.vacancyBorrowed !== true,
                        "coexisting semantic pair must auto-expand the logical sidebar")) return
                if (!root.check(feature.inputBounds.width > 0 && feature.inputBounds.height > 0
                        && root.near(feature.inputBounds.x,feature.record.content.x)
                        && root.near(feature.inputBounds.y,feature.record.content.y)
                        && root.near(feature.inputBounds.width,feature.record.content.width)
                        && root.near(feature.inputBounds.height,feature.record.content.height),
                        "auto-expanded record and input geometry must share one truth")) return
                root.notesHover=true
            } else if (root.step === 3) {
                if (!root.check(controller.bodyPlacements.styledPopup0?.vacancyBorrowed === true
                        && controller.bodyPlacements.leftPanel?.vacancyBorrowed !== true,
                        "popup body hover must temporarily override automatic ownership")) return
                root.notesHover=false
            } else if (root.step === 4) {
                if (!root.check(controller.bodyPlacements.leftPanel?.vacancyBorrowed === true
                        && controller.bodyPlacements.styledPopup0?.vacancyBorrowed !== true,
                        "hover loss must return to automatic sidebar ownership")) return
                Config.setNestedValues({
                    "sidebar.shellLayout.feature.slot":"right",
                    "sidebar.shellLayout.system.slot":"left"
                })
                Config.flushWrites()
            } else if (root.step === 5) {
                if (!root.check(ShellLayoutController.sidebarAssignments().featureSidebar === "right"
                        && feature.edge === "right"
                        && feature.vacancyRole === "featureSidebar",
                        "physical sidebar swap must not change logical identity")) return
                if (!root.check(controller.bodyPlacements.leftPanel?.vacancyBorrowed === true,
                        "swapped logical feature sidebar must still auto-borrow")) return
                root.notesOpen=false
            } else if (root.step === 6) {
                const currentFeatureBase=controller.baseBodyPlacements.leftPanel
                if (!root.check(controller.bodyPlacements.leftPanel?.vacancyBorrowed !== true
                        && controller.bodyPlacements.styledPopup0?.vacancyBorrowed !== true,
                        "closing the semantic peer must disable automatic borrowing")) return
                if (!root.check(root.samePlacement(controller.bodyPlacements.leftPanel,currentFeatureBase),
                        "peer close must restore exact current base allocator target")) return
            } else if (root.step === 7) {
                const currentFeatureBase=controller.baseBodyPlacements.leftPanel
                if (!root.check(root.samePlacement(feature.visualPlacement,currentFeatureBase),
                        "existing placement motion must settle at exact base geometry")) return
                console.info("ABYSS_VACANCY_RUNTIME_PASS")
                root.finished=true
                Qt.quit()
            }
            root.step++
        }
    }

}
QML

status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST QT_QPA_PLATFORM=wayland     XDG_CONFIG_HOME="$test_root/config" XDG_STATE_HOME="$test_root/state"     XDG_CACHE_HOME="$test_root/cache" timeout 18s qs -p "$test_root" --no-color     > "$test_root/runtime.log" 2>&1 || status=$?

if [[ "$status" != 0 && "$status" != 124 ]]; then
    cat "$test_root/runtime.log"
    exit 1
fi
if ! rg -q 'ABYSS_VACANCY_RUNTIME_PASS' "$test_root/runtime.log"         || rg -q 'ABYSS_VACANCY_RUNTIME_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log"; then
    cat "$test_root/runtime.log"
    exit 1
fi
printf 'PASS: automatic semantic borrowing, final-body hover override, exact restore and physical sidebar swap\n'
