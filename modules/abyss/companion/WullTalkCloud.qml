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
    width: Math.min(380, Math.max(220, outputWidth - 32))
    height: editing ? Math.min(430, Math.max(230, outputHeight - 48)) : content.implicitHeight + 24
    x: Math.max(12, Math.min(outputWidth - width - 12, actor.x + actor.width / 2 - width / 2))
    y: actor.y - height - 18 >= 12 ? actor.y - height - 18
        : Math.min(outputHeight - height - 12, actor.y + actor.height + 18)
    visible: allowed && actor.visible && actor.inputReady && (WullMind.text.length > 0 || WullMind.conversationOpen)
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
        height: root.editing ? root.height - 24 : implicitHeight
        spacing: 7
        StyledText {
            Layout.fillWidth: true
            visible: !root.editing
            text: WullMind.text
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.small
            Accessible.description: WullMind.source === "local" ? "Local AI" : "Companion message"
        }
        Item {
            visible: root.editing && WullMind.historyLoaded && WullMind.history.length===0
            Layout.fillWidth: true
            Layout.fillHeight: true
            StyledText {
                anchors.centerIn: parent
                width: Math.min(parent.width, 260)
                horizontalAlignment: Text.AlignHCenter
                text: "Splish! What's on your mind?"
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
        ListView {
            id: transcript
            objectName: "wullChatHistory"
            visible: root.editing && WullMind.history.length>0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: WullMind.history
            property bool readyForOlder: false
            onCountChanged: {
                if (WullMind.historyLoadingOlder) return
                readyForOlder=false
                Qt.callLater(() => {
                    if (!root.editing) return
                    transcript.positionViewAtEnd()
                    transcript.readyForOlder=true
                })
            }
            onContentYChanged: {
                if (readyForOlder && contentY<=12 && WullMind.historyHasMore && !WullMind.busy)
                    WullMind.loadHistory(true)
            }
            delegate: Item {
                required property var modelData
                width: transcript.width
                height: bubble.height + 2
                readonly property bool fromUser: modelData?.role === "user"
                Rectangle {
                    id: bubble
                    width: Math.min(parent.width*.88,Math.max(86,messageText.implicitWidth+20))
                    height: messageText.implicitHeight+14
                    x: parent.fromUser ? parent.width-width : 0
                    radius: 14
                    color: parent.fromUser ? Qt.alpha(AbyssStyle.accent,.14) : Qt.alpha(AbyssStyle.surfaceRaised,.72)
                    opacity: parent.modelData?.failed === true ? .58 : 1
                    StyledText {
                        id: messageText
                        x: 10; y: 7; width: parent.width-20
                        text: String(parent.parent.modelData?.content ?? "")
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
            Connections {
                target: WullMind
                function onHistoryPrepended(count): void {
                    transcript.positionViewAtIndex(count,ListView.Beginning)
                    transcript.readyForOlder=true
                }
            }
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
                spacing: 6
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
                        radius: 18
                        border.width: 0
                        color: Qt.alpha(AbyssStyle.accent, .05)
                    }
                    onAccepted: root.submit()
                    Keys.onEscapePressed: { focus = false; WullMind.cancel(); WullMind.dismiss() }
                }
                RippleButton {
                    objectName: "wullChatSend"
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: !WullMind.busy && message.text.trim().length>0
                    buttonRadius: 18
                    onClicked: root.submit()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_upward"
                        iconSize: 20
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }
    }
    function submit(): void {
        if (WullMind.sendMessage(message.text)) message.text=""
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
