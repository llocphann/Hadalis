import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Dashboard-native Todo presentation.
 *
 * The shared Todo service remains the only data/mutation owner. This card keeps
 * Dashboard composition independent from the Sidebar widget so both surfaces
 * can evolve without UI regressions in the other.
 */
DashCard {
    id: root

    title: ""
    icon: ""
    Layout.fillHeight: true
    focus: true

    property int currentTab: 0
    property bool showAddDialog: false

    readonly property var indexedTasks: Todo.list.map(function(item, index) {
        return Object.assign({}, item, { originalIndex: index })
    })
    readonly property var unfinishedTasks: root.indexedTasks.filter(
        function(item) { return item.done !== true })
    readonly property var doneTasks: root.indexedTasks.filter(
        function(item) { return item.done === true })
    readonly property var visibleTasks:
        root.currentTab === 0 ? root.unfinishedTasks : root.doneTasks

    function openTodoSettings(): void {
        GlobalStates.openSettingsSection(7, "Todo & Obsidian")
    }

    function toggleTask(item): void {
        if (!item || Todo.busy)
            return
        if (item.done === true)
            Todo.markUnfinished(item.originalIndex)
        else
            Todo.markDone(item.originalIndex)
    }

    function deleteTask(item): void {
        if (!item || Todo.busy)
            return
        Todo.deleteItem(item.originalIndex)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_N && Todo.ready && !Todo.busy) {
            root.showAddDialog = true
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            root.currentTab = Math.min(1, root.currentTab + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            root.currentTab = Math.max(0, root.currentTab - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false
            event.accepted = true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: root.compact ? 6 : 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.preferredWidth: root.compact ? 38 : 44
                Layout.preferredHeight: Layout.preferredWidth
                text: "checklist"
                shape: MaterialShape.Shape.Cookie4Sided
                padding: root.compact ? 6 : 8
                iconSize: root.compact ? 21 : 24
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("To Do")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: root.colText
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        implicitWidth: sourceRow.implicitWidth + 12
                        implicitHeight: sourceRow.implicitHeight + 5
                        radius: height / 2
                        color: Appearance.colors.colLayer2

                        RowLayout {
                            id: sourceRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: Todo.backend === "obsidian"
                                    ? "description" : "database"
                                iconSize: Appearance.font.pixelSize.small
                                color: root.colAccent
                            }

                            StyledText {
                                text: Todo.backend === "obsidian"
                                    ? "Obsidian" : "Hadalis"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.colSubtext
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Todo.list.length + " " + Translation.tr("Tasks")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.colSubtext
                        elide: Text.ElideRight
                    }
                }
            }

            RippleButton {
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: height / 2
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.openTodoSettings()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "more_horiz"
                    iconSize: 20
                    color: root.colSubtext
                }

                StyledToolTip {
                    text: Translation.tr("Todo & Obsidian")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3

                Repeater {
                    model: [
                        {
                            label: Translation.tr("Unfinished"),
                            icon: "checklist",
                            count: root.unfinishedTasks.length
                        },
                        {
                            label: Translation.tr("Done"),
                            icon: "check_circle",
                            count: root.doneTasks.length
                        }
                    ]

                    delegate: RippleButton {
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        buttonRadius: Appearance.rounding.full
                        colBackground: root.currentTab === index
                            ? Appearance.colors.colPrimaryContainer
                            : "transparent"
                        colBackgroundHover: root.currentTab === index
                            ? Appearance.colors.colPrimaryContainer
                            : Appearance.colors.colLayer2Hover
                        onClicked: root.currentTab = index

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 17
                                color: root.currentTab === index
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : root.colSubtext
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: root.currentTab === index
                                    ? Font.DemiBold : Font.Medium
                                color: root.currentTab === index
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : root.colSubtext
                            }

                            Rectangle {
                                implicitWidth: Math.max(22, countText.implicitWidth + 10)
                                implicitHeight: 22
                                radius: height / 2
                                color: root.currentTab === index
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colLayer1

                                StyledText {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.DemiBold
                                    color: root.currentTab === index
                                        ? Appearance.colors.colOnPrimary
                                        : root.colSubtext
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 72
            clip: true

            Flickable {
                id: taskFlick
                anchors.fill: parent
                visible: root.visibleTasks.length > 0
                contentWidth: width
                contentHeight: taskColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Column {
                    id: taskColumn
                    width: taskFlick.width
                    spacing: root.compact ? 4 : 6

                    Repeater {
                        model: root.visibleTasks

                        delegate: Rectangle {
                            id: taskRow
                            required property var modelData
                            width: taskColumn.width
                            implicitHeight: Math.max(root.compact ? 44 : 50,
                                rowContent.implicitHeight + 12)
                            radius: Appearance.rounding.small
                            color: rowHover.hovered
                                ? Appearance.colors.colLayer2Hover
                                : Appearance.colors.colLayer2

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                }
                            }

                            RowLayout {
                                id: rowContent
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 7
                                anchors.topMargin: 6
                                anchors.bottomMargin: 6
                                spacing: 8

                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        radius: 7
                                        color: taskRow.modelData.done === true
                                            ? Appearance.colors.colPrimary
                                            : "transparent"
                                        border.width: 2
                                        border.color: taskRow.modelData.done === true
                                            ? Appearance.colors.colPrimary
                                            : Appearance.colors.colOutline

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: taskRow.modelData.done === true
                                            text: "check"
                                            iconSize: 16
                                            color: Appearance.colors.colOnPrimary
                                        }
                                    }

                                    TapHandler {
                                        enabled: !Todo.busy
                                        onTapped: root.toggleTask(taskRow.modelData)
                                    }

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: taskRow.modelData.content ?? ""
                                    color: taskRow.modelData.done === true
                                        ? root.colSubtext : root.colText
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: taskRow.modelData.done === true
                                        ? Font.Normal : Font.Medium
                                    font.strikeout: taskRow.modelData.done === true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                RippleButton {
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    buttonRadius: height / 2
                                    enabled: !Todo.busy
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.deleteTask(taskRow.modelData)

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 17
                                        color: root.colSubtext
                                    }
                                }
                            }

                            HoverHandler {
                                id: rowHover
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 220)
                spacing: 5
                visible: root.visibleTasks.length === 0

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    width: root.compact ? 46 : 54
                    height: width
                    text: root.currentTab === 0 ? "task_alt" : "done_all"
                    shape: MaterialShape.Shape.Clover4Leaf
                    padding: 8
                    iconSize: root.compact ? 24 : 28
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Todo.errorMessage.length > 0
                        ? Todo.errorMessage
                        : root.currentTab === 0
                            ? Translation.tr("Nothing here!")
                            : Translation.tr("Finished tasks will go here")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colText
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButton {
                visible: Todo.backend !== "obsidian"
                Layout.preferredWidth: setupRow.implicitWidth + 18
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.openTodoSettings()

                contentItem: RowLayout {
                    id: setupRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        text: "link"
                        iconSize: 16
                        color: root.colAccent
                    }

                    StyledText {
                        text: Translation.tr("Prepare Obsidian")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: root.colText
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RippleButton {
                implicitWidth: root.compact ? 34 : editRow.implicitWidth + 16
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                enabled: Todo.ready
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Todo.openSource("")

                contentItem: RowLayout {
                    id: editRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        text: "edit_note"
                        iconSize: 17
                        color: root.colAccent
                    }

                    StyledText {
                        visible: !root.compact
                        text: Translation.tr("Edit")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colText
                    }
                }
            }

            RippleButton {
                Layout.preferredWidth: addRow.implicitWidth + 18
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                enabled: Todo.ready && !Todo.busy
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: root.showAddDialog = true

                contentItem: RowLayout {
                    id: addRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        text: "add"
                        iconSize: 17
                        color: Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        text: Translation.tr("Add task")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 100
        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim

            TapHandler {
                onTapped: root.showAddDialog = false
            }
        }

        Rectangle {
            id: addDialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.compact ? 10 : 18
            implicitHeight: addDialogColumn.implicitHeight + 28
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHigh

            ColumnLayout {
                id: addDialogColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Add task")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: root.colText
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    focus: root.showAddDialog
                    padding: 10
                    color: Appearance.colors.colOnSurface
                    placeholderText: Translation.tr("Task description")
                    placeholderTextColor: Appearance.colors.colOutline
                    onAccepted: addTask()

                    function addTask(): void {
                        const text = todoInput.text.trim()
                        if (text.length === 0 || Todo.busy)
                            return
                        if (Todo.addTask(text)) {
                            todoInput.text = ""
                            root.currentTab = 0
                            root.showAddDialog = false
                        }
                    }

                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        border.width: todoInput.activeFocus ? 2 : 1
                        border.color: todoInput.activeFocus
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colOutline
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                    }

                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        onClicked: root.showAddDialog = false
                    }

                    DialogButton {
                        buttonText: Translation.tr("Add")
                        enabled: Todo.ready && !Todo.busy
                            && todoInput.text.trim().length > 0
                        onClicked: todoInput.addTask()
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => todoInput.forceActiveFocus())
            else
                todoInput.text = ""
        }
    }
}
