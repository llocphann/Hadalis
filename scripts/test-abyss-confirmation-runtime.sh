#!/usr/bin/env bash
# Runtime acceptance harness for the Abyss confirmation presenter. This uses
# real StyledPopup/Abyss popup slots and the real ConfirmationService callbacks,
# but only synthetic test requests; application-native interception remains out
# of scope until a backend can supply trustworthy semantics.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for token in     'StyledPopup {'     'liquidPresentationKind: "confirmation"'     'exclusiveKeyboardFocus: true'; do
    grep -Fq "$token" "$repo_root/modules/abyss/AbyssConfirmationPresenter.qml"         || { printf 'FAIL: confirmation presenter contract missing: %s\n' "$token" >&2; exit 1; }
done

if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss confirmation runtime (Quickshell/Wayland unavailable)\n'
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
//@ pragma ShellId hadalis-abyss-confirmation-runtime-test
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.bar
import qs.modules.abyss

ShellRoot {
    id: root

    property int phase: 0
    property bool finished: false
    property int acceptedCallbacks: 0
    property bool showPeer: false
    property var confirmationPopup: null
    property int queuedFirstId: 0
    property int queuedSecondId: 0
    property int reopenedId: 0
    readonly property string outputName:
        String(window.screen?.name ?? "")

    function check(ok, message): bool {
        if (ok)
            return true
        console.error("ABYSS_CONFIRMATION_RUNTIME_FAIL", message)
        root.finished = true
        return false
    }

    function requestDirect(edge, longContent = false): void {
        sourceAnchor.attachedEdge = edge
        ConfirmationService.enqueue({
            owner: "runtime-test",
            anchorItem: sourceAnchor,
            anchorKind: "direct",
            title: longContent
                ? "A deliberately long confirmation title that must wrap without widening the connected popup beyond its content cap"
                : "Confirm action?",
            message: longContent
                ? "This is a deliberately long message used to verify content-fit wrapping inside the existing Abyss popup surface geometry rather than a fixed standalone dialog."
                : "Runtime confirmation request",
            details: longContent
                ? "Synthetic runtime acceptance request. No external action is performed."
                : "",
            actions: [
                {
                    id: "cancel",
                    label: "Cancel",
                    role: "cancel",
                    isCancel: true
                },
                {
                    id: "accept",
                    label: longContent
                        ? "Accept this deliberately long action label"
                        : "Accept",
                    role: "default",
                    isDefault: true,
                    callback: () => root.acceptedCallbacks += 1
                }
            ]
        })
    }

    function requestIdentity(): void {
        ConfirmationService.enqueue({
            owner: "runtime-test",
            appId: "runtime.app",
            title: "Identity routed confirmation",
            message: "Use the highest-priority live source anchor.",
            actions: [
                { id: "cancel", label: "Cancel", role: "cancel", isCancel: true },
                { id: "accept", label: "Accept", role: "default", isDefault: true }
            ]
        })
    }

    function requestFallback(): void {
        ConfirmationService.enqueue({
            owner: "runtime-test",
            outputName: root.outputName,
            title: "Fallback confirmation",
            message: "No source application anchor is available.",
            actions: [
                { id: "cancel", label: "Cancel", role: "cancel", isCancel: true },
                { id: "accept", label: "Accept", role: "default", isDefault: true }
            ]
        })
    }

    function requestApp(appId, title): int {
        return ConfirmationService.enqueue({
            owner: "runtime-test",
            appId: appId,
            outputName: root.outputName,
            title: title,
            message: "Runtime queued/reopen confirmation request.",
            actions: [
                { id: "cancel", label: "Cancel", role: "cancel", isCancel: true },
                { id: "accept", label: "Accept", role: "default", isDefault: true }
            ]
        })
    }

    AbyssSurfaceController {
        id: controller
        outputName: root.outputName
        presentationItem: scene
        outputWidth: scene.width
        outputHeight: scene.height
        edgeInsets: ({ left: 16, top: 16, right: 16, bottom: 16 })
    }

    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1200
        implicitHeight: 900

        Item {
            id: scene
            anchors.fill: parent

            MouseArea {
                id: sourceAnchor
                property var liquidController: controller
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: attachedEdge === "right" ? scene.width-width
                    : attachedEdge === "left" ? 0 : 540
                y: attachedEdge === "bottom" ? scene.height-height
                    : attachedEdge === "top" ? 0 : 330
                width: 42
                height: 42
                visible: true
                enabled: true
            }

            MouseArea {
                id: trayAnchor
                property var liquidController: controller
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: 680
                y: 0
                width: 36
                height: 36
                visible: true
                enabled: true
            }

            MouseArea {
                id: dockAnchor
                property var liquidController: controller
                property string attachedEdge: "bottom"
                property string popupJoinedEdge: ""
                x: 680
                y: scene.height-height
                width: 44
                height: 44
                visible: true
                enabled: true
            }

            // Model a resident AbyssBodyHost whose loaded child still exists
            // after the source surface has fully closed. It must never resolve.
            Item {
                id: hiddenResidentHost
                property var liquidController: controller
                property string attachedEdge: "bottom"
                property bool visualResident: false
                x: 760
                y: scene.height-height
                width: 44
                height: 44
                visible: true
                enabled: true

                MouseArea {
                    id: hiddenResidentAnchor
                    anchors.fill: parent
                    visible: true
                    enabled: true
                }
            }

            MouseArea {
                id: peerAnchor
                property var liquidController: controller
                property string attachedEdge: "top"
                x: 600
                y: 0
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
                x: (scene.width-width)/2
                y: 0
                width: 8
                height: 8
                visible: true
                enabled: true
            }

            Repeater {
                model: controller.popupCapacity

                delegate: AbyssBodyHost {
                    id: host
                    required property int index
                    readonly property var popupEntry:
                        controller.popupSlots[index] ?? null
                    readonly property var hostedPopup:
                        popupEntry?.popup ?? null
                    readonly property bool horizontalEdge:
                        edge === "top" || edge === "bottom"
                    readonly property rect anchorBounds:
                        hostedPopup?._anchorRect(scene.width, scene.height)
                            ?? Qt.rect(0, 0, 0, 0)

                    anchors.fill: parent
                    identity: "styledPopup" + index
                    controller: controller
                    stackPolicy: "pyramid"
                    semanticOpenOverride:
                        hostedPopup?.liquidSemanticVisible ?? false
                    edge: hostedPopup?._attachmentEdge ?? "top"
                    joinedEdge:
                        hostedPopup?._liquidAnchor?.popupJoinedEdge ?? ""
                    open: hostedPopup?.presentationActive ?? false
                    externalProgress: hostedPopup?.revealProgress ?? 0
                    embeddedItem: hostedPopup?.contentItem ?? null
                    padding: 14
                    span: (horizontalEdge
                        ? (embeddedItem?.implicitWidth ?? 1)
                        : (embeddedItem?.implicitHeight ?? 1)) + padding*2
                    depth: (horizontalEdge
                        ? (embeddedItem?.implicitHeight ?? 1)
                        : (embeddedItem?.implicitWidth ?? 1)) + padding*2
                    along: (horizontalEdge
                        ? anchorBounds.x + anchorBounds.width/2
                        : anchorBounds.y + anchorBounds.height/2) - span/2
                    edgeInsets: controller.edgeInsets

                    onPopupEntryChanged: {
                        retainedPlacement = null
                        resetPyramidMotion()
                    }
                    Component.onCompleted:
                        controller.registerPopupHost(index, host)
                    Component.onDestruction:
                        controller.unregisterPopupHost(index, host)
                }
            }
        }
    }

    StyledPopup {
        id: peerPopup
        hoverTarget: peerAnchor
        hoverActivates: false
        alternativeVisibleCondition: root.showPeer
        closeOnOutsideClick: false

        Item {
            implicitWidth: 270
            implicitHeight: 120
        }
    }

    AbyssConfirmationPresenter {
        outputName: root.outputName
        fallbackAnchor: fallbackAnchor
        presentationEnabled: true
    }

    Timer {
        interval: 260
        repeat: true
        running: !root.finished

        onTriggered: {
            if (!Config.ready || root.outputName.length === 0)
                return

            if (root.phase === 0) {
                Config.setNestedValue("panelFamily", "abyss")
                PopupAnchorRegistry.registerAnchor(
                    trayAnchor, "tray", () => ["runtime.app"], 300)
                PopupAnchorRegistry.registerAnchor(
                    dockAnchor, "dock", () => ["runtime.app"], 200)
                sourceAnchor.popupJoinedEdge = "left"
                root.requestDirect("top", true)
                root.phase = 1
                return
            }

            if (root.phase === 1) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                const popup = controller.activePopup
                if (!root.check(
                        ConfirmationService.resolvedAnchor === sourceAnchor,
                        "direct source Item owns confirmation placement"))
                    return
                if (!root.check(popup._attachmentEdge === "top",
                        "top source keeps top attachment"))
                    return
                if (!root.check(
                        popup.contentItem.implicitWidth >= 260
                        && popup.contentItem.implicitWidth <= 460,
                        "long confirmation content stays within content-fit width cap"))
                    return
                const slot = controller._popupSlot(popup)
                const host = controller.popupHosts[String(slot)] ?? null
                if (!root.check(host?.joinedEdge === "left",
                        "confirmation inherits source Join Edge"))
                    return
                sourceAnchor.popupJoinedEdge = ""
                ConfirmationService.resolve("accept")
                root.phase = 2
                return
            }

            if (root.phase === 2) {
                if (ConfirmationService.active)
                    return
                if (!root.check(root.acceptedCallbacks === 1,
                        "real confirmation callback executes exactly once"))
                    return
                root.requestDirect("bottom")
                root.phase = 3
                return
            }

            if (root.phase === 3) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(controller.activePopup._attachmentEdge === "bottom",
                        "bottom source keeps bottom attachment"))
                    return
                ConfirmationService.cancel()
                root.phase = 4
                return
            }

            if (root.phase === 4) {
                if (ConfirmationService.active)
                    return
                root.requestDirect("left")
                root.phase = 5
                return
            }

            if (root.phase === 5) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(controller.activePopup._attachmentEdge === "left",
                        "left source keeps left attachment"))
                    return
                ConfirmationService.cancel()
                root.phase = 6
                return
            }

            if (root.phase === 6) {
                if (ConfirmationService.active)
                    return
                root.requestDirect("right")
                root.phase = 7
                return
            }

            if (root.phase === 7) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(controller.activePopup._attachmentEdge === "right",
                        "right source keeps right attachment"))
                    return
                ConfirmationService.cancel()
                root.phase = 8
                return
            }

            if (root.phase === 8) {
                if (ConfirmationService.active)
                    return
                root.requestIdentity()
                root.phase = 9
                return
            }

            if (root.phase === 9) {
                if (!ConfirmationService.requestVisible)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === trayAnchor,
                        "tray source outranks dock source for the same app identity"))
                    return
                ConfirmationService.cancel()
                root.phase = 10
                return
            }

            if (root.phase === 10) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.unregisterAnchor(trayAnchor)
                root.requestIdentity()
                root.phase = 11
                return
            }

            if (root.phase === 11) {
                if (!ConfirmationService.requestVisible)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === dockAnchor,
                        "dock source is used when the tray source is absent"))
                    return
                ConfirmationService.cancel()
                root.phase = 12
                return
            }

            if (root.phase === 12) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.unregisterAnchor(dockAnchor)
                root.requestFallback()
                root.phase = 13
                return
            }

            if (root.phase === 13) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(ConfirmationService.resolvedAnchor === null,
                        "unresolved source keeps request on fallback path"))
                    return
                if (!root.check(
                        controller.activePopup.hoverTarget === fallbackAnchor
                        && controller.activePopup._attachmentEdge === "top",
                        "fallback uses the output top-center Abyss anchor"))
                    return
                ConfirmationService.cancel()
                root.phase = 14
                return
            }

            if (root.phase === 14) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.registerAnchor(
                    trayAnchor, "tray", () => ["runtime.app"], 300)
                root.requestIdentity()
                root.phase = 15
                return
            }

            if (root.phase === 15) {
                if (!ConfirmationService.requestVisible)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === trayAnchor,
                        "source-removal case begins attached"))
                    return
                PopupAnchorRegistry.unregisterAnchor(trayAnchor)
                root.phase = 16
                return
            }

            if (root.phase === 16) {
                if (ConfirmationService.active)
                    return
                if (!root.check(!ConfirmationService.requestVisible,
                        "source disappearance cancels instead of teleporting"))
                    return
                root.showPeer = true
                root.phase = 17
                return
            }

            if (root.phase === 17) {
                if (!peerPopup.presentationActive
                        || controller.activePopups.length < 1)
                    return
                sourceAnchor.attachedEdge = "top"
                root.requestDirect("top")
                root.phase = 18
                return
            }

            if (root.phase === 18) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 2)
                    return
                root.confirmationPopup = controller.activePopup
                if (!root.check(
                        root.confirmationPopup !== peerPopup
                        && root.confirmationPopup.presentationActive,
                        "confirmation coexists with an existing popup"))
                    return
                root.showPeer = false
                root.phase = 19
                return
            }

            if (root.phase === 19) {
                if (!root.check(
                        ConfirmationService.requestVisible
                        && root.confirmationPopup?.presentationActive,
                        "confirmation survives peer retract/reflow"))
                    return
                ConfirmationService.cancel()
                root.phase = 20
                return
            }

            if (root.phase === 20) {
                if (ConfirmationService.active || peerPopup.presentationActive)
                    return
                PopupAnchorRegistry.registerAnchor(
                    trayAnchor, "tray", () => ["runtime.app"], 300)
                root.queuedFirstId =
                    root.requestApp("runtime.app", "Queued first")
                root.queuedSecondId =
                    root.requestApp("runtime.app", "Queued second")
                if (!root.check(
                        ConfirmationService.currentRequestId
                            === root.queuedFirstId
                        && ConfirmationService.queue.length === 1,
                        "second confirmation queues behind the active request"))
                    return
                root.phase = 21
                return
            }

            if (root.phase === 21) {
                if (!ConfirmationService.requestVisible
                        || ConfirmationService.currentRequestId
                            !== root.queuedFirstId)
                    return
                ConfirmationService.cancel()
                root.phase = 22
                return
            }

            if (root.phase === 22) {
                if (!ConfirmationService.requestVisible
                        || ConfirmationService.currentRequestId
                            !== root.queuedSecondId)
                    return
                if (!root.check(ConfirmationService.queue.length === 0,
                        "queued confirmation activates after predecessor release"))
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === trayAnchor,
                        "queued request resolves its own live source anchor"))
                    return
                ConfirmationService.cancel()
                root.phase = 23
                return
            }

            if (root.phase === 23) {
                if (ConfirmationService.active)
                    return
                root.reopenedId =
                    root.requestApp("runtime.app", "Reopened confirmation")
                root.phase = 24
                return
            }

            if (root.phase === 24) {
                if (!ConfirmationService.requestVisible
                        || ConfirmationService.currentRequestId
                            !== root.reopenedId)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === trayAnchor,
                        "closed confirmation can reopen on the same source"))
                    return
                ConfirmationService.cancel()
                root.phase = 25
                return
            }

            if (root.phase === 25) {
                if (ConfirmationService.active)
                    return
                PopupAnchorRegistry.unregisterAnchor(trayAnchor)
                PopupAnchorRegistry.unregisterAnchor(dockAnchor)
                PopupAnchorRegistry.registerAnchor(
                    hiddenResidentAnchor, "dock",
                    () => ["hidden.runtime.app"], 200)
                root.requestApp(
                    "hidden.runtime.app", "Hidden resident source")
                root.phase = 26
                return
            }

            if (root.phase === 26) {
                if (!ConfirmationService.requestVisible
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor === null
                        && controller.activePopup.hoverTarget === fallbackAnchor,
                        "closed resident source is ignored for top-center fallback"))
                    return
                ConfirmationService.cancel()
                root.phase = 27
                return
            }

            if (root.phase === 27) {
                if (ConfirmationService.active)
                    return
                // A source can remain registered while its resident host stops
                // being presented. The active request must reject instead of
                // hanging on stale geometry or teleporting to fallback.
                hiddenResidentHost.visualResident = true
                root.requestApp(
                    "hidden.runtime.app", "Source will disappear")
                root.phase = 28
                return
            }

            if (root.phase === 28) {
                if (!ConfirmationService.requestVisible)
                    return
                if (!root.check(
                        ConfirmationService.resolvedAnchor
                            === hiddenResidentAnchor,
                        "presented resident source resolves while live"))
                    return
                hiddenResidentHost.visualResident = false
                root.phase = 29
                return
            }

            if (root.phase === 29) {
                if (ConfirmationService.active)
                    return
                if (!root.check(!ConfirmationService.requestVisible,
                        "registered source becoming non-presented cancels without teleport"))
                    return
                PopupAnchorRegistry.unregisterAnchor(hiddenResidentAnchor)
                console.info("ABYSS_CONFIRMATION_RUNTIME_PASS")
                root.finished = true
            }
        }
    }
}
QML

status=0
env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST     QT_QPA_PLATFORM=wayland     XDG_CONFIG_HOME="$test_root/config"     XDG_STATE_HOME="$test_root/state"     XDG_CACHE_HOME="$test_root/cache"     timeout 20s qs -p "$test_root" --no-color     > "$test_root/runtime.log" 2>&1 || status=$?

if [[ "$status" != 124 ]]         || ! rg -q 'ABYSS_CONFIRMATION_RUNTIME_PASS' "$test_root/runtime.log"         || rg -q 'ABYSS_CONFIRMATION_RUNTIME_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log"; then
    cat "$test_root/runtime.log"
    exit 1
fi

printf 'PASS: confirmation callbacks, content-fit, four-edge attachment, Join Edge inheritance, tray/dock routing, top-center fallback, source loss, peer reflow, queue/reopen, hidden-resident fallback and live-anchor invalidation\n'
