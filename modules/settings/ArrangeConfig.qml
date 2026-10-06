pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 20
    settingsPageName: Translation.tr("Arrange")

    readonly property var visiblePages: SettingsPageRegistry.navigationPageIndexes(false)
    readonly property var hiddenPages: SettingsPageRegistry.hiddenPages.filter(index =>
        SettingsPageRegistry.pages[index] && SettingsPageRegistry.isPageApplicable(index))

    component NavRow: Rectangle {
        id: row
        required property int pageIdx
        required property int flatIndex
        property bool hiddenSource: false
        readonly property var page: SettingsPageRegistry.pages[row.pageIdx] ?? null
        readonly property color iconTint: SettingsMaterialPreset.navigationIconColor(
            Math.max(0, row.flatIndex), Math.max(1, root.visiblePages.length), false)

        Layout.fillWidth: true
        implicitHeight: 48
        radius: Appearance.rounding.small
        color: hover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
        HoverHandler { id: hover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Appearance.rounding.small
                color: Qt.alpha(row.iconTint, 0.14)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.page?.icon ?? "settings"
                    rotation: row.page?.iconRotation ?? 0
                    iconSize: 18
                    color: row.iconTint
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.page?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.page?.desc ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            RippleButton {
                visible: !row.hiddenSource
                enabled: row.flatIndex > 0
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                buttonRadius: Appearance.rounding.full
                opacity: enabled ? 1 : 0.35
                onClicked: SettingsArrangement.movePageFlat(row.pageIdx, -1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip { text: Translation.tr("Move up") }
            }

            RippleButton {
                visible: !row.hiddenSource
                enabled: row.flatIndex >= 0 && row.flatIndex < root.visiblePages.length - 1
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                buttonRadius: Appearance.rounding.full
                opacity: enabled ? 1 : 0.35
                onClicked: SettingsArrangement.movePageFlat(row.pageIdx, 1)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip { text: Translation.tr("Move down") }
            }

            RippleButton {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                buttonRadius: Appearance.rounding.full
                onClicked: row.hiddenSource
                    ? SettingsArrangement.restorePage(row.pageIdx)
                    : SettingsArrangement.hidePageById(row.pageIdx)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: row.hiddenSource ? "visibility" : "visibility_off"
                    iconSize: 17
                    color: Appearance.colors.colSubtext
                }
                StyledToolTip {
                    text: row.hiddenSource
                        ? Translation.tr("Show in navigation")
                        : Translation.tr("Hide from navigation")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        collapsible: false
        icon: "reorder"
        title: Translation.tr("Navigation tabs")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("One flat tab list. Reorder the tabs or hide the ones you do not use.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
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
        }
    }

    SettingsCardSection {
        visible: root.hiddenPages.length > 0
        expanded: true
        collapsible: false
        icon: "visibility_off"
        title: Translation.tr("Hidden tabs")

        SettingsGroup {
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
        Layout.alignment: Qt.AlignRight
        materialIcon: "restart_alt"
        mainText: Translation.tr("Reset navigation order")
        onClicked: SettingsArrangement.reset()
    }
}
