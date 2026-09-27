pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.notificationCenter
import qs.services

// Keep the mature notification grouping, expansion, images, actions and links.
Item {
    id: root
    property string kind: "popup"
    property string outputName: ""
    signal closeRequested()
    readonly property bool center: kind === "center"
    readonly property real desiredWidth: Appearance.sizes.notificationPopupWidth
    readonly property real desiredHeight: popupLoader.item?.contentHeight ?? 0
    Component.onCompleted: if (center) Notifications.markAllRead()
    onCenterChanged: if (center) Notifications.markAllRead()
    Loader {
        anchors.fill: parent
        active: root.center
        sourceComponent: NotificationCenterContent {}
    }
    Loader {
        id: popupLoader
        anchors.fill: parent
        active: !root.center
        sourceComponent: NotificationListView { popup: true; clip: true }
    }
}
