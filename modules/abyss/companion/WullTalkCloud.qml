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
    // 0 = closed, 1 = thinking effort, 2 = model picker.
    property int profileStage: 0
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
            Rectangle {
                objectName: "wullProfilePanel"
                visible: root.editing && root.profileStage > 0
                Layout.fillWidth: true
                implicitHeight: profilePanel.implicitHeight + 16
                radius: 14
                color: Qt.alpha(AbyssStyle.surfaceRaised, .82)
                ColumnLayout {
                    id: profilePanel
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5
                    ColumnLayout {
                        objectName: "wullEffortPanel"
                        visible: root.profileStage === 1
                        Layout.fillWidth: true
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "Thinking effort"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: WullMind.thinkingEffortLabel
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colPrimary
                            }
                        }
                        StyledSlider {
                            objectName: "wullThinkingEffort"
                            Layout.fillWidth: true
                            enableSettingsSearch: false
                            from: 0
                            to: 3
                            stepSize: 1
                            value: Math.max(0, WullMind.thinkingLevels.findIndex(level => level.value === WullMind.effectiveThinkingEffort))
                            enabled: WullMind.thinkingSupported && !WullMind.busy
                            tooltipContent: WullMind.thinkingEffortLabel
                            onMoved: {
                                const levels = ["off", "low", "medium", "high"]
                                WullMind.setThinkingEffort(levels[Math.max(0, Math.min(3, Math.round(value)))])
                            }
                        }
                        StyledText {
                            visible: !WullMind.thinkingSupported
                            Layout.fillWidth: true
                            text: "This model uses instant mode. Tap the effort control again to choose another model."
                            wrapMode: Text.WordWrap
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }
                    ColumnLayout {
                        objectName: "wullModelPicker"
                        visible: root.profileStage === 2
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: "Model"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: WullMind.currentModelLabel
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colPrimary
                            }
                        }
                        Repeater {
                            model: WullMind.selectableModels
                            DialogButton {
                                required property var modelData
                                objectName: "wullModelOption-" + String(modelData.name)
                                Layout.fillWidth: true
                                buttonText: modelData.label ?? modelData.name
                                toggled: WullMind.model === modelData.name
                                enabled: !WullMind.busy
                                colBackgroundToggled: Appearance.colors.colPrimary
                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                colEnabled: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
                                onClicked: {
                                    WullMind.selectModel(modelData)
                                    root.profileStage = 0
                                    Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                objectName: "wullChatComposer"
                visible: root.editing
                Layout.fillWidth: true
                implicitHeight: composerContent.implicitHeight + 8
                radius: 18
                color: Qt.alpha(AbyssStyle.accent, .05)
                ColumnLayout {
                    id: composerContent
                    x: 4
                    y: 4
                    width: parent.width - 8
                    spacing: 2
                    MaterialTextField {
                        id: message
                        objectName: "wullChatInput"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        maximumLength: 1200
                        enableSettingsSearch: false
                        placeholderText: ""
                        Accessible.name: "Message"
                        background: Rectangle { color: "transparent"; border.width: 0 }
                        onAccepted: root.submit()
                        Keys.onEscapePressed: {
                            if (root.profileStage > 0) {
                                root.profileStage = 0
                                forceActiveFocus()
                            } else {
                                focus = false
                                WullMind.cancel()
                                WullMind.dismiss()
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RippleButton {
                            objectName: "wullModelEffort"
                            Layout.preferredWidth: Math.max(68, Math.min(root.width - 90, effortLabel.implicitWidth + 60))
                            Layout.preferredHeight: 30
                            implicitWidth: Layout.preferredWidth
                            implicitHeight: 30
                            enabled: !WullMind.busy && WullMind.selectableModels.length > 0
                            buttonRadius: 15
                            onClicked: {
                                if (root.profileStage === 0)
                                    root.profileStage = 1
                                else if (root.profileStage === 1)
                                    root.profileStage = 2
                                else {
                                    root.profileStage = 0
                                    Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
                                }
                            }
                            Keys.onEscapePressed: {
                                root.profileStage = 0
                                Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
                            }
                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 5
                                MaterialSymbol {
                                    text: WullMind.thinkingSupported ? "psychology" : "bolt"
                                    iconSize: 16
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    id: effortLabel
                                    text: WullMind.thinkingEffortLabel
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                }
                                MaterialSymbol {
                                    text: root.profileStage === 2 ? "swap_vert"
                                        : root.profileStage === 1 ? "expand_more" : "chevron_right"
                                    iconSize: 16
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
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
        }
    }
    function submit(): void {
        if (WullMind.sendMessage(message.text)) message.text=""
    }
    onEditingChanged: {
        if (editing) Qt.callLater(() => { if (root.editing) message.forceActiveFocus() })
        else root.profileStage = 0
    }
    onControlsVisibleChanged: if (!controlsVisible) {
        root.profileStage = 0
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
