pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property bool showOpenCenterButton: false
    readonly property bool dragActive: listview.dragIndex >= 0
    readonly property bool searchVisible: Notifications.list.length > 3

    signal openCenterRequested()
    signal searchFocusRequested()

    function focusSearch(): void {
        searchField.forceActiveFocus()
    }

    function clearSearchFocus(): void {
        searchField.focus = false
    }

    Component.onCompleted: Notifications.ensureInitialized()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: Notifications.silent ? "notifications_paused" : "notifications"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Notifications")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Notifications.silent
                        ? Translation.tr("Silent · %1 total").arg(Notifications.list.length)
                        : Translation.tr("%1 unread · %2 total")
                            .arg(Notifications.unread).arg(Notifications.list.length)
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                enabled: Notifications.unread > 0
                onClicked: Notifications.markAllRead()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "done_all"
                    iconSize: 17
                    color: parent.enabled
                        ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                }

                StyledToolTip { text: Translation.tr("Mark all as read") }
            }

            RippleButton {
                visible: root.showOpenCenterButton
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                onClicked: root.openCenterRequested()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "open_in_new"
                    iconSize: 17
                    color: Appearance.colors.colOnLayer1
                }

                StyledToolTip { text: Translation.tr("Open notification center") }
            }
        }

        ToolbarTextField {
            id: searchField
            visible: root.searchVisible
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 36
            placeholderText: Translation.tr("Search notifications")
            onVisibleChanged: {
                if (!visible) text = ""
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.searchFocusRequested()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            NotificationListView {
                id: listview
                anchors.fill: parent
                clip: true
                popup: false
                filterQuery: searchField.text
            }

            MaterialPlaceholderMessage {
                anchors.centerIn: parent
                maximumWidth: Math.min(280, parent.width - 24)
                compact: true
                shown: Notifications.list.length === 0
                    || (root.searchVisible && searchField.text.trim().length > 0
                        && listview.count === 0)
                icon: Notifications.list.length === 0
                    ? "notifications_active" : "search_off"
                text: Notifications.list.length === 0
                    ? (Notifications.silent
                        ? Translation.tr("Muted")
                        : Translation.tr("All caught up"))
                    : Translation.tr("No matching notifications")
                shape: MaterialShape.Shape.Ghostish
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: Notifications.silent
                    ? "notifications_off" : "notifications_active"
                mainText: Notifications.silent
                    ? Translation.tr("Resume") : Translation.tr("Do Not Disturb")
                toggled: Notifications.silent
                onClicked: Notifications.toggleSilent()
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                materialIcon: "delete_sweep"
                mainText: Translation.tr("Clear all")
                enabled: Notifications.list.length > 0
                onClicked: Notifications.discardAllNotifications()
            }
        }
    }
}
