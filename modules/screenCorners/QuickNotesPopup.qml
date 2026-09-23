pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad
import qs.services

// Bottom-left hover surface for fast note capture.
//
// The popup deliberately reuses the canonical Notepad singleton/widget instead
// of introducing a second notes store. Hover only reveals the surface; keyboard
// focus is requested after an explicit click so merely brushing the corner never
// steals focus from the active application.
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
    closeOnOutsideClick: root.editorFocused
    popupBackgroundMargin: 0

    function enterEditorMode(): void {
        const editor = notesEditorLoader.item
        if (!root.active || !Notepad.ready || !editor)
            return
        // Hover preview must stay non-focusable until the shared Notepad is
        // actually ready to accept input. Otherwise an early click during
        // startup can grab the keyboard while presenting a disabled editor.
        root.editorFocused = true
        editor.focus = true
        Qt.callLater(() => {
            if (root.editorFocused && notesEditorLoader.item)
                notesEditorLoader.item.focusEditor()
        })
    }

    function leaveEditorMode(): void {
        entryBridgeTimer.stop()
        root.entryBridgeHeld = false
        if (notesEditorLoader.item) {
            notesEditorLoader.item.flushPendingSave()
            notesEditorLoader.item.focus = false
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
        if (notesEditorLoader.item) {
            notesEditorLoader.item.flushPendingSave()
            notesEditorLoader.item.focus = false
        }
        root.editorFocused = false
    }
    Component.onDestruction: {
        if (notesEditorLoader.item)
            notesEditorLoader.item.flushPendingSave()
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
        // Qt.WindowShortcut resolves against the actual layer-shell window
        // rather than the non-visual StyledPopup loader.
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
        // ConnectedSurfaceGeometry can clamp the requested body on small or
        // transformed outputs. Follow the actual content host size so the
        // editor reflows instead of being clipped at its configured width.
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "edit_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("Quick Notes")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                StyledText {
                    readonly property string activeTitle:
                        String(Notepad.tabs[Notepad.currentTab]?.title ?? "").trim()
                    visible: Notepad.ready && activeTitle.length > 0
                        && contentRoot.width >= 220
                    Layout.maximumWidth: contentRoot.width < 340 ? 80 : 150
                    text: "· " + activeTitle
                    elide: Text.ElideRight
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    visible: contentRoot.width >= 340
                    text: root.editorFocused
                        ? Translation.tr("Esc to release")
                        : Translation.tr("Click to type")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                clip: true

                // The shared editor is the only relatively heavy part of this
                // corner surface. Keep it unloaded while the popup is idle so
                // every monitor does not retain a duplicate Notepad view,
                // timers and service connections just to own a 14px hot corner.
                Loader {
                    id: notesEditorLoader
                    anchors.fill: parent
                    active: root.active
                    sourceComponent: NotepadWidget {
                        margin: 4
                        compactPresentation: true
                        quickCapturePresentation: true
                    }
                }

                // Observe a deliberate click anywhere inside the note surface,
                // including child controls, then make the layer surface
                // keyboard-focusable on the next event turn.
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.enterEditorMode()
                }
            }
        }
    }
}
