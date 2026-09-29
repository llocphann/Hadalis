import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6

    readonly property int rowHeight: 38
    readonly property var defaultOrder: [
        "screenSnip","screenRecord","colorPicker","notepad","keyboard",
        "keyboardLayout","mic","screenCast","darkMode","performance","utilities"
    ]
    readonly property var actionOrder: {
        const configured = Config.options?.bar?.utilButtons?.order ?? []
        const result = []
        for (const id of configured) {
            if (root.defaultOrder.includes(id) && !result.includes(id))
                result.push(id)
        }
        for (const id of root.defaultOrder)
            if (!result.includes(id)) result.push(id)
        return result
    }
    readonly property var activeActions: {
        void Config.revision
        return root.actionOrder.filter(id => root.configuredVisible(id))
    }
    readonly property var unusedActions: {
        void Config.revision
        return root.actionOrder.filter(id => !root.configuredVisible(id))
    }

    property var dragInfo: null
    property int dropIndex: -1
    readonly property bool dragging: dragInfo !== null

    function actionLabel(id): string {
        const labels = {
            screenSnip:"Screenshot",screenRecord:"Screen record",
            colorPicker:"Color picker",notepad:"Notepad",
            keyboard:"On-screen keyboard",keyboardLayout:"Keyboard layout",
            mic:"Microphone",screenCast:"Screen cast",
            darkMode:"Dark / light mode",performance:"Power profile",
            utilities:"Utilities"
        }
        const source = labels[id] ?? id
        const translated = Translation.tr(source)
        return String(translated ?? "").trim().length > 0 ? translated : source
    }

    function actionIcon(id): string {
        const icons = {
            screenSnip:"screenshot_region",screenRecord:"screen_record",
            colorPicker:"colorize",notepad:"edit_note",
            keyboard:"keyboard",keyboardLayout:"language",
            mic:"mic",screenCast:"cast",
            darkMode:"dark_mode",performance:"speed",
            utilities:"tune"
        }
        return icons[id] ?? "widgets"
    }

    function configuredVisible(id): bool {
        switch (id) {
        case "screenSnip": return Config.options?.bar?.utilButtons?.showScreenSnip ?? true
        case "screenRecord": return Config.options?.bar?.utilButtons?.showScreenRecord ?? true
        case "colorPicker": return Config.options?.bar?.utilButtons?.showColorPicker ?? false
        case "notepad": return Config.options?.bar?.utilButtons?.showNotepad ?? true
        case "keyboard": return Config.options?.bar?.utilButtons?.showKeyboardToggle ?? true
        case "keyboardLayout": return Config.options?.bar?.utilButtons?.showKeyboardLayoutSwitch ?? false
        case "mic": return Config.options?.bar?.utilButtons?.showMicToggle ?? false
        case "screenCast": return Config.options?.bar?.utilButtons?.showScreenCast ?? false
        case "darkMode": return Config.options?.bar?.utilButtons?.showDarkModeToggle ?? true
        case "performance": return Config.options?.bar?.utilButtons?.showPerformanceProfileToggle ?? false
        case "utilities": return Config.options?.bar?.utilButtons?.showUtilitiesLauncher ?? true
        default: return true
        }
    }

    function visibilityPath(id): string {
        const keys = {
            screenSnip:"showScreenSnip",screenRecord:"showScreenRecord",
            colorPicker:"showColorPicker",notepad:"showNotepad",
            keyboard:"showKeyboardToggle",keyboardLayout:"showKeyboardLayoutSwitch",
            mic:"showMicToggle",screenCast:"showScreenCast",
            darkMode:"showDarkModeToggle",performance:"showPerformanceProfileToggle",
            utilities:"showUtilitiesLauncher"
        }
        return "bar.utilButtons."+(keys[id] ?? "")
    }

    function setActionVisible(id, visible): void {
        const path = root.visibilityPath(id)
        if (!path.endsWith("."))
            Config.setNestedValue(path, visible)
    }

    function removeAction(id): void {
        root.setActionVisible(id, false)
    }

    function addAction(id): void {
        if (root.configuredVisible(id))
            return
        const next = root.activeActions.filter(actionId => actionId !== id)
            .concat([id], root.unusedActions.filter(actionId => actionId !== id))
        Config.setNestedValue("bar.utilButtons.order", next)
        root.setActionVisible(id, true)
    }

    function commitDrop(): void {
        if (!root.dragInfo || root.dropIndex < 0) {
            root.dragInfo = null
            root.dropIndex = -1
            return
        }
        const active = root.activeActions.slice()
        const from = root.dragInfo.index
        const to = root.dropIndex
        if (from >= 0 && from < active.length && to >= 0 && to < active.length && from !== to) {
            const moved = active.splice(from, 1)[0]
            active.splice(to, 0, moved)
            Config.setNestedValue("bar.utilButtons.order", active.concat(root.unusedActions))
        }
        root.dragInfo = null
        root.dropIndex = -1
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: root.unusedActions.length > 0 ? 42 : 0
        visible: root.unusedActions.length > 0
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6

            StyledText {
                text: Translation.tr("Unused")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                orientation: ListView.Horizontal
                spacing: 4
                clip: true
                model: root.unusedActions

                delegate: RippleButton {
                    id: unusedActionButton
                    required property var modelData
                    required property int index
                    readonly property string actionId: String(modelData ?? "")
                    width: 32
                    height: 32
                    buttonRadius: Appearance.rounding.full
                    Accessible.name: Translation.tr("Add to Quick Actions")
                        + ": " + root.actionLabel(actionId)
                    onClicked: root.addAction(actionId)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.actionIcon(unusedActionButton.actionId)
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledToolTip {
                        text: Translation.tr("Add to Quick Actions")
                            + " · " + root.actionLabel(unusedActionButton.actionId)
                    }
                }
            }
        }
    }

    Repeater {
        model: root.activeActions

        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            readonly property string actionId: String(modelData ?? "")
            Layout.fillWidth: true
            implicitHeight: root.rowHeight
            clip: false

            DropArea {
                anchors.fill: parent
                enabled: root.dragging
                onEntered: drag => {
                    if (drag.source && drag.source.actionId !== slot.actionId)
                        root.dropIndex = slot.index
                }
            }

            Rectangle {
                id: row
                property string actionId: slot.actionId
                width: slot.width
                height: root.rowHeight
                x: 0
                y: 0
                z: handle.drag.active ? 100 : 1
                radius: Appearance.rounding.small
                color: handle.containsMouse || handle.drag.active
                    ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
                border.width: root.dropIndex === slot.index && root.dragging ? 1 : 0
                border.color: Appearance.colors.colPrimary
                Drag.active: handle.drag.active
                Drag.source: row
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 8

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "drag_indicator"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }

                        MouseArea {
                            id: handle
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            drag.target: row
                            drag.axis: Drag.YAxis
                            drag.minimumY: -slot.index * (root.rowHeight + root.spacing)
                            drag.maximumY: (root.activeActions.length - slot.index - 1)
                                * (root.rowHeight + root.spacing)
                            onPressed: {
                                root.dragInfo = {id: slot.actionId, index: slot.index}
                                root.dropIndex = slot.index
                            }
                            onReleased: {
                                row.Drag.drop()
                                root.commitDrop()
                                row.y = 0
                            }
                            onCanceled: {
                                root.dragInfo = null
                                root.dropIndex = -1
                                row.y = 0
                            }
                        }
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.actionIcon(slot.actionId)
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 120
                        Layout.alignment: Qt.AlignVCenter
                        text: root.actionLabel(slot.actionId)
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    RippleButton {
                        implicitWidth: 30
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        Accessible.name: Translation.tr("Remove from Quick Actions")
                        onClicked: root.removeAction(slot.actionId)

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "remove_circle"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }

                        StyledToolTip {
                            text: Translation.tr("Remove from Quick Actions")
                        }
                    }
                }
            }
        }
    }
}
