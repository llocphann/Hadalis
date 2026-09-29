pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.abyss.looks

FocusScope {
    id: root
    required property var request
    focus: true

    readonly property real minContentWidth: 260
    readonly property real maxContentWidth: 460
    readonly property string titleText:
        String(root.request?.title ?? "")
    readonly property string messageText:
        String(root.request?.message ?? "")
    readonly property string detailsText:
        String(root.request?.details ?? "")
    readonly property var actions:
        Array.isArray(root.request?.actions) ? root.request.actions : []
    readonly property var visibleActions:
        root.actions.filter(action => action?.visible !== false)
    property bool detailsOpen: false

    readonly property real desiredWidth: Math.max(minContentWidth,
        Math.min(maxContentWidth, Math.max(
            titleMetrics.advanceWidth,
            messageMetrics.advanceWidth,
            detailsText.length > 0 ? detailsButtonMetrics.advanceWidth : 0)))
    readonly property real desiredHeight: contentColumn.implicitHeight
    implicitWidth: desiredWidth
    implicitHeight: desiredHeight

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
        id: detailsButtonMetrics
        text: root.detailsOpen
            ? Translation.tr("Hide details") : Translation.tr("Details")
        font.family: AbyssStyle.fontFamily
        font.pixelSize: AbyssStyle.fontSize
    }

    function cancel(): void {
        ConfirmationService.cancel()
    }

    function accept(): void {
        ConfirmationService.acceptDefault()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.accept()
            event.accepted = true
        }
    }

    Component.onCompleted: root.forceActiveFocus()
    onRequestChanged: {
        root.detailsOpen = false
        Qt.callLater(() => root.forceActiveFocus())
    }

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
            visible: root.messageText.length > 0
            text: root.messageText
            color: AbyssStyle.textColorMuted
            wrapMode: Text.WordWrap
        }

        AbyssButton {
            id: detailsButton
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
            visible: root.visibleActions.length > 0
        }

        Item {
            Layout.fillWidth: true
            visible: root.visibleActions.length > 0
            implicitHeight: actionFlow.childrenRect.height

            Flow {
                id: actionFlow
                width: parent.width
                spacing: 8
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: root.visibleActions

                    delegate: AbyssButton {
                        id: actionButton
                        required property var modelData

                        TextMetrics {
                            id: actionMetrics
                            text: String(actionButton.modelData?.label ?? "")
                            font: actionButton.font
                        }

                        visible: modelData?.visible !== false
                        enabled: modelData?.enabled !== false
                        text: String(modelData?.label ?? "")
                        glyph: String(modelData?.glyph ?? "")
                        width: Math.min(180,
                            Math.max(72, actionMetrics.advanceWidth + 28))
                        onClicked: ConfirmationService.resolve(
                            String(modelData?.id ?? ""))
                    }
                }
            }
        }
    }
}
