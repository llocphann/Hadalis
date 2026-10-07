pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.services
import qs.modules.common.widgets

Item {
    id: root
    property int currentPage: -1
    signal pageActivated(int pageIndex)
    signal pageHidden(int pageIndex)
    signal doneRequested()

    readonly property int rowHeight: 38
    readonly property var visiblePages: SettingsPageRegistry.navigationPageIndexes(false)
    readonly property var hiddenPages: SettingsPageRegistry.hiddenPages.filter(index =>
        SettingsPageRegistry.pages[index] && SettingsPageRegistry.isPageApplicable(index))

    component NavRow: Rectangle {
        id: row
        required property int pageIdx
        required property int flatIndex
        property bool hiddenSource: false
        readonly property var page: SettingsPageRegistry.pages[row.pageIdx] ?? null
        readonly property bool active: row.pageIdx === root.currentPage
        readonly property color iconTint: SettingsMaterialPreset.navigationIconColor(
            Math.max(0, row.flatIndex), Math.max(1, root.visiblePages.length), row.active)

        width: parent ? parent.width : 0
        height: root.rowHeight
        radius: Appearance.rounding.small
        color: row.active ? Appearance.colors.colPrimaryContainer
            : hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"
        HoverHandler { id: hover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 3
            spacing: 5

            MaterialSymbol {
                text: row.page?.icon ?? "settings"
                rotation: row.page?.iconRotation ?? 0
                iconSize: 17
                color: row.iconTint
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: row.page?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: row.active ? Font.Medium : Font.Normal
                color: row.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                elide: Text.ElideRight
                TapHandler {
                    enabled: !row.hiddenSource
                    onTapped: root.pageActivated(row.pageIdx)
                }
            }

            RippleButton {
                visible: !row.hiddenSource
                enabled: row.flatIndex > 0
                Layout.preferredWidth: 27
                Layout.preferredHeight: 27
                buttonRadius: Appearance.rounding.full
                opacity: enabled ? 1 : 0.32
                onClicked: SettingsArrangement.movePageFlat(row.pageIdx, -1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButton {
                visible: !row.hiddenSource
                enabled: row.flatIndex >= 0 && row.flatIndex < root.visiblePages.length - 1
                Layout.preferredWidth: 27
                Layout.preferredHeight: 27
                buttonRadius: Appearance.rounding.full
                opacity: enabled ? 1 : 0.32
                onClicked: SettingsArrangement.movePageFlat(row.pageIdx, 1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButton {
                Layout.preferredWidth: 27
                Layout.preferredHeight: 27
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    if (row.hiddenSource) {
                        SettingsArrangement.restorePage(row.pageIdx)
                    } else if (SettingsArrangement.hidePageById(row.pageIdx)) {
                        root.pageHidden(row.pageIdx)
                    }
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.hiddenSource ? "visibility" : "visibility_off"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: editorColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: editorColumn
            width: parent.width
            spacing: 4

            Rectangle {
                width: parent.width
                height: 40
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 5
                    spacing: 6
                    MaterialSymbol {
                        text: "reorder"
                        iconSize: 17
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Navigation tabs")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    RippleButton {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        buttonRadius: Appearance.rounding.full
                        onClicked: root.doneRequested()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "done"
                            iconSize: 17
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledToolTip { text: Translation.tr("Done editing") }
                    }
                }
            }

            Repeater {
                model: root.visiblePages
                delegate: NavRow {
                    required property int modelData
                    required property int index
                    pageIdx: modelData
                    flatIndex: index
                }
            }

            Rectangle {
                visible: root.hiddenPages.length > 0
                width: parent.width
                height: visible ? hiddenColumn.implicitHeight + 10 : 0
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer0
                Column {
                    id: hiddenColumn
                    x: 5
                    y: 5
                    width: parent.width - 10
                    spacing: 3
                    RowLayout {
                        width: parent.width
                        height: 28
                        MaterialSymbol {
                            text: "visibility_off"
                            iconSize: 16
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Hidden tabs")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                        }
                    }
                    Repeater {
                        model: root.hiddenPages
                        delegate: NavRow {
                            required property int modelData
                            required property int index
                            pageIdx: modelData
                            flatIndex: -1
                            hiddenSource: true
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                width: parent.width
                materialIcon: "restart_alt"
                mainText: Translation.tr("Reset navigation order")
                onClicked: SettingsArrangement.reset()
            }
        }
    }
}
