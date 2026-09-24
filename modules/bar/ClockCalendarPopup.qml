import QtQuick
import qs.modules.sidebarRight.events

StyledPopup {
    id: root

    Item {
        id: popupContent

        implicitWidth: calendarContent.implicitWidth
        implicitHeight: calendarContent.implicitHeight
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        ClockCalendarContent {
            id: calendarContent
            anchors.fill: parent
        }
    }
}
