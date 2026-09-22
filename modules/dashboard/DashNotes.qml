import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.notepad

/**
 * Quick Notes card.
 *
 * Notepad tabs are draft buffers; a successful Dashboard capture creates a
 * filesystem-canonical Zettelkasten note while preserving the source draft.
 * Dashboard presentation is deliberately terse: secondary state lives behind
 * icons/tooltips so the editor owns nearly all available height.
 */
DashCard {
    id: root
    title: ""
    icon: ""
    Layout.fillHeight: true

    readonly property bool constrainedHeight:
        root.height > 0 && root.height < 210

    readonly property string zettelStatusText: {
        if (Zettelkasten.errorMessage.length > 0)
            return Zettelkasten.errorMessage
        if (Zettelkasten.ready)
            return Translation.tr("%1 note · draft stays in Notepad")
                .arg(Zettelkasten.defaultType)
        return Translation.tr("Configure an Obsidian vault to capture notes")
    }

    function openZettelkastenSettings(): void {
        GlobalStates.openSettingsSection(7, "Quick Notes & Zettelkasten")
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 4

        // One compact identity/action row replaces the old title + two lines of
        // Zettelkasten prose. Hover exposes the same information without
        // permanently consuming editor space.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: "note_stack"
                iconSize: root.constrainedHeight
                    ? Appearance.font.pixelSize.normal
                    : Appearance.font.pixelSize.larger
                color: root.colAccent
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Quick Notes")
                font.pixelSize: root.constrainedHeight
                    ? Appearance.font.pixelSize.small
                    : Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }

            RippleButton {
                implicitWidth: root.constrainedHeight ? 28 : 30
                implicitHeight: implicitWidth
                buttonRadius: height / 2
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.openZettelkastenSettings()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: Zettelkasten.errorMessage.length > 0
                        ? "error"
                        : (Zettelkasten.ready ? "hub" : "link_off")
                    iconSize: 17
                    color: Zettelkasten.errorMessage.length > 0
                        ? Appearance.colors.colError
                        : (Zettelkasten.ready ? root.colAccent : root.colSubtext)
                }

                StyledToolTip {
                    text: Zettelkasten.errorMessage.length > 0
                        ? root.zettelStatusText
                        : (Zettelkasten.ready
                            ? Translation.tr("Zettelkasten capture") + " · "
                                + root.zettelStatusText
                            : root.zettelStatusText)
                }
            }

            RippleButton {
                implicitWidth: root.constrainedHeight ? 28 : 32
                implicitHeight: implicitWidth
                buttonRadius: height / 2
                enabled: notepad.canSaveZettel
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                onClicked: notepad.captureQuickNote()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "note_add"
                    iconSize: 17
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledToolTip {
                    text: Zettelkasten.ready
                        ? Translation.tr("Create a %1 Zettelkasten note while keeping the Notepad draft unchanged.")
                            .arg(Zettelkasten.defaultType)
                        : Translation.tr("Configure an Obsidian vault to enable Zettelkasten")
                }
            }
        }

        NotepadWidget {
            id: notepad
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.constrainedHeight ? 76 : 130
            compactPresentation: true
            margin: 0
        }
    }
}
