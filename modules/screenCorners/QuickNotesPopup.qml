pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.sidebarRight.notepad
import qs.services

// Bottom-left hover surface for Quick Notes.
//
// Hover only reveals the shared Dashboard/Sidebar presentation. The layer-shell
// surface becomes an exclusive keyboard owner only after the actual editor
// gains QML focus, so brushing the corner never steals focus from another app.
Bar.StyledPopup {
    id: root

    required property Item anchorItem
    property bool editorFocused: false
    property bool entryBridgeHeld: false
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property real requestedPopupWidth: Math.max(280, Math.min(720,
        Config.options?.quickNotes?.popupWidth ?? 420))
    readonly property real requestedPopupHeight: Math.max(180, Math.min(640,
        Config.options?.quickNotes?.popupHeight ?? 300))

    hoverTarget: root.anchorItem
    attachmentEdgeOverride: root.cornerAttachmentEdge
    attachmentThicknessOverride: root.cornerAttachmentThickness
    hoverActivates: true
    alternativeVisibleCondition: root.editorFocused || root.entryBridgeHeld
    keyboardFocus: root.editorFocused
    exclusiveKeyboardFocus: true
    closeOnOutsideClick: root.editorFocused
    popupBackgroundMargin: 0

    function enterEditorMode(): void {
        const editor = notesViewLoader.item
        if (!root.active || !Notepad.ready || !editor)
            return

        // The editor's active-focus transition is the explicit user intent.
        // Switching the shared popup to Exclusive focus here makes Niri grant
        // keyboard ownership immediately instead of waiting for a second click.
        root.editorFocused = true
        editor.focus = true
        Qt.callLater(() => {
            if (root.editorFocused && notesViewLoader.item)
                notesViewLoader.item.focusEditor()
        })
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

    onRequestClose: root.leaveEditorMode()
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

        // Reuse the exact Dashboard/Sidebar Quick Notes presentation. The
        // nested Loader keeps the heavier editor/timers cold while this
        // monitor's hot-corner popup is not resident.
        Loader {
            id: notesViewLoader
            anchors.fill: parent
            active: root.active

            sourceComponent: QuickNotesView {
                margin: 0
                surfaceLocalTabSelection: true
                showHeader: true
                showZettelkastenActions: true

                // Only a real editor focus transition captures the keyboard.
                // Header/tab/tool interactions remain ordinary pointer actions.
                onEditorActivated: root.enterEditorMode()
            }
        }
    }
}
