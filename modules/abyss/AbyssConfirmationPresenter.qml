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
            if (!presentationActive
                    && root.ownsRequest
                    && !ConfirmationService.requestVisible)
                ConfirmationService.finishPresentation(root.requestId)
        }

        AbyssConfirmationContent {
            request: root.request
        }
    }
}
