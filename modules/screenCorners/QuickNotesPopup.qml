pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad
import qs.modules.sidebarRight.pomodoro
import qs.modules.dashboard
import qs.services

// Bottom-left hover surface for notes, tasks and timers.
//
// Hover reveals two groups: notes/tasks and the three timer modes. The popup
// pre-arms OnDemand keyboard focus for the note and task editors, while timer
// controls remain pointer interactive without taking keyboard focus on hover.
Bar.StyledPopup {
    id: root

    required property Item anchorItem
    property bool editorFocused: false
    property bool entryBridgeHeld: false
    property int selectedMainTab: 0
    property int selectedNotesTab: 0
    readonly property int selectedTimerTab: Math.max(0, Math.min(
        2, Persistent.states?.timer?.tab ?? 0))
    property bool pinnedOpen: false
    // Notes/To-do is a transient child tray of the large Notes & To-do tab.
    // Its animated height participates in ColumnLayout so it takes space from
    // the editor instead of covering note content.
    property bool notesTrayOpen: false
    property bool timerTrayOpen: false
    // One animated progress drives both reserved layout height and opacity.
    // This avoids the 4px end-of-close snap from separate height/gap states and
    // also makes hover reversals continue smoothly from the current frame.
    property real notesTrayReveal:
        root.selectedMainTab === 0 && root.notesTrayOpen ? 1.0 : 0.0
    property real timerTrayReveal:
        root.selectedMainTab === 1 && root.timerTrayOpen ? 1.0 : 0.0

    Behavior on notesTrayReveal {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve:
                Appearance.animation.elementResize.bezierCurve
        }
    }

    Behavior on timerTrayReveal {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve:
                Appearance.animation.elementResize.bezierCurve
        }
    }

    readonly property bool todoDialogOpen: todoViewLoader.item?.showAddDialog ?? false
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property real requestedPopupWidth: Math.max(280, Math.min(720,
        Config.options?.quickNotes?.popupWidth ?? 420))
    // All Notes/To-do/Timers faces share one configured popup envelope.
    // Switching modes must never resize the corner surface underneath the user.
    readonly property real requestedPopupHeight: Math.max(300,
        Math.min(640, Config.options?.quickNotes?.popupHeight ?? 300))

    hoverTarget: root.anchorItem
    barAutoHideHoldEnabled: false
    attachmentEdgeOverride: root.cornerAttachmentEdge
    attachmentThicknessOverride: root.cornerAttachmentThickness
    hoverActivates: true
    alternativeVisibleCondition: root.editorFocused || root.todoDialogOpen
        || root.entryBridgeHeld || root.pinnedOpen
    // Pre-arm click-to-focus before the first editor click. OnDemand does not
    // steal focus merely because the hover popup is visible.
    keyboardFocusOnDemand: true
    keyboardFocus: root.editorFocused || root.todoDialogOpen
    exclusiveKeyboardFocus: true
    // Keep the fullscreen catcher below this Overlay surface so it cannot cover
    // the TextArea or replace its I-beam cursor after editor focus is acquired.
    outsideClickBackdropBelowPopup: true
    closeOnOutsideClick: root.editorFocused || root.todoDialogOpen
    popupBackgroundMargin: 0

    function enterEditorMode(): void {
        if (!root.active || !Notepad.ready || !notesViewLoader.item)
            return
        // editorActivated is emitted only after TextArea actually gains
        // activeFocus through the pre-armed OnDemand layer-shell surface.
        // From this point Exclusive focus simply preserves ownership while the
        // user types; it is no longer responsible for making the first click work.
        root.editorFocused = true
    }

    function leaveEditorMode(): void {
        entryBridgeTimer.stop()
        notesTrayHideTimer.stop()
        root.entryBridgeHeld = false
        root.notesTrayOpen = false
        if (notesViewLoader.item) {
            notesViewLoader.item.flushPendingSave()
            notesViewLoader.item.releaseEditorFocus()
        }
        root.editorFocused = false
    }

    function holdNotesTray(): void {
        notesTrayHideTimer.stop()
        if (root.selectedMainTab === 0)
            root.notesTrayOpen = true
    }

    function releaseNotesTray(): void {
        // A small grace period prevents the tray from blinking while the
        // pointer crosses child controls or the 4px visual gap.
        if (root.notesTrayOpen)
            notesTrayHideTimer.restart()
    }

    function holdTimerTray(): void {
        timerTrayHideTimer.stop()
        if (root.selectedMainTab === 1)
            root.timerTrayOpen = true
    }

    function releaseTimerTray(): void {
        if (root.timerTrayOpen)
            timerTrayHideTimer.restart()
    }

    onRequestClose: {
        root.leaveEditorMode()
        if (todoViewLoader.item)
            todoViewLoader.item.showAddDialog = false
    }
    onSelectedMainTabChanged: {
        root.leaveEditorMode()
        notesTrayHideTimer.stop()
        timerTrayHideTimer.stop()
        root.notesTrayOpen = false
        root.timerTrayOpen = false

        // Switching the large tab does not change HoverHandler state, so open
        // the newly selected child tray explicitly while the pointer is still
        // inside the shared dock.
        if (tabDockHover.hovered) {
            if (root.selectedMainTab === 0)
                root.holdNotesTray()
            else
                root.holdTimerTray()
        }
    }
    onSelectedNotesTabChanged: {
        root.leaveEditorMode()
        if (tabDockHover.hovered && root.selectedMainTab === 0)
            root.holdNotesTray()
    }
    onActiveChanged: {
        if (active) {
            if (!root.editorFocused) {
                root.entryBridgeHeld = true
                entryBridgeTimer.restart()
            }
            return
        }

        entryBridgeTimer.stop()
        root.entryBridgeHeld = false
        if (notesViewLoader.item) {
            notesViewLoader.item.flushPendingSave()
            notesViewLoader.item.releaseEditorFocus()
        }
        root.editorFocused = false
    }

    Component.onDestruction: {
        if (notesViewLoader.item)
            notesViewLoader.item.flushPendingSave()
    }

    // Give the pointer enough time to cross a bottom/left Bar owner before the
    // shared popup hover hand-off takes over. This is only an entry bridge; once
    // the body is reached, StyledPopup's normal full-body hover contract owns it.
    property QtObject _entryBridgeTimer: Timer {
        id: entryBridgeTimer
        interval: Math.max(260, Math.min(700,
            Math.round(root.cornerAttachmentThickness * 6)))
        repeat: false
        onTriggered: root.entryBridgeHeld = false
    }

    property QtObject _notesTrayHideTimer: Timer {
        id: notesTrayHideTimer
        interval: 220
        repeat: false
        onTriggered: root.notesTrayOpen = false
    }

    property QtObject _timerTrayHideTimer: Timer {
        id: timerTrayHideTimer
        interval: 220
        repeat: false
        onTriggered: root.timerTrayOpen = false
    }

    Item {
        id: contentRoot

        // Keep the release shortcut inside the reparented popup content so
        // Qt.WindowShortcut resolves against the actual layer-shell window.
        Shortcut {
            sequences: [StandardKey.Cancel]
            context: Qt.WindowShortcut
            enabled: root.active && root.editorFocused
            onActivated: root.leaveEditorMode()
        }

        // Settings describe the visible popup body, not just its inner
        // content. Subtract StyledPopup's canonical padding so the configured
        // width/height remain literal before output clamping.
        implicitWidth: Math.max(1,
            root.requestedPopupWidth - root._contentPadding * 2)
        implicitHeight: Math.max(1,
            root.requestedPopupHeight - root._contentPadding * 2)
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            Item {
                id: tabDock
                Layout.fillWidth: true
                // Expanding the dock changes the layout allocation itself, so
                // Quick Notes/To-do consumes editor height rather than drawing
                // over the editor.
                implicitHeight: mainTabs.height
                    + 32 * Math.max(root.notesTrayReveal,
                        root.timerTrayReveal)
                z: 20
                clip: false

                // One continuous hover owner covers the large tab, the visual
                // gap and the revealed tray. This avoids the old hand-off
                // flicker between two independent HoverHandlers.
                HoverHandler {
                    id: tabDockHover
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                    onHoveredChanged: {
                        if (hovered) {
                            if (root.selectedMainTab === 0)
                                root.holdNotesTray()
                            else
                                root.holdTimerTray()
                        } else {
                            root.releaseNotesTray()
                            root.releaseTimerTray()
                        }
                    }
                }

                PillTabBar {
                    id: mainTabs
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(276, Math.max(
                        180, contentRoot.width
                            - (popupPinButton.width + 12) * 2))
                    pillHeight: 30
                    currentIndex: root.selectedMainTab
                    tabs: [
                        { icon: "note_stack", label: Translation.tr("Notes & To-do") },
                        { icon: "timer", label: Translation.tr("Timers") }
                    ]
                    onTabSelected: index => root.selectedMainTab = index
                }

                IconToolbarButton {
                    id: popupPinButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    implicitWidth: 30
                    implicitHeight: 30
                    text: "push_pin"
                    toggled: root.pinnedOpen
                    onClicked: root.pinnedOpen = !root.pinnedOpen

                    StyledToolTip {
                        text: root.pinnedOpen
                            ? Translation.tr("Unpin this popup")
                            : Translation.tr("Pin this popup on the current tab")
                    }
                }

                Item {
                    id: notesTraySlot
                    anchors.top: mainTabs.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(260, Math.max(
                        160, contentRoot.width - 24))
                    // 32px = 4px visual separation + 28px pill. The entire
                    // extent collapses continuously so the editor receives
                    // space back without a final discrete jump.
                    height: 32 * root.notesTrayReveal
                    clip: true

                    PillTabBar {
                        id: notesTray
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        pillHeight: 28
                        currentIndex: root.selectedNotesTab
                        opacity: root.notesTrayReveal
                        tabs: [
                            { icon: "edit_note", label: Translation.tr("Quick Notes") },
                            { icon: "checklist", label: Translation.tr("To-do") }
                        ]
                        onTabSelected: index => root.selectedNotesTab = index
                    }
                }

                Item {
                    id: timerTraySlot
                    anchors.top: mainTabs.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(300, Math.max(
                        210, contentRoot.width - 24))
                    height: 32 * root.timerTrayReveal
                    clip: true

                    PillTabBar {
                        id: timerTray
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        pillHeight: 28
                        currentIndex: root.selectedTimerTab
                        opacity: root.timerTrayReveal
                        tabs: [
                            { icon: "search_activity", label: Translation.tr("Pomodoro") },
                            { icon: "hourglass_empty", label: Translation.tr("Timer") },
                            { icon: "timer", label: Translation.tr("Stopwatch") }
                        ]
                        onTabSelected: index => {
                            if (Persistent?.states?.timer)
                                Persistent.states.timer.tab = index
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: notesViewLoader
                    anchors.fill: parent
                    active: root.active && root.selectedMainTab === 0
                        && root.selectedNotesTab === 0
                    sourceComponent: QuickNotesView {
                        margin: 0
                        surfaceLocalTabSelection: true
                        showHeader: false
                        showZettelkastenActions: false
                        verticalDotNavigation: true
                        onEditorActivated: root.enterEditorMode()
                    }
                }

                Loader {
                    id: todoViewLoader
                    anchors.fill: parent
                    active: root.active && root.selectedMainTab === 0
                        && root.selectedNotesTab === 1
                    sourceComponent: DashTodo {
                        color: "transparent"
                    }
                }

                Loader {
                    id: timerViewLoader
                    anchors.fill: parent
                    active: root.active
                    visible: root.selectedMainTab === 1
                    sourceComponent: PomodoroWidget {
                        compactMode: true
                        showTabBar: false
                        showPinButton: false
                    }
                }
            }
        }
    }
}
