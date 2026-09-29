#!/usr/bin/env bash
# Real Polkit/AuthFlow runtime acceptance for the Abyss presenter.
#
# This must run inside a real logind session with a temporary CI user whose
# password is supplied through HADALIS_POLKIT_CI_TOKEN. The workflow provisions
# a disposable auth_self PolicyKit action; no production credential is used.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v qs >/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'SKIP: Abyss Polkit runtime (Quickshell/Wayland unavailable)\n'
    exit 0
fi
if ! command -v pkcheck >/dev/null; then
    printf 'SKIP: Abyss Polkit runtime (pkcheck unavailable)\n'
    exit 0
fi
if [[ -z "${HADALIS_POLKIT_CI_TOKEN:-}" ]]; then
    printf 'FAIL: HADALIS_POLKIT_CI_TOKEN is required for the disposable CI identity\n' >&2
    exit 1
fi

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
for entry in modules services GlobalStates.qml qmldir assets scripts defaults translations; do
    ln -s "$repo_root/$entry" "$test_root/$entry"
done
mkdir -p "$test_root/config/illogical-impulse"
cp "$repo_root/defaults/config.json" "$test_root/config/illogical-impulse/config.json"

cat > "$test_root/shell.qml" <<'QML'
//@ pragma ShellId hadalis-abyss-polkit-runtime-test
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss

ShellRoot {
    id: root

    property int phase: 0
    property int ticks: 0
    property bool finished: false
    property int firstSerial: 0
    property int cancelExitCode: -999
    property int queuedSuccesses: 0
    property int queuedFailures: 0
    readonly property string token:
        String(Quickshell.env("HADALIS_POLKIT_CI_TOKEN") ?? "")
    readonly property string outputName:
        String(window.screen?.name ?? "")

    function check(ok, message): bool {
        if (ok)
            return true
        console.error("ABYSS_POLKIT_RUNTIME_FAIL", message)
        root.finished = true
        return false
    }

    function authCommand(actionId = "org.hadalis.ci.authenticate"): var {
        return [
            "/bin/bash", "-c",
            "exec /usr/bin/pkcheck --action-id "
                + actionId
                + " --process $$ --allow-user-interaction"
        ]
    }

    function start(proc, actionId = "org.hadalis.ci.authenticate"): void {
        proc.command = root.authCommand(actionId)
        proc.running = true
    }

    // Weston headless intentionally does not expose wlr-layer-shell. Use a
    // real Wayland xdg-toplevel with deterministic geometry here, exactly as the
    // confirmation runtime harness does. The connected controller still proves
    // exclusive-focus ownership; compositor layer-shell focus is covered by the
    // nested-Niri confirmation lane rather than faked on an unsupported protocol.
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1200
        implicitHeight: 900
        color: "transparent"

        Item {
            id: scene
            anchors.fill: parent

            Item {
                id: fallbackAnchor
                property var liquidController: controller
                property string attachedEdge: "top"
                property string popupJoinedEdge: ""
                x: (scene.width - width) / 2
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
                        : (embeddedItem?.implicitHeight ?? 1)) + padding * 2
                    depth: (horizontalEdge
                        ? (embeddedItem?.implicitHeight ?? 1)
                        : (embeddedItem?.implicitWidth ?? 1)) + padding * 2
                    along: (horizontalEdge
                        ? anchorBounds.x + anchorBounds.width / 2
                        : anchorBounds.y + anchorBounds.height / 2) - span / 2
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

    AbyssSurfaceController {
        id: controller
        outputName: root.outputName
        presentationItem: scene
        outputWidth: scene.width
        outputHeight: scene.height
        edgeInsets: ({ left: 12, top: 12, right: 12, bottom: 12 })
    }

    AbyssPolkitPresenter {
        outputName: root.outputName
        fallbackAnchor: fallbackAnchor
        presentationEnabled: true
    }

    function syncPromptHost(): void {
        if (root.outputName.length > 0)
            AbyssPromptHostRegistry.registerHost(window, root.outputName)
    }
    Component.onCompleted: root.syncPromptHost()
    Component.onDestruction: AbyssPromptHostRegistry.unregisterHost(window)
    onOutputNameChanged: root.syncPromptHost()

    Process {
        id: firstAuth
        property bool done: false
        property int result: -999
        onExited: (exitCode, exitStatus) => {
            firstAuth.result = exitCode
            firstAuth.done = true
        }
    }

    Process {
        id: cancelAuth
        property bool done: false
        onExited: (exitCode, exitStatus) => {
            root.cancelExitCode = exitCode
            cancelAuth.done = true
        }
    }

    Process {
        id: queueA
        property bool done: false
        onExited: (exitCode, exitStatus) => {
            queueA.done = true
            if (exitCode === 0)
                root.queuedSuccesses += 1
            else
                root.queuedFailures += 1
        }
    }

    Process {
        id: queueB
        property bool done: false
        onExited: (exitCode, exitStatus) => {
            queueB.done = true
            if (exitCode === 0)
                root.queuedSuccesses += 1
            else
                root.queuedFailures += 1
        }
    }

    Timer {
        interval: 180
        repeat: true
        running: !root.finished

        onTriggered: {
            root.ticks += 1
            if (root.ticks >= 180) {
                root.check(false,
                    "timeout phase=" + root.phase
                    + " available=" + PolkitService.available
                    + " registered=" + PolkitService.registered
                    + " active=" + PolkitService.active
                    + " serial=" + PolkitService.requestSerial
                    + " retained=" + PolkitService.presentationRetained
                    + " canSubmit=" + PolkitService.canSubmit
                    + " failed=" + PolkitService.failed
                    + " firstAuthDone=" + firstAuth.done
                    + " firstAuthResult=" + firstAuth.result
                    + " queuedSuccesses=" + root.queuedSuccesses
                    + " queuedFailures=" + root.queuedFailures
                    + " queueADone=" + queueA.done
                    + " queueBDone=" + queueB.done
                    + " popups=" + controller.activePopups.length
                    + " popupTargetOk="
                        + (controller.activePopup?.hoverTarget === fallbackAnchor)
                    + " exclusiveFocus=" + controller.popupExclusiveFocus
                    + " focusOwner=" + (controller.popupFocusOwner !== null))
                return
            }

            if (!Config.ready || root.outputName.length === 0
                    || Object.keys(controller.popupHosts ?? {}).length
                        < controller.popupCapacity)
                return

            if (root.phase === 0) {
                Config.setNestedValue("panelFamily", "abyss")
                if (!PolkitService.available || !PolkitService.registered)
                    return
                // Before an AuthFlow starts, PolkitService has no target output
                // yet, so abyssPresenterAvailable is intentionally false. Check
                // the concrete frame-ready host here; the service-level
                // availability is asserted after the AuthFlow latches output.
                if (!root.check(
                        PolkitService.abyssConfigured
                        && AbyssPromptHostRegistry.hasOutput(root.outputName),
                        "live Abyss prompt host is ready for real Polkit"))
                    return
                root.start(firstAuth)
                root.phase = 1
                return
            }

            if (root.phase === 1) {
                if (firstAuth.done && !PolkitService.active) {
                    root.check(false,
                        "initial pkcheck exited before AuthFlow result="
                        + firstAuth.result)
                    return
                }
                if (!PolkitService.active || !PolkitService.canSubmit
                        || !PolkitService.presentationMatchesActive
                        || controller.activePopups.length < 1)
                    return
                if (!root.check(
                        PolkitService.abyssPresenterAvailable,
                        "active AuthFlow owns a live Abyss prompt host"))
                    return
                if (!root.check(
                        PolkitService.resolvedAnchor === null
                        && PolkitService.targetOutputName === root.outputName,
                        "ordinary real AuthFlow uses requested-output top-center fallback"))
                    return

                // Popup registration precedes the first body placement/input-
                // bounds update by one or more QML turns. Focus ownership is
                // intentionally geometry-gated in AbyssSurfaceController, so
                // wait for the connected body to become focus-eligible instead
                // of treating that normal registration/layout gap as failure.
                if (controller.activePopup?.hoverTarget !== fallbackAnchor
                        || !controller.popupExclusiveFocus)
                    return

                root.firstSerial = PolkitService.requestSerial
                PolkitService.submit("wrong-hadalis-ci-token")
                root.phase = 2
                return
            }

            if (root.phase === 2) {
                if (!PolkitService.active || !PolkitService.failed
                        || !PolkitService.canSubmit)
                    return
                if (!root.check(
                        PolkitService.requestSerial === root.firstSerial,
                        "wrong password retries inside the same AuthFlow request"))
                    return
                PolkitService.submit(root.token)
                root.phase = 3
                return
            }

            if (root.phase === 3) {
                if (!firstAuth.done || PolkitService.active)
                    return
                if (!root.check(firstAuth.result === 0,
                        "correct response completes real PolicyKit authorization"))
                    return
                root.start(cancelAuth)
                root.phase = 4
                return
            }

            if (root.phase === 4) {
                if (!PolkitService.active || !PolkitService.canSubmit)
                    return
                PolkitService.cancel()
                root.phase = 5
                return
            }

            if (root.phase === 5) {
                if (!cancelAuth.done || PolkitService.active)
                    return
                if (!root.check(root.cancelExitCode !== 0,
                        "Cancel aborts the real PolicyKit authorization"))
                    return
                // Distinct actions prevent PolicyKit from coalescing two
                // concurrent checks for the exact same action/subject. That
                // makes this a deterministic test of PolkitAgent queue
                // activation rather than authorization-cache behavior.
                root.start(queueA, "org.hadalis.ci.authenticate.queuea")
                root.start(queueB, "org.hadalis.ci.authenticate.queueb")
                root.phase = 6
                return
            }

            if (root.phase === 6) {
                if (!PolkitService.active || !PolkitService.canSubmit)
                    return
                PolkitService.submit(root.token)
                root.phase = 7
                return
            }

            if (root.phase === 7) {
                if (root.queuedSuccesses < 1
                        || !PolkitService.active
                        || !PolkitService.canSubmit)
                    return
                PolkitService.submit(root.token)
                root.phase = 8
                return
            }

            if (root.phase === 8) {
                if (!queueA.done || !queueB.done || PolkitService.active)
                    return
                if (!root.check(
                        root.queuedSuccesses === 2
                        && root.queuedFailures === 0,
                        "two real PolicyKit requests serialize and both authorize"))
                    return
                if (!root.check(
                        PolkitService.requestSerial >= root.firstSerial + 3,
                        "Quickshell PolkitAgent remained queue authority"))
                    return
                console.info("ABYSS_POLKIT_RUNTIME_PASS")
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
    timeout 36s qs -p "$test_root" --no-color \
    > "$test_root/runtime.log" 2>&1 || status=$?

if [[ "$status" != 124 ]] \
        || ! rg -q 'ABYSS_POLKIT_RUNTIME_PASS' "$test_root/runtime.log" \
        || rg -q 'ABYSS_POLKIT_RUNTIME_FAIL|ReferenceError:|TypeError:|Binding loop|Unable to assign|is not a type' "$test_root/runtime.log"; then
    cat "$test_root/runtime.log"
    exit 1
fi

printf 'PASS: real Polkit wrong-response retry, success, cancel, queued AuthFlow activation/serialization and connected Abyss focus/fallback presentation\n'
