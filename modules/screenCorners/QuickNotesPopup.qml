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

    hoverTarget: root.anchorItem
    attachmentEdgeOverride: "bottom"
    attachmentThicknessOverride: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    hoverActivates: true
    alternativeVisibleCondition: root.editorFocused
    keyboardFocus: root.editorFocused
    closeOnOutsideClick: root.editorFocused
    popupBackgroundMargin: 0

    function enterEditorMode(): void {
        if (!root.active)
            return
        root.editorFocused = true
        notesEditor.focus = true
        Qt.callLater(() => notesEditor.focusEditor())
    }

    function leaveEditorMode(): void {
        notesEditor.flushPendingSave()
        root.editorFocused = false
        notesEditor.focus = false
    }

    onRequestClose: root.leaveEditorMode()
    onActiveChanged: {
        if (!active) {
            notesEditor.flushPendingSave()
            root.editorFocused = false
            notesEditor.focus = false
        }
    }
    Component.onDestruction: notesEditor.flushPendingSave()

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

                NotepadWidget {
                    id: notesEditor
                    anchors.fill: parent
                    margin: 4
                    compactPresentation: true
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
