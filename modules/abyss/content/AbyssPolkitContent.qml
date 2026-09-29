pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.abyss.looks

FocusScope {
    id: root
    required property var model
    focus: true

    readonly property real minContentWidth: 300
    readonly property real maxContentWidth: 500
    readonly property string titleText:
        String(root.model?.title ?? Translation.tr("Authentication required"))
    readonly property string messageText:
        String(root.model?.message ?? "")
    readonly property string supplementaryText:
        String(root.model?.supplementaryMessage ?? "")
    readonly property string identityText:
        String(root.model?.identityLabel ?? "")
    readonly property string detailsText:
        String(root.model?.details ?? "")
    property bool detailsOpen: false

    readonly property real desiredWidth: Math.max(minContentWidth,
        Math.min(maxContentWidth, Math.max(
            titleMetrics.advanceWidth,
            messageMetrics.advanceWidth,
            promptMetrics.advanceWidth)))
    implicitWidth: desiredWidth
    implicitHeight: contentColumn.implicitHeight

    TextMetrics {
        id: titleMetrics
        text: root.titleText
        font.family: AbyssStyle.fontFamily
        font.pixelSize: AbyssStyle.fontSize + 2
        font.weight: Font.DemiBold
    }
    TextMetrics {
        id: messageMetrics
        text: root.messageText
        font.family: AbyssStyle.fontFamily
        font.pixelSize: AbyssStyle.fontSize
    }
    TextMetrics {
        id: promptMetrics
        text: String(root.model?.prompt ?? "")
        font.family: AbyssStyle.fontFamily
        font.pixelSize: AbyssStyle.fontSize
    }

    function clearResponse(): void {
        inputField.text = ""
    }

    function submitResponse(): void {
        if (!PolkitService.canSubmit)
            return
        // One local variable for the synchronous backend call; clear the field
        // first so the UI never retains the response during pending state.
        const response = inputField.text
        inputField.text = ""
        PolkitService.submit(response)
    }

    function refocusResponse(): void {
        if (!PolkitService.canSubmit)
            return
        Qt.callLater(() => inputField.forceActiveFocus())
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.clearResponse()
            PolkitService.cancel()
            event.accepted = true
        } else if ((event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter)
                && PolkitService.canSubmit) {
            root.submitResponse()
            event.accepted = true
        }
    }

    Connections {
        target: PolkitService
        function onRequestSerialChanged(): void {
            root.detailsOpen = false
            root.clearResponse()
            root.refocusResponse()
        }
        function onInteractionAvailableChanged(): void {
            if (!PolkitService.interactionAvailable)
                return
            root.clearResponse()
            root.refocusResponse()
        }
        function onActiveChanged(): void {
            if (!PolkitService.active)
                root.clearResponse()
        }
    }

    Component.onCompleted: root.refocusResponse()
    Component.onDestruction: root.clearResponse()

    ColumnLayout {
        id: contentColumn
        width: root.width
        spacing: 10

        AbyssLabel {
            Layout.fillWidth: true
            text: root.titleText
            font.pixelSize: AbyssStyle.fontSize + 2
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        AbyssLabel {
            Layout.fillWidth: true
            visible: String(root.model?.actionLabel ?? "").length > 0
            text: String(root.model?.actionLabel ?? "")
            color: AbyssStyle.accent
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        AbyssLabel {
            Layout.fillWidth: true
            visible: root.messageText.length > 0
            text: root.messageText
            color: AbyssStyle.textColorMuted
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.identityText.length > 0
            spacing: 8

            AbyssLabel {
                Layout.fillWidth: true
                text: Translation.tr("Identity") + ": " + root.identityText
                color: AbyssStyle.textColorMuted
                elide: Text.ElideRight
            }

            AbyssButton {
                visible: Number(root.model?.identityCount ?? 0) > 1
                enabled: PolkitService.interactionAvailable
                    && !(root.model?.busy ?? false)
                text: Translation.tr("Switch")
                glyph: "switch_account"
                onClicked: {
                    // A response typed for one identity must not survive into
                    // the replacement PAM conversation.
                    root.clearResponse()
                    PolkitService.selectNextIdentity()
                }
            }
        }

        AbyssLabel {
            Layout.fillWidth: true
            visible: root.supplementaryText.length > 0
                || (root.model?.failed ?? false)
            text: root.supplementaryText.length > 0
                ? root.supplementaryText
                : Translation.tr("Authentication failed. Try again.")
            color: (root.model?.supplementaryIsError ?? false)
                || (root.model?.failed ?? false)
                ? AbyssStyle.accent : AbyssStyle.textColorMuted
            wrapMode: Text.WordWrap
        }

        AbyssSearchField {
            id: inputField
            Layout.fillWidth: true
            visible: (root.model?.responseRequired ?? false)
                || (root.model?.busy ?? false)
            enabled: PolkitService.canSubmit
            focus: true
            placeholderText: String(root.model?.prompt ?? "")
            echoMode: (root.model?.responseVisible ?? false)
                ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            onAccepted: root.submitResponse()
        }

        AbyssLabel {
            Layout.fillWidth: true
            visible: root.model?.busy ?? false
            text: Translation.tr("Authenticating…")
            color: AbyssStyle.textColorMuted
            wrapMode: Text.WordWrap
        }

        AbyssButton {
            visible: root.detailsText.length > 0
            text: root.detailsOpen
                ? Translation.tr("Hide details") : Translation.tr("Details")
            glyph: root.detailsOpen ? "expand_less" : "expand_more"
            onClicked: root.detailsOpen = !root.detailsOpen
        }

        AbyssLabel {
            Layout.fillWidth: true
            visible: root.detailsOpen && root.detailsText.length > 0
            text: root.detailsText
            color: AbyssStyle.textColorMuted
            wrapMode: Text.WrapAnywhere
        }

        AbyssSeparator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            AbyssButton {
                text: Translation.tr("Cancel")
                glyph: "close"
                onClicked: {
                    root.clearResponse()
                    PolkitService.cancel()
                }
            }

            AbyssButton {
                enabled: PolkitService.canSubmit
                text: root.model?.busy ?? false
                    ? Translation.tr("Authenticating…")
                    : Translation.tr("Authenticate")
                glyph: "verified_user"
                onClicked: root.submitResponse()
            }
        }
    }
}
