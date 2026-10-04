pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

// Hover reveals controls. Only a click or explicit chat can request focus.
Item {
    id: root
    required property Item actor
    required property real outputWidth
    required property real outputHeight
    property bool allowed: false
    readonly property bool controlsVisible: visible && cloudHover.hovered
        && cloudHover.point.position.x >= x && cloudHover.point.position.x <= x + width
        && cloudHover.point.position.y >= y && cloudHover.point.position.y <= y + height
    readonly property bool editing: controlsVisible && WullMind.conversationOpen
    width: Math.min(310, Math.max(190, outputWidth - 32))
    height: content.implicitHeight + 24
    x: Math.max(12, Math.min(outputWidth - width - 12, actor.x + actor.width / 2 - width / 2))
    y: actor.y - height - 18 >= 12 ? actor.y - height - 18
        : Math.min(outputHeight - height - 12, actor.y + actor.height + 18)
    visible: allowed && actor.visible && actor.inputReady && WullMind.text.length > 0
    z: 240
    function containsScenePoint(point): bool {
        const local = root.mapFromItem(null, point.x, point.y)
        return visible && local.x >= 0 && local.x <= width && local.y >= 0 && local.y <= height
    }

    // Observe the existing output item's events, whose bounds stay fixed when
    // the bubble grows upward. The bubble's own input Region stays unchanged.
    HoverHandler { id: cloudHover; objectName: "wullCloudHoverTracker"; parent: root.parent; enabled: root.visible }
    Rectangle {
        objectName: "wullCloudBackground"
        anchors.fill: parent
        radius: 18
        border.width: 0
        color: Qt.alpha(AbyssStyle.surface, .96)
    }

    component CheckInRow: ColumnLayout {
        id: choice
        required property string field
        required property string label
        required property var options
        required property string selectedValue
        Layout.fillWidth: true
        spacing: 3
        StyledText {
            text: choice.label
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 5
            columnSpacing: 2
            Repeater {
                model: choice.options
                DialogButton {
                    required property var modelData
                    objectName: "wull" + choice.field + "-" + modelData.value
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 28
                    padding: 3
                    buttonText: modelData.label
                    toggled: choice.selectedValue === modelData.value
                    colBackgroundToggled: Qt.alpha(AbyssStyle.accent, .2)
                    colBackgroundToggledHover: Qt.alpha(AbyssStyle.accent, .3)
                    onClicked: WullMind.setCheckInChoice(choice.field, modelData.value)
                }
            }
        }
    }

    ColumnLayout {
        id: content
        x: 12; y: 12; width: parent.width - 24
        spacing: 7
        StyledText {
            Layout.fillWidth: true
            text: WullMind.text
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.small
            Accessible.description: WullMind.source === "local" ? "Local AI" : "Companion message"
        }
        ColumnLayout {
            visible: root.controlsVisible
            Layout.fillWidth: true
            spacing: 5
            CheckInRow {
                field: "mood"; label: Translation.tr("Mood")
                selectedValue: WullMind.userMood || String(WullMind.journal.mood ?? "").toLowerCase()
                options: [
                    {value: "terrible", label: Translation.tr("Awful")},
                    {value: "bad", label: Translation.tr("Low")},
                    {value: "okay", label: Translation.tr("Okay")},
                    {value: "good", label: Translation.tr("Good")},
                    {value: "great", label: Translation.tr("Great")}
                ]
            }
            CheckInRow {
                field: "energy"; label: Translation.tr("Energy")
                selectedValue: WullMind.userEnergy || String(WullMind.journal.energy ?? "").toLowerCase()
                options: [
                    {value: "drained", label: Translation.tr("Drained")},
                    {value: "low", label: Translation.tr("Low")},
                    {value: "medium", label: Translation.tr("Mid")},
                    {value: "high", label: Translation.tr("High")},
                    {value: "peak", label: Translation.tr("Peak")}
                ]
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                MaterialTextField {
                    id: message
                    objectName: "wullChatInput"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    maximumLength: 1200
                    enableSettingsSearch: false
                    placeholderText: ""
                    Accessible.name: "Message"
                    background: Rectangle {
                        implicitHeight: 36
                        radius: 8
                        border.width: 0
                        color: Qt.alpha(AbyssStyle.accent, .05)
                    }
                    onActiveFocusChanged: if (activeFocus) WullMind.openChat()
                    onAccepted: if (WullMind.sendMessage(text)) text = ""
                    Keys.onEscapePressed: { focus = false; WullMind.closeChat() }
                }
                IconToolbarButton {
                    objectName: "wullChatSend"
                    implicitHeight: 32
                    Layout.fillHeight: false
                    text: WullMind.busy ? "stop" : "arrow_upward"
                    Accessible.name: WullMind.busy ? "Cancel" : "Send"
                    onClicked: {
                        if (WullMind.busy) WullMind.cancel()
                        else if (WullMind.sendMessage(message.text)) message.text = ""
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                MaterialSymbol {
                    objectName: "wullMessageSource"
                    text: WullMind.source === "local" ? "psychology" : "water_drop"
                    iconSize: 16
                    color: Qt.alpha(AbyssStyle.accent, .7)
                    Accessible.name: WullMind.source === "local" ? "Local AI" : "Companion message"
                }
                Item { Layout.fillWidth: true }
                IconToolbarButton {
                    visible: !!WullMind.journal.journalPath
                    implicitHeight: 28
                    Layout.fillHeight: false
                    text: "book_2"
                    Accessible.name: "Open journal"
                    onClicked: WullMind.openJournal()
                }
                IconToolbarButton {
                    objectName: "wullCloudDismiss"
                    implicitHeight: 28
                    Layout.fillHeight: false
                    text: "close"
                    Accessible.name: "Close"
                    onClicked: WullMind.dismiss()
                }
            }
        }
    }
    onEditingChanged: if (editing) Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
    onControlsVisibleChanged: if (!controlsVisible) {
        message.focus = false
        if (WullMind.conversationOpen) WullMind.closeChat()
    }
    Shape {
        width: 18; height: 12
        x: Math.max(18, Math.min(root.width - 36, actor.x + actor.width / 2 - root.x - 9))
        y: root.y < actor.y ? root.height - 1 : -11
        rotation: root.y < actor.y ? 0 : 180
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillColor: Qt.alpha(AbyssStyle.surface, .96)
            startX: 0; startY: 0
            PathLine { x: 9; y: 12 }
            PathLine { x: 18; y: 0 }
        }
    }
}
