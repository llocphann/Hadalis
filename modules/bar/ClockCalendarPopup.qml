import QtQuick
import qs.modules.sidebarRight.events

StyledPopup {
    id: root

    // Inline editing stays inside the Events pane, but it still needs the
    // popup's keyboard grab while a text field is active.
    alternativeVisibleCondition: calendarContent.eventEditorActive
    keyboardFocusOnDemand: true
    keyboardFocus: calendarContent.eventEditorActive
    exclusiveKeyboardFocus: true
    outsideClickBackdropBelowPopup: true
    closeOnOutsideClick: calendarContent.eventEditorActive
    onRequestClose: calendarContent.closeEventEditor()
    onActiveChanged: {
        if (!active)
            calendarContent.closeEventEditor()
    }

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
