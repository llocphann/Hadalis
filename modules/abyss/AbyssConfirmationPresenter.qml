pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.abyss.content

// One presenter per output. StyledPopup discovers the real source Item's
// liquidController/attachedEdge, so all geometry and Pyramid motion remain
// owned by the existing connected-surface architecture.
Item {
    id: root

    required property string outputName
    required property Item fallbackAnchor
    property bool presentationEnabled: true

    readonly property var request: ConfirmationService.currentRequest
    readonly property int requestId:
        Number(root.request?._requestId ?? 0)
    readonly property bool ownsRequest:
        root.request !== null
        && ConfirmationService.targetOutputName === root.outputName
    readonly property bool hadResolvedAnchor:
        root.request?._hadResolvedAnchor === true
    // Never substitute the fallback during an attached request's teardown.
    // If the source Item disappears, ConfirmationService cancels the request
    // and this becomes null, preventing an in-flight teleport to top center.
    readonly property Item presentationAnchor:
        !root.ownsRequest ? null
        : root.hadResolvedAnchor
            ? ConfirmationService.resolvedAnchor
            : root.fallbackAnchor

    function scheduleFinish(requestId): void {
        const id = Number(requestId)
        if (id <= 0)
            return
        // Let all bindings/registry handlers for this QML turn settle before
        // releasing queue ownership. A renderer failover can establish its
        // semantic hold in that same turn without racing the retract callback.
        Qt.callLater(() => ConfirmationService.finishPresentation(id))
    }

    function finishIfReleased(): void {
        if (!popup.presentationActive
                && root.ownsRequest
                && !ConfirmationService.requestVisible)
            root.scheduleFinish(root.requestId)
    }

    Connections {
        target: ConfirmationService
        function onRequestVisibleChanged(): void {
            root.finishIfReleased()
        }
    }

    Component.onDestruction: {
        // Output hotplug/family teardown can destroy the owning presenter after
        // semantic close but before StyledPopup emits its final tail signal.
        if (root.ownsRequest && !ConfirmationService.requestVisible)
            root.scheduleFinish(root.requestId)
    }

    StyledPopup {
        id: popup
        hoverTarget: root.presentationAnchor
        hoverActivates: false
        alternativeVisibleCondition:
            root.presentationEnabled
            && root.ownsRequest
            && ConfirmationService.requestVisible
            && !PolkitService.active
        liquidPresentationKind: "confirmation"
        popupBackgroundMargin: 0
        closeOnOutsideClick: false
        keyboardFocus: true
        exclusiveKeyboardFocus: true

        onRequestClose: ConfirmationService.cancel()

        onPresentationActiveChanged: {
            if (popup.presentationActive && root.ownsRequest)
                ConfirmationService.markPresentationStarted(root.requestId)
            root.finishIfReleased()
        }

        AbyssConfirmationContent {
            request: root.request
        }
    }
}
