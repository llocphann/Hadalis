import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad

/**
 * Quick Notes card.
 *
 * Notepad tabs are draft buffers; a successful Dashboard capture becomes a
 * filesystem-canonical Zettelkasten note and removes the unchanged draft.
 */
DashCard {
    id: root
    title: Translation.tr("Quick Notes")
    icon: "note_stack"
    Layout.fillHeight: true

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Zettelkasten capture")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (Zettelkasten.errorMessage.length > 0)
                            return Zettelkasten.errorMessage
                        if (Zettelkasten.ready)
                            return Translation.tr("%1 note · draft clears after verified save")
                                .arg(Zettelkasten.defaultType)
                        return Translation.tr("Configure an Obsidian vault to capture notes")
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Zettelkasten.errorMessage.length > 0
                        ? Appearance.colors.colError
                        : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            RippleButton {
                Layout.preferredWidth: quickNoteRow.implicitWidth + 18
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: notepad.canSaveZettel
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: notepad.captureQuickNote()

                contentItem: RowLayout {
                    id: quickNoteRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        text: "note_add"
                        iconSize: 16
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Translation.tr("Capture")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }

                StyledToolTip {
                    text: Zettelkasten.ready
                        ? Translation.tr("Create a %1 Zettelkasten note. The unchanged draft is cleared only after the file is saved successfully.")
                            .arg(Zettelkasten.defaultType)
                        : Translation.tr("Configure an Obsidian vault to enable Zettelkasten")
                }
            }
        }

        NotepadWidget {
            id: notepad
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
        }
    }
}
