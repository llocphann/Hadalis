import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.calendar

DashCard {
    id: root
    signal requestEventsDialog(var event)

    CalendarWidget {
        Layout.fillWidth: true
        Layout.fillHeight: true
        dashboardAdaptive: true
        onOpenEventsDialog: editEvent =>
            root.requestEventsDialog(editEvent)
        onDayWithEventsClicked: date =>
            root.requestEventsDialog(date)
    }
}
