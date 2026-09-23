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
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))

    hoverTarget: root.anchorItem
    attachmentEdgeOverride: root.cornerAttachmentEdge
    attachmentThicknessOverride: root.cornerAttachmentThickness
    hoverActivates: true
    alternativeVisibleCondition: root.editorFocused
    keyboardFocus: root.editorFocused
    closeOnOutsideClick: root.editorFocused
    popupBackgroundMargin: 0

    function enterEditorMode(): void {
        if (!root.active)
            return
        root.editorFocused = true
        if (notesEditorLoader.item)
            notesEditorLoader.item.focus = true
        Qt.callLater(() => {
            if (notesEditorLoader.item)
                notesEditorLoader.item.focusEditor()
        })
    }

    function leaveEditorMode(): void {
        if (notesEditorLoader.item) {
            notesEditorLoader.item.flushPendingSave()
            notesEditorLoader.item.focus = false
        }
        root.editorFocused = false
    }

    onRequestClose: root.leaveEditorMode()
    onActiveChanged: {
        if (!active) {
            if (notesEditorLoader.item) {
                notesEditorLoader.item.flushPendingSave()
                notesEditorLoader.item.focus = false
            }
            root.editorFocused = false
        }
    }
    Component.onDestruction: {
        if (notesEditorLoader.item)
            notesEditorLoader.item.flushPendingSave()
    }

    property QtObject _escapeShortcut: Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.active && root.editorFocused
        onActivated: root.leaveEditorMode()
    }

    Item {
        id: contentRoot

        implicitWidth: Math.max(280, Math.min(720,
            Config.options?.quickNotes?.popupWidth ?? 420))
        implicitHeight: Math.max(180, Math.min(640,
            Config.options?.quickNotes?.popupHeight ?? 300))
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
                    visible: Notepad.ready && Notepad.tabs.length > 0
                    Layout.maximumWidth: 150
                    text: "· " + String(Notepad.tabs[Notepad.currentTab]?.title ?? "")
                    elide: Text.ElideRight
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                Item { Layout.fillWidth: true }

                StyledText {
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
