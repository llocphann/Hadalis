import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.abyss.looks

ColumnLayout {
    id: root
    readonly property var player: MprisController.activePlayer
    spacing: 12
    Image {
        visible: source.toString().length > 0
        source: root.player?.trackArtUrl ?? ""
        Layout.preferredWidth: 100; Layout.preferredHeight: 100
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
    AbyssLabel { text: root.player?.trackTitle || "No media playing"; font.pixelSize: AbyssStyle.fontSize*1.25; Layout.fillWidth: true }
    AbyssLabel { text: root.player?.trackArtist || ""; color: AbyssStyle.textColorMuted; Layout.fillWidth: true }
    RowLayout {
        AbyssButton { glyph: "skip_previous"; description: "Previous track"; enabled: root.player?.canGoPrevious ?? false; onClicked: root.player.previous() }
        AbyssButton { glyph: root.player?.isPlaying ? "pause" : "play_arrow"; description: root.player?.isPlaying ? "Pause" : "Play"; enabled: root.player?.canTogglePlaying ?? false; onClicked: root.player.togglePlaying() }
        AbyssButton { glyph: "skip_next"; description: "Next track"; enabled: root.player?.canGoNext ?? false; onClicked: root.player.next() }
    }
}
