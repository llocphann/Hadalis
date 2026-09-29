pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.abyss.content

// Polkit keeps its real Quickshell AuthFlow backend. This object only presents
// that flow through the same StyledPopup/Abyss/Pyramid path as other prompts.
Item {
    id: root

    required property string outputName
    required property Item fallbackAnchor
    property bool presentationEnabled: true

    readonly property bool ownsOutput:
        PolkitService.targetOutputName.length > 0
        && PolkitService.targetOutputName === root.outputName
    readonly property Item presentationAnchor:
        !root.ownsOutput ? null
        : PolkitService.hadResolvedAnchor
            ? PolkitService.resolvedAnchor
            : root.fallbackAnchor

    readonly property var liveModel: ({
        requestSerial: PolkitService.requestSerial,
        title: Translation.tr("Authentication required"),
        actionLabel: PolkitService.actionLabel,
        message: PolkitService.cleanMessage,
        prompt: PolkitService.cleanPrompt,
        responseVisible: PolkitService.responseVisible,
        responseRequired: PolkitService.responseRequired,
        interactionAvailable: PolkitService.interactionAvailable,
        busy: PolkitService.busy,
        failed: PolkitService.failed,
        supplementaryMessage: PolkitService.supplementaryMessage,
        supplementaryIsError: PolkitService.supplementaryIsError,
        identityLabel: PolkitService.identityLabel,
        identityCount: Number(PolkitService.identities?.length ?? 0),
        details: PolkitService.detailsText,
        iconName: PolkitService.iconName
    })
    property var latchedModel: ({})

    function captureLiveModel(): void {
        if (PolkitService.active)
            root.latchedModel = Object.assign({}, root.liveModel)
    }

    onLiveModelChanged: root.captureLiveModel()
    Component.onCompleted: root.captureLiveModel()

    StyledPopup {
        id: popup
        hoverTarget: root.presentationAnchor
        hoverActivates: false
        alternativeVisibleCondition:
            root.presentationEnabled && root.ownsOutput
            && PolkitService.available && PolkitService.active
        liquidPresentationKind: "polkit"
        popupBackgroundMargin: 0
        closeOnOutsideClick: false
        keyboardFocus: true
        exclusiveKeyboardFocus: true

        onRequestClose: PolkitService.cancel()
        onPresentationActiveChanged: {
            if (!presentationActive && !PolkitService.active) {
                root.latchedModel = ({})
                PolkitService.finishPresentation()
            }
        }

        Component.onDestruction: {
            if (!PolkitService.active)
                PolkitService.finishPresentation()
        }

        AbyssPolkitContent {
            model: root.latchedModel
        }
    }
}
