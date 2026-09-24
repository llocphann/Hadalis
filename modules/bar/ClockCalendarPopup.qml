import QtQuick
import qs.modules.sidebarRight.events

StyledPopup {
    id: root

    property bool showEventsDialog: false
    property bool eventsDialogLoaded: false
    property var eventsDialogEditEvent: null
    alternativeVisibleCondition: root.showEventsDialog
    keyboardFocusOnDemand: true
    keyboardFocus: root.showEventsDialog
    exclusiveKeyboardFocus: true
    outsideClickBackdropBelowPopup: true
    closeOnOutsideClick: root.showEventsDialog

    function openEventEditor(event): void {
        root.eventsDialogEditEvent = event
        root.eventsDialogLoaded = true
        root.showEventsDialog = true
        Qt.callLater(root.prepareEventEditor)
    }

    function prepareEventEditor(): void {
        const dialog = eventsDialogLoader.item
        if (!dialog || !root.showEventsDialog)
            return
        const event = root.eventsDialogEditEvent
        if (event instanceof Date) {
            dialog.resetForm()
            dialog.eventDate = event
        } else if (event) {
            dialog.loadEvent(event)
        } else {
            dialog.resetForm()
        }
        dialog.forceActiveFocus()
    }

    onRequestClose: root.showEventsDialog = false
    onActiveChanged: {
        if (!active)
            root.showEventsDialog = false
    }

    Item {
        implicitWidth: calendarContent.implicitWidth
        implicitHeight: calendarContent.implicitHeight
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        ClockCalendarContent {
            id: calendarContent
            anchors.fill: parent
            onEventEditorRequested: (event) => root.openEventEditor(event)
        }

        Loader {
            id: eventsDialogLoader
            anchors.fill: parent
            active: root.eventsDialogLoaded && root.active
            onLoaded: Qt.callLater(root.prepareEventEditor)
            sourceComponent: EventsDialog {
                anchors.fill: parent
                show: root.showEventsDialog
                backgroundHeight: Math.max(300, Math.min(500,
                    (parent?.height ?? 520) - 20))
                onDismiss: root.showEventsDialog = false
            }
        }
    }
}
