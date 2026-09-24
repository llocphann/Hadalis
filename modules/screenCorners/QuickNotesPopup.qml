pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad
import qs.modules.sidebarRight.todo
import qs.modules.sidebarRight.pomodoro
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
    readonly property bool todoDialogOpen: todoViewLoader.item?.showAddDialog ?? false
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property real requestedPopupWidth: Math.max(280, Math.min(720,
        Config.options?.quickNotes?.popupWidth ?? 420))
    readonly property real requestedPopupHeight: Math.max(
        root.selectedMainTab === 0 && root.selectedNotesTab === 0 ? 300 : 380,
        Math.min(640, Config.options?.quickNotes?.popupHeight ?? 300))

    hoverTarget: root.anchorItem
    attachmentEdgeOverride: root.cornerAttachmentEdge
    attachmentThicknessOverride: root.cornerAttachmentThickness
    hoverActivates: true
    alternativeVisibleCondition: root.editorFocused || root.todoDialogOpen
        || root.entryBridgeHeld
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
        root.entryBridgeHeld = false
        if (notesViewLoader.item) {
            notesViewLoader.item.flushPendingSave()
            notesViewLoader.item.releaseEditorFocus()
        }
        root.editorFocused = false
    }

    onRequestClose: {
        root.leaveEditorMode()
        if (todoViewLoader.item)
            todoViewLoader.item.showAddDialog = false
    }
    onSelectedMainTabChanged: root.leaveEditorMode()
    onSelectedNotesTabChanged: root.leaveEditorMode()
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
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { icon: "note_stack", label: Translation.tr("Notes & To-do") },
                        { icon: "timer", label: Translation.tr("Timers") }
                    ]

                    delegate: Button {
                        id: mainTabButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 38
                        Accessible.name: modelData.label
                        onClicked: root.selectedMainTab = index
                        background: Rectangle {
                            radius: Appearance.rounding.normal
                            color: root.selectedMainTab === mainTabButton.index
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colLayer1
                        }
                        contentItem: RowLayout {
                            spacing: 6
                            MaterialSymbol {
                                text: mainTabButton.modelData.icon
                                iconSize: 18
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: mainTabButton.modelData.label
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer1
                                font.weight: root.selectedMainTab === mainTabButton.index
                                    ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }

            SecondaryTabBar {
                Layout.fillWidth: true
                visible: root.selectedMainTab === 0
                currentIndex: root.selectedNotesTab
                onCurrentIndexChanged: root.selectedNotesTab = currentIndex
                SecondaryTabButton {
                    buttonText: Translation.tr("Quick Notes")
                    buttonIcon: "edit_note"
                    selected: root.selectedNotesTab === 0
                }
                SecondaryTabButton {
                    buttonText: Translation.tr("To-do")
                    buttonIcon: "checklist"
                    selected: root.selectedNotesTab === 1
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
                        showHeader: true
                        showZettelkastenActions: true
                        onEditorActivated: root.enterEditorMode()
                    }
                }

                Loader {
                    id: todoViewLoader
                    anchors.fill: parent
                    active: root.active && root.selectedMainTab === 0
                        && root.selectedNotesTab === 1
                    sourceComponent: TodoWidget {}
                }

                Loader {
                    id: timerViewLoader
                    anchors.fill: parent
                    active: root.active && root.selectedMainTab === 1
                    sourceComponent: PomodoroWidget {
                        compactMode: true
                    }
                }
            }
        }
    }
}
