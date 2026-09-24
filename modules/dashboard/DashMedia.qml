import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls

/**
 * Dashboard Media reuses the canonical PlayerControl transport/artwork/seek
 * surface and the shared EqualizerPanel. The media card intentionally does not
 * run a CAVA visualizer: DSP visualization already belongs to EqualizerPanel,
 * so the player surface stays quiet and avoids duplicate audio analysis.
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
                // Keep the shared PlayerControl resident for the lifetime of
                // this Dashboard media card once a player exists. Recreating it
                // at every presentation resets ColorQuantizer/artwork masks
                // during the parent slide, which produced the cyan/blank flash.
                // Expensive CAVA/EasyEffects activity remains presentation-gated
                // below, so hidden residency does not keep those backends hot.
                active: root.hasPlayer
                sourceComponent: PlayerControl {
                    player: root.player
                    visualizerPoints: []
                    showVisualizer: false
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
