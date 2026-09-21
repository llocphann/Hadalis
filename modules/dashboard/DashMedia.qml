import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls

/**
 * Dashboard Media uses the same PlayerControl + CAVA + Equalizer contract as
 * the Bar/Sidebar media surfaces. Keep this file as an owner/composition layer;
 * transport, artwork, seek UI and visualizer belong to PlayerControl so those
 * surfaces cannot drift into separate media designs again.
 */
DashCard {
    id: root

    // Lifecycle is owned by DashboardContent/DashboardCanvas because this card
    // is hosted both by the standalone Dashboard and the embedded Overview.
    // Keep this writable: DashboardCanvas binds its host-specific presentation
    // state into every DashMedia instance.
    property bool presentationActive:
        GlobalStates.dashboardOpen || GlobalStates.overviewOpen

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property bool isPlaying: root.player?.isPlaying ?? false

    CavaProcess {
        id: dashMediaCava
        active: root.presentationActive && root.hasPlayer && root.isPlaying
        sampleCount: 64
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: root.compact ? 4 : 6

        Item {
            id: playerSurface
            Layout.fillWidth: true
            Layout.minimumHeight: root.hasPlayer ? 120 : 104
            Layout.preferredHeight: root.hasPlayer
                ? Appearance.sizes.mediaControlsHeight : 112

            Loader {
                id: sharedPlayerLoader
                anchors.fill: parent
                active: root.presentationActive && root.hasPlayer
                sourceComponent: PlayerControl {
                    player: root.player
                    visualizerPoints: dashMediaCava.points
                    visualizerMaxValue:
                        Math.max(1, dashMediaCava.normalizationCeiling)
                    compactLayout: true
                    radius: Appearance.rounding.normal
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4
                visible: !root.hasPlayer

                MaterialShapeWrappedMaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    text: "music_note"
                    shape: MaterialShape.Shape.Cookie4Sided
                    padding: 7
                    iconSize: 26
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("Nothing playing")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("No music is currently playing")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                }
            }
        }

        EqualizerPanel {
            id: equalizer
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            compactLayout: true
            active: root.presentationActive && root.visible
        }
    }
}
