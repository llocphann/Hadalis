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

for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$test_root/$entry"
done
mkdir -p "$test_root/config/illogical-impulse" "$test_root/state" "$test_root/cache"
cp "$repo_root/defaults/config.json" "$test_root/config/illogical-impulse/config.json"

cat > "$test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-confirmation-multi-output-runtime-test
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss
import qs.modules.bar

ShellRoot {
    id: root

    property bool finished: false
    property int phase: 0
    property int preconditionTicks: 0
    property var surfaces: []

    function check(ok, message): bool {
        if (ok)
            return true
        console.error("ABYSS_CONFIRMATION_MULTI_OUTPUT_FAIL", message)
        root.finished = true
        return false
    }

    function registerSurface(surface): void {
        if (!surface)
            return
        const next = root.surfaces.filter(candidate => candidate !== surface)
        next.push(surface)
        next.sort((left, right) =>
            String(left?.outputName ?? "").localeCompare(
                String(right?.outputName ?? "")))
        root.surfaces = next
    }

    function unregisterSurface(surface): void {
        root.surfaces = root.surfaces.filter(candidate => candidate !== surface)
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

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: surface
            required property ShellScreen modelData
            readonly property string outputName: String(modelData?.name ?? "")
            property bool carrierActive: false
            readonly property var controllerRef: carrier.item?.controllerRef ?? null
            readonly property var trayRef: carrier.item?.trayRef ?? null
            readonly property var dockRef: carrier.item?.dockRef ?? null
            readonly property var fallbackRef: carrier.item?.fallbackRef ?? null

            Component.onCompleted: root.registerSurface(surface)
            Component.onDestruction: root.unregisterSurface(surface)

            Loader {
                id: carrier
                active: surface.carrierActive
                sourceComponent: Component {
                    Scope {
                        id: carrierRoot
                        readonly property var controllerRef: controller
                        readonly property var trayRef: trayAnchor
                        readonly property var dockRef: dockAnchor
                        readonly property var fallbackRef: fallbackAnchor

                        FloatingWindow {
                            id: window
                            visible: true
                            screen: surface.modelData
                            implicitWidth: 720
                            implicitHeight: 520

                            Item {
                                id: scene
                                anchors.fill: parent

                                Item {
                                    id: trayAnchor
                                    property var liquidController: controller
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
                                    id: dockAnchor
                                    property var liquidController: controller
                                    property string attachedEdge: "bottom"
                                    property string popupJoinedEdge: ""
                                    x: 120
                                    y: scene.height - height
                                    width: 40
                                    height: 40
                                    visible: true
                                    enabled: true
                                }

                                Item {
                                    id: fallbackAnchor
                                    property var liquidController: controller
                                    property string attachedEdge: "top"
                                    property string popupJoinedEdge: ""
                                    x: (scene.width - width) / 2
                                    y: 0
                                    width: 1
                                    height: 1
                                    visible: true
                                    enabled: true
                                }
                            }
                        }

                        AbyssSurfaceController {
                            id: controller
                            outputName: surface.outputName
                            presentationItem: scene
                            outputWidth: scene.width
                            outputHeight: scene.height
                            edgeInsets: ({ left: 12, top: 12, right: 12, bottom: 12 })
                        }

                        AbyssConfirmationPresenter {
                            outputName: surface.outputName
                            fallbackAnchor: fallbackAnchor
                            presentationEnabled: true
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 260
        repeat: true
        running: !root.finished

        onTriggered: {
            root.preconditionTicks += 1
            if (!Config.ready || root.surfaces.length < 2) {
                if (root.preconditionTicks >= 12) {
                    const names = root.surfaces.map(surface =>
                        String(surface?.outputName ?? ""))
                    root.check(false,
                        "runtime preconditions unavailable: Config.ready="
                        + Config.ready + " surfaces=" + root.surfaces.length
                        + " names=" + JSON.stringify(names))
                }
                return
            }

            const one = root.surfaces[0]
            const two = root.surfaces[1]
            if (!one || !two
                    || !one.outputName || !two.outputName
                    || one.outputName === two.outputName) {
                root.check(false,
                    "Wayland compositor must expose two distinct outputs")
                return
            }

            if (root.phase === 0) {
                // Delay platform-window creation until Quickshell has entered
                // the event loop and enumerated both ShellScreen objects.
                one.carrierActive = true
                root.phase = 1
                return
            }

            if (root.phase === 1) {
                if (!one.controllerRef)
                    return
                two.carrierActive = true
                root.phase = 2
                return
            }

            if (root.phase === 2) {
                if (!one.controllerRef || !two.controllerRef
                        || !one.trayRef || !two.dockRef)
                    return
                Config.setNestedValue("panelFamily", "abyss")
                PopupAnchorRegistry.registerAnchor(
                    one.trayRef, "tray", () => ["multi.runtime.app"], 300)
                PopupAnchorRegistry.registerAnchor(
                    two.dockRef, "dock", () => ["multi.runtime.app"], 200)
                root.request(
                    "multi.runtime.app", two.outputName,
                    "Prefer same-output Dock over remote Tray")
                root.phase = 3
                return
            }

            if (root.phase === 3) {
                if (!ConfirmationService.requestVisible
                        || two.controllerRef.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === two.outputName
                        && ConfirmationService.resolvedAnchor === two.dockRef,
                        "same-output affinity outranks a higher-priority remote surface"))
                    return
                if (!root.check(
                        two.controllerRef.activePopup?.hoverTarget === two.dockRef
                        && one.controllerRef.activePopups.length === 0,
                        "connected popup is presented only on requested output"))
                    return
                ConfirmationService.cancel()
                root.phase = 4
                return
            }

            if (root.phase === 4) {
                if (ConfirmationService.active)
                    return
                root.request(
                    "multi.runtime.app", one.outputName,
                    "Prefer local Tray on first output")
                root.phase = 5
                return
            }

            if (root.phase === 5) {
                if (!ConfirmationService.requestVisible
                        || one.controllerRef.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === one.outputName
                        && ConfirmationService.resolvedAnchor === one.trayRef,
                        "first-output request resolves its local Tray source"))
                    return
                ConfirmationService.cancel()
                root.phase = 6
                return
            }

            if (root.phase === 6) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.unregisterAnchor(one.trayRef)
                PopupAnchorRegistry.unregisterAnchor(two.dockRef)
                root.request("", two.outputName, "Second-output fallback")
                root.phase = 7
                return
            }

            if (root.phase === 7) {
                if (!ConfirmationService.requestVisible
                        || two.controllerRef.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.targetOutputName === two.outputName
                        && ConfirmationService.resolvedAnchor === null
                        && two.controllerRef.activePopup?.hoverTarget === two.fallbackRef
                        && one.controllerRef.activePopups.length === 0,
                        "unresolved request uses top-center fallback on requested output"))
                    return
                ConfirmationService.cancel()
                root.phase = 8
                return
            }

            if (root.phase === 8) {
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
