pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.functions
import qs.modules.abyss.looks

Item {
    id: root
    property string kind: "popup"
    property string outputName: ""
    signal closeRequested()
    readonly property bool center: kind === "center"
    readonly property var notifications: center ? [...Notifications.list].sort((a,b) => b.time-a.time) : Notifications.popupList
    Component.onCompleted: if (center) Notifications.markAllRead()
    onCenterChanged: if (center) Notifications.markAllRead()
    ColumnLayout {
        anchors.fill: parent
        spacing: AbyssStyle.sectionSpacing/2
        RowLayout {
            visible: root.center
            AbyssLabel { text: "Notifications"; font.bold: true; Layout.fillWidth: true }
            AbyssButton { glyph: "notifications_off"; description: "Do not disturb"; checked: Notifications.silent; onClicked: Notifications.toggleSilent() }
            AbyssButton { glyph: "delete_sweep"; description: "Clear notifications"; onClicked: Notifications.discardAllNotifications() }
            AbyssButton { glyph: "close"; description: "Close notifications"; onClicked: root.closeRequested() }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: AbyssStyle.sectionSpacing
            model: root.notifications
            delegate: ColumnLayout {
                id: row
                required property var modelData
                width: list.width
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    AbyssLabel { text: row.modelData.appName; color: AbyssStyle.textColorMuted; Layout.fillWidth: true }
                    AbyssButton { glyph: "close"; description: "Dismiss notification"; onClicked: Notifications.discardNotification(row.modelData.notificationId) }
                }
                AbyssLabel { text: row.modelData.summary; font.bold: true; Layout.fillWidth: true }
                AbyssLabel { text: StringUtils.stripHtmlTags(row.modelData.body); Layout.fillWidth: true; maximumLineCount: root.center ? 8 : 3; elide: Text.ElideRight }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: row.modelData.actions
                        AbyssButton {
                            required property var modelData
                            text: modelData.text
                            onClicked: Notifications.attemptInvokeAction(row.modelData.notificationId,modelData.identifier)
                        }
                    }
                }
                AbyssSeparator { Layout.fillWidth: true }
            }
        }
        AbyssLabel { visible: root.notifications.length === 0; text: "No notifications"; color: AbyssStyle.textColorMuted }
    }
}
