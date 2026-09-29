#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v qs >/dev/null 2>&1; then
    echo "SKIP: quickshell (qs) is unavailable"
    exit 0
fi
if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    echo "SKIP: Wayland runtime is unavailable"
    exit 0
fi

test_root="$(mktemp -d)"
cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT

mkdir -p "$test_root/config/hadalis" "$test_root/state" "$test_root/cache"
cat > "$test_root/config/hadalis/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.abyss
import qs.modules.bar

ShellRoot {
    id: root

    property bool finished: false
    property int phase: 0
    readonly property var screens: Quickshell.screens ?? []
    readonly property string outputOne:
        String(root.screens.length > 0 ? root.screens[0]?.name ?? "" : "")
    readonly property string outputTwo:
        String(root.screens.length > 1 ? root.screens[1]?.name ?? "" : "")

    function check(ok, message): bool {
        if (ok)
            return true
        console.error("ABYSS_CONFIRMATION_MULTI_OUTPUT_FAIL", message)
        root.finished = true
        return false
    }

    function request(appId, outputName, title): int {
        return ConfirmationService.enqueue({
            owner: "multi-output-runtime",
            appId: appId,
            outputName: outputName,
            title: title,
            message: "Two-output confirmation routing.",
            actions: [
                { id: "cancel", label: "Cancel", role: "cancel", isCancel: true },
                { id: "accept", label: "Accept", role: "default", isDefault: true }
            ]
        })
    }

    FloatingWindow {
        id: windowOne
        visible: true
        screen: root.screens.length > 0 ? root.screens[0] : null
        implicitWidth: 720
        implicitHeight: 520

        Item {
            id: sceneOne
            anchors.fill: parent

            Item {
                id: trayOne
                property var liquidController: controllerOne
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: 80
                y: 0
                width: 40
                height: 40
                visible: true
                enabled: true
            }

            Item {
                id: fallbackOne
                property var liquidController: controllerOne
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: (sceneOne.width - width) / 2
                y: 0
                width: 1
                height: 1
                visible: true
                enabled: true
            }
        }
    }

    AbyssSurfaceController {
        id: controllerOne
        outputName: root.outputOne
        presentationItem: sceneOne
        outputWidth: sceneOne.width
        outputHeight: sceneOne.height
        edgeInsets: ({ left: 12, top: 12, right: 12, bottom: 12 })
    }

    FloatingWindow {
        id: windowTwo
        visible: true
        screen: root.screens.length > 1 ? root.screens[1] : null
        implicitWidth: 720
        implicitHeight: 520

        Item {
            id: sceneTwo
            anchors.fill: parent

            Item {
                id: dockTwo
                property var liquidController: controllerTwo
                property string attachedEdge: "bottom"
                property string popupJoinedEdge: ""
                x: 120
                y: sceneTwo.height - height
                width: 40
                height: 40
                visible: true
                enabled: true
            }

            Item {
                id: fallbackTwo
                property var liquidController: controllerTwo
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: (sceneTwo.width - width) / 2
                y: 0
                width: 1
                height: 1
                visible: true
                enabled: true
            }
        }
    }

    AbyssSurfaceController {
        id: controllerTwo
        outputName: root.outputTwo
        presentationItem: sceneTwo
        outputWidth: sceneTwo.width
        outputHeight: sceneTwo.height
        edgeInsets: ({ left: 12, top: 12, right: 12, bottom: 12 })
    }

    AbyssConfirmationPresenter {
        outputName: root.outputOne
        fallbackAnchor: fallbackOne
        presentationEnabled: true
    }

    AbyssConfirmationPresenter {
        outputName: root.outputTwo
        fallbackAnchor: fallbackTwo
        presentationEnabled: true
    }

    Timer {
        interval: 260
        repeat: true
        running: !root.finished

        onTriggered: {
            if (!Config.ready || root.outputOne.length === 0
                    || root.outputTwo.length === 0)
                return

            if (root.phase === 0) {
                if (!root.check(root.screens.length >= 2
                        && root.outputOne !== root.outputTwo,
                        "Wayland compositor must expose two distinct outputs"))
                    return
                Config.setNestedValue("panelFamily", "abyss")
                PopupAnchorRegistry.registerAnchor(
                    trayOne, "tray", () => ["multi.runtime.app"], 300)
                PopupAnchorRegistry.registerAnchor(
                    dockTwo, "dock", () => ["multi.runtime.app"], 200)
                root.request(
                    "multi.runtime.app", root.outputTwo,
                    "Prefer same-output Dock over remote Tray")
                root.phase = 1
                return
            }

            if (root.phase === 1) {
                if (!ConfirmationService.requestVisible
                        || controllerTwo.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === root.outputTwo
                        && ConfirmationService.resolvedAnchor === dockTwo,
                        "same-output affinity outranks a higher-priority remote surface"))
                    return
                if (!root.check(
                        controllerTwo.activePopup?.hoverTarget === dockTwo
                        && controllerOne.activePopups.length === 0,
                        "connected popup is presented only on requested output"))
                    return
                ConfirmationService.cancel()
                root.phase = 2
                return
            }

            if (root.phase === 2) {
                if (ConfirmationService.active)
                    return
                root.request(
                    "multi.runtime.app", root.outputOne,
                    "Prefer local Tray on first output")
                root.phase = 3
                return
            }

            if (root.phase === 3) {
                if (!ConfirmationService.requestVisible
                        || controllerOne.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === root.outputOne
                        && ConfirmationService.resolvedAnchor === trayOne,
                        "first-output request resolves its local Tray source"))
                    return
                ConfirmationService.cancel()
                root.phase = 4
                return
            }

            if (root.phase === 4) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.unregisterAnchor(trayOne)
                PopupAnchorRegistry.unregisterAnchor(dockTwo)
                root.request("", root.outputTwo, "Second-output fallback")
                root.phase = 5
                return
            }

            if (root.phase === 5) {
                if (!ConfirmationService.requestVisible
                        || controllerTwo.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === root.outputTwo
                        && ConfirmationService.resolvedAnchor === null
                        && controllerTwo.activePopup?.hoverTarget === fallbackTwo
                        && controllerOne.activePopups.length === 0,
                        "unresolved request uses top-center fallback on requested output"))
                    return
                ConfirmationService.cancel()
                root.phase = 6
                return
            }

            if (root.phase === 6) {
                if (ConfirmationService.active)
                    return
                console.info("ABYSS_CONFIRMATION_MULTI_OUTPUT_PASS")
                root.finished = true
            }
        }
    }
}
QML

status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST \
    QT_QPA_PLATFORM=wayland \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_STATE_HOME="$test_root/state" \
    XDG_CACHE_HOME="$test_root/cache" \
    timeout 20s qs -p "$test_root" --no-color \
    > "$test_root/runtime.log" 2>&1 || status=$?

if [[ "$status" != 124 ]] \
        || ! rg -q 'ABYSS_CONFIRMATION_MULTI_OUTPUT_PASS' "$test_root/runtime.log" \
        || rg -q 'ABYSS_CONFIRMATION_MULTI_OUTPUT_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log"; then
    cat "$test_root/runtime.log"
    exit 1
fi

printf 'PASS: two-output source affinity and requested-output fallback\n'
