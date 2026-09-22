import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
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

    // The dashboard card can be resized independently from the Sidebar. Keep
    // chrome proportional so the task viewport, not fixed controls, absorbs
    // most of the size change.
    readonly property bool narrowLayout: root.width > 0 && root.width < 285
    readonly property bool shallowLayout: root.height > 0 && root.height < 300
    readonly property bool veryShallowLayout:
        root.height > 0 && root.height < 210
    readonly property int tabControlHeight:
        root.veryShallowLayout ? 34 : (root.narrowLayout ? 36 : 38)

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
        spacing: root.veryShallowLayout
            ? 4 : (root.narrowLayout ? 5 : (root.compact ? 6 : 8))

        RowLayout {
            Layout.fillWidth: true
            spacing: root.narrowLayout ? 6 : 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.preferredWidth: root.veryShallowLayout
                    ? 32 : (root.narrowLayout ? 34 : (root.compact ? 38 : 44))
                Layout.preferredHeight: Layout.preferredWidth
                text: "checklist"
                shape: MaterialShape.Shape.Cookie4Sided
                padding: root.veryShallowLayout
                    ? 5 : (root.narrowLayout ? 5 : (root.compact ? 6 : 8))
                iconSize: root.veryShallowLayout
                    ? 18 : (root.narrowLayout ? 19 : (root.compact ? 21 : 24))
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
                    visible: !root.veryShallowLayout

                    Rectangle {
                        implicitWidth: Math.min(sourceRow.implicitWidth + 12,
                            root.narrowLayout ? 110 : 150)
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
                                Layout.maximumWidth: root.narrowLayout ? 72 : 112
                                text: Todo.sourceLabel
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.colSubtext
                                elide: Text.ElideRight
                                maximumLineCount: 1
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
                implicitWidth: root.narrowLayout ? 30 : 34
                implicitHeight: implicitWidth
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
            id: tabShell
            Layout.fillWidth: true
            implicitHeight: root.tabControlHeight
            radius: height / 2
            color: Appearance.colors.colLayer2
            clip: true

            readonly property real halfWidth: width / 2
            readonly property real inset: 3
            readonly property real notch: Math.min(9, height * 0.24)
            readonly property real outerRadius: height / 2

            // The inactive half is not another ordinary pill. Its seam recedes
            // around the focused inner pill with inverse-rounded shoulders,
            // while the outer edge remains part of the single parent pill.
            Shape {
                id: inactiveRightShape
                visible: root.currentTab === 0
                x: tabShell.halfWidth - tabShell.notch
                width: tabShell.halfWidth + tabShell.notch
                height: tabShell.height
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: rightTabHover.hovered
                        ? Appearance.colors.colLayer1Hover
                        : Appearance.colors.colLayer1
                    startX: 0
                    startY: 0
                    PathLine {
                        x: inactiveRightShape.width - tabShell.outerRadius
                        y: 0
                    }
                    PathQuad {
                        x: inactiveRightShape.width
                        y: tabShell.outerRadius
                        controlX: inactiveRightShape.width
                        controlY: 0
                    }
                    PathLine {
                        x: inactiveRightShape.width
                        y: inactiveRightShape.height - tabShell.outerRadius
                    }
                    PathQuad {
                        x: inactiveRightShape.width - tabShell.outerRadius
                        y: inactiveRightShape.height
                        controlX: inactiveRightShape.width
                        controlY: inactiveRightShape.height
                    }
                    PathLine { x: 0; y: inactiveRightShape.height }
                    PathQuad {
                        x: tabShell.notch
                        y: inactiveRightShape.height - tabShell.notch
                        controlX: tabShell.notch
                        controlY: inactiveRightShape.height
                    }
                    PathLine { x: tabShell.notch; y: tabShell.notch }
                    PathQuad {
                        x: 0
                        y: 0
                        controlX: tabShell.notch
                        controlY: 0
                    }
                }
            }

            Shape {
                id: inactiveLeftShape
                visible: root.currentTab === 1
                x: 0
                width: tabShell.halfWidth + tabShell.notch
                height: tabShell.height
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: leftTabHover.hovered
                        ? Appearance.colors.colLayer1Hover
                        : Appearance.colors.colLayer1
                    startX: tabShell.outerRadius
                    startY: 0
                    PathLine { x: inactiveLeftShape.width; y: 0 }
                    PathQuad {
                        x: inactiveLeftShape.width - tabShell.notch
                        y: tabShell.notch
                        controlX: inactiveLeftShape.width - tabShell.notch
                        controlY: 0
                    }
                    PathLine {
                        x: inactiveLeftShape.width - tabShell.notch
                        y: inactiveLeftShape.height - tabShell.notch
                    }
                    PathQuad {
                        x: inactiveLeftShape.width
                        y: inactiveLeftShape.height
                        controlX: inactiveLeftShape.width - tabShell.notch
                        controlY: inactiveLeftShape.height
                    }
                    PathLine {
                        x: tabShell.outerRadius
                        y: inactiveLeftShape.height
                    }
                    PathQuad {
                        x: 0
                        y: inactiveLeftShape.height - tabShell.outerRadius
                        controlX: 0
                        controlY: inactiveLeftShape.height
                    }
                    PathLine { x: 0; y: tabShell.outerRadius }
                    PathQuad {
                        x: tabShell.outerRadius
                        y: 0
                        controlX: 0
                        controlY: 0
                    }
                }
            }

            Rectangle {
                id: activeTabPill
                x: root.currentTab === 0
                    ? tabShell.inset
                    : tabShell.halfWidth + tabShell.inset
                y: tabShell.inset
                width: tabShell.halfWidth - tabShell.inset * 2
                height: tabShell.height - tabShell.inset * 2
                radius: height / 2
                color: (root.currentTab === 0
                        ? leftTabHover.hovered : rightTabHover.hovered)
                    ? Appearance.colors.colPrimaryContainerHover
                    : Appearance.colors.colPrimaryContainer
                z: 2

                Behavior on x {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }
            }

            Item {
                id: leftTabHit
                x: 0
                width: tabShell.halfWidth
                height: tabShell.height
                z: 5

                HoverHandler {
                    id: leftTabHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.currentTab = 0
                }
            }

            Item {
                id: rightTabHit
                x: tabShell.halfWidth
                width: tabShell.halfWidth
                height: tabShell.height
                z: 5

                HoverHandler {
                    id: rightTabHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: root.currentTab = 1
                }
            }

            Item {
                x: 0
                width: tabShell.halfWidth
                height: tabShell.height
                z: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: root.narrowLayout ? 3 : 5

                    MaterialSymbol {
                        text: "checklist"
                        iconSize: root.narrowLayout ? 15 : 17
                        color: root.currentTab === 0
                            ? Appearance.colors.colOnPrimaryContainer
                            : root.colSubtext
                    }

                    StyledText {
                        Layout.maximumWidth: root.narrowLayout ? 62 : 92
                        text: Translation.tr("Unfinished")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: root.currentTab === 0
                            ? Font.DemiBold : Font.Medium
                        color: root.currentTab === 0
                            ? Appearance.colors.colOnPrimaryContainer
                            : root.colSubtext
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        implicitWidth: Math.max(root.narrowLayout ? 19 : 22,
                            leftCountText.implicitWidth + (root.narrowLayout ? 7 : 10))
                        implicitHeight: root.narrowLayout ? 19 : 22
                        radius: height / 2
                        color: root.currentTab === 0
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colLayer2

                        StyledText {
                            id: leftCountText
                            anchors.centerIn: parent
                            text: root.unfinishedTasks.length
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: root.currentTab === 0
                                ? Appearance.colors.colOnPrimary
                                : root.colSubtext
                        }
                    }
                }
            }

            Item {
                x: tabShell.halfWidth
                width: tabShell.halfWidth
                height: tabShell.height
                z: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: root.narrowLayout ? 3 : 5

                    MaterialSymbol {
                        text: "check_circle"
                        iconSize: root.narrowLayout ? 15 : 17
                        color: root.currentTab === 1
                            ? Appearance.colors.colOnPrimaryContainer
                            : root.colSubtext
                    }

                    StyledText {
                        Layout.maximumWidth: root.narrowLayout ? 48 : 72
                        text: Translation.tr("Done")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: root.currentTab === 1
                            ? Font.DemiBold : Font.Medium
                        color: root.currentTab === 1
                            ? Appearance.colors.colOnPrimaryContainer
                            : root.colSubtext
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        implicitWidth: Math.max(root.narrowLayout ? 19 : 22,
                            rightCountText.implicitWidth + (root.narrowLayout ? 7 : 10))
                        implicitHeight: root.narrowLayout ? 19 : 22
                        radius: height / 2
                        color: root.currentTab === 1
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colLayer2

                        StyledText {
                            id: rightCountText
                            anchors.centerIn: parent
                            text: root.doneTasks.length
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: root.currentTab === 1
                                ? Appearance.colors.colOnPrimary
                                : root.colSubtext
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y < 0)
                        root.currentTab = 1
                    else if (event.angleDelta.y > 0)
                        root.currentTab = 0
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.veryShallowLayout
                ? 8 : (root.shallowLayout ? 56 : 72)
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

                                Rectangle {
                                    visible: String(taskRow.modelData.startTime ?? "").length > 0
                                    implicitWidth: taskTimeLabel.implicitWidth + 12
                                    implicitHeight: 24
                                    radius: height / 2
                                    color: Appearance.colors.colLayer1

                                    StyledText {
                                        id: taskTimeLabel
                                        anchors.centerIn: parent
                                        text: {
                                            const start = String(taskRow.modelData.startTime ?? "")
                                            const end = String(taskRow.modelData.endTime ?? "")
                                            return end.length > 0 ? start + "–" + end : start
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.family: Appearance.font.family.numbers
                                        font.weight: Font.DemiBold
                                        color: root.colAccent
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
                width: Math.min(parent.width - (root.narrowLayout ? 12 : 24),
                    root.narrowLayout ? 190 : 220)
                spacing: root.shallowLayout ? 3 : 5
                visible: root.visibleTasks.length === 0

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.veryShallowLayout
                    width: root.shallowLayout ? 42 : (root.compact ? 46 : 54)
                    height: width
                    text: root.currentTab === 0 ? "task_alt" : "done_all"
                    shape: MaterialShape.Shape.Clover4Leaf
                    padding: root.shallowLayout ? 6 : 8
                    iconSize: root.shallowLayout ? 22 : (root.compact ? 24 : 28)
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
            spacing: root.narrowLayout ? 4 : 6

            RippleButton {
                visible: Todo.backend !== "obsidian"
                Layout.preferredWidth: (root.narrowLayout || root.veryShallowLayout)
                    ? 34 : setupRow.implicitWidth + 18
                implicitHeight: root.veryShallowLayout ? 30 : 34
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.openTodoSettings()

                StyledToolTip {
                    text: Translation.tr("Prepare Obsidian")
                }

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
                        visible: !root.narrowLayout && !root.veryShallowLayout
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
                implicitWidth: (root.compact || root.narrowLayout
                        || root.veryShallowLayout)
                    ? 34 : editRow.implicitWidth + 16
                implicitHeight: root.veryShallowLayout ? 30 : 34
                buttonRadius: Appearance.rounding.full
                enabled: Todo.ready
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Todo.openSource("")

                StyledToolTip {
                    text: Translation.tr("Edit task source")
                }

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
                        visible: !root.compact && !root.narrowLayout
                            && !root.veryShallowLayout
                        text: Translation.tr("Edit")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colText
                    }
                }
            }

            RippleButton {
                Layout.preferredWidth: (root.narrowLayout || root.veryShallowLayout)
                    ? 34 : addRow.implicitWidth + 18
                implicitHeight: root.veryShallowLayout ? 30 : 34
                buttonRadius: Appearance.rounding.full
                enabled: Todo.ready && !Todo.busy
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: root.showAddDialog = true

                StyledToolTip {
                    text: Translation.tr("Add task")
                }

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
                        visible: !root.narrowLayout && !root.veryShallowLayout
                        text: Translation.tr("Add task")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    property Item addDialogOverlay: Item {
        parent: root
        anchors.fill: root
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
                        const start = Todo.useMarkdownNote
                            ? todoStartTime.text.trim() : ""
                        const end = Todo.useMarkdownNote
                            ? todoEndTime.text.trim() : ""
                        if (Todo.addTaskWithTime(text, start, end)) {
                            todoInput.text = ""
                            todoStartTime.text = ""
                            todoEndTime.text = ""
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
                    spacing: 8
                    visible: Todo.backend === "obsidian"
                        && Todo.useMarkdownNote

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: Translation.tr("Start time")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colSubtext
                        }

                        TextField {
                            id: todoStartTime
                            Layout.fillWidth: true
                            placeholderText: "HH:mm"
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colOutline
                            validator: RegularExpressionValidator {
                                regularExpression: /^(?:|(?:[01]\d|2[0-3]):[0-5]\d)$/
                            }
                            background: Rectangle {
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1
                                border.width: todoStartTime.activeFocus ? 2 : 1
                                border.color: todoStartTime.activeFocus
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOutline
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: Translation.tr("End time")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colSubtext
                        }

                        TextField {
                            id: todoEndTime
                            Layout.fillWidth: true
                            enabled: todoStartTime.text.trim().length > 0
                            placeholderText: "HH:mm"
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colOutline
                            validator: RegularExpressionValidator {
                                regularExpression: /^(?:|(?:[01]\d|2[0-3]):[0-5]\d)$/
                            }
                            background: Rectangle {
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1
                                border.width: todoEndTime.activeFocus ? 2 : 1
                                border.color: todoEndTime.activeFocus
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOutline
                            }
                        }
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
            else {
                todoInput.text = ""
                todoStartTime.text = ""
                todoEndTime.text = ""
            }
        }
    }
}
