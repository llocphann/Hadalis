pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.ii.overlay
import qs.modules.notificationCenter
import qs.services

StyledOverlayWidget {
    id: root

    draggable: GlobalStates.overlayOpen
        && !notificationsHoverArea.containsMouse
        && !(centerContent.dragActive ?? false)

    minimumWidth: 360
    minimumHeight: 260

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius

        MouseArea {
            id: notificationsHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        NotificationCenterContent {
            id: centerContent
            anchors.fill: parent
            anchors.margins: 8
            showOpenCenterButton: true

            onOpenCenterRequested: {
                GlobalStates.overlayOpen = false
                Qt.callLater(() => GlobalStates.openNotificationCenter(""))
            }

            onExternalNavigationRequested:
                GlobalStates.overlayOpen = false
        }
    }
}
