import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad

/**
 * Notes card: shared multi-tab notepad plus explicit Zettelkasten quick capture.
 */
DashCard {
    id: root
    title: Translation.tr("Notes")
    icon: "edit_note"
    Layout.fillHeight: true

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item { Layout.fillWidth: true }

            RippleButton {
                Layout.preferredWidth: quickNoteRow.implicitWidth + 18
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: notepad.canSaveZettel
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: notepad.saveAsZettel()

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
                        text: Translation.tr("Quick note → Zettelkasten")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }

                StyledToolTip {
                    text: Zettelkasten.ready
                        ? Translation.tr("Save the current note as a Fleeting Zettelkasten note")
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
