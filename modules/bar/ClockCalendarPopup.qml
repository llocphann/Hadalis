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
        dialog.focusEditor()
    }

    onRequestClose: root.showEventsDialog = false
    onActiveChanged: {
        if (!active)
            root.showEventsDialog = false
    }

    Item {
        id: popupContent

        readonly property real editorPaneHeight: Math.max(320, Math.min(430,
            (root.presentationWindow?.height ?? 900) * 0.40))
        readonly property real editorSectionGap:
            root.showEventsDialog ? 10 : 0

        implicitWidth: calendarContent.implicitWidth
        implicitHeight: calendarContent.implicitHeight
            + (root.showEventsDialog
                ? popupContent.editorPaneHeight
                    + popupContent.editorSectionGap
                : 0)
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve:
                    Appearance.animation.elementResize.bezierCurve
            }
        }

        ClockCalendarContent {
            id: calendarContent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: implicitHeight
            onEventEditorRequested: (event) => root.openEventEditor(event)
        }

        Rectangle {
            id: editorDivider
            anchors {
                left: parent.left
                right: parent.right
                top: calendarContent.bottom
                topMargin: root.showEventsDialog ? 5 : 0
            }
            height: root.showEventsDialog ? 1 : 0
            visible: height > 0
            color: Appearance.colors.colLayer2
            opacity: 0.7
        }

        Item {
            id: editorPane
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: root.showEventsDialog
                ? popupContent.editorPaneHeight : 0
            clip: true
            opacity: root.showEventsDialog ? 1 : 0

            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve:
                        Appearance.animation.elementResize.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve:
                        Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Loader {
                id: eventsDialogLoader
                anchors {
                    fill: parent
                    topMargin: 9
                }
                active: root.eventsDialogLoaded && root.active
                onLoaded: Qt.callLater(root.prepareEventEditor)
                sourceComponent: EventsDialog {
                    anchors.fill: parent
                    show: root.showEventsDialog
                    embeddedPresentation: true
                    backgroundHeight: -1
                    onDismiss: root.showEventsDialog = false
                }
            }
        }
    }
}
