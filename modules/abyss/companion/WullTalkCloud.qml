pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

// One question offers one choice row. Only explicit chat requests input focus.
Item {
    id: root
    required property Item actor
    required property real outputWidth
    required property real outputHeight
    property bool allowed: false
    readonly property bool editing: visible && WullMind.conversationOpen
    readonly property bool controlsVisible: visible && (editing || WullMind.checkInStage.length>0)
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
        required property var options
        required property string selectedValue
        Layout.fillWidth: true
        spacing: 3
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
                    enabled: !WullMind.busy
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
                visible: WullMind.checkInStage === "mood"
                field: "mood"
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
                visible: WullMind.checkInStage === "energy"
                field: "energy"
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
                visible: root.editing
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
                    onAccepted: if (WullMind.sendMessage(text)) text = ""
                    Keys.onEscapePressed: { focus = false; WullMind.cancel(); WullMind.dismiss() }
                }
            }
        }
    }
    onEditingChanged: if (editing) Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
    onControlsVisibleChanged: if (!controlsVisible) {
        message.focus = false
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
