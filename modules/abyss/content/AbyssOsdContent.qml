import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.abyss.looks

ColumnLayout {
    id: root
    property string outputName: ""
    readonly property string indicatorKind: GlobalStates.abyssOsdKind
    readonly property var output: Quickshell.screens.find(s => s.name === outputName) ?? null
    readonly property var monitor: output ? Brightness.getMonitorForScreen(output) : null
    readonly property real amount: indicatorKind === "brightness" ? (monitor?.brightness ?? 0) : indicatorKind === "mic" ? Audio.micVolume : Audio.value
    spacing: AbyssStyle.sectionSpacing/2
    AbyssLabel {
        Layout.fillWidth: true
        text: root.indicatorKind === "media" ? (MprisController.activePlayer?.trackTitle || "Media")
            : root.indicatorKind === "keyboardLayout" ? KeyboardIndicators.popupText
            : root.indicatorKind === "voiceSearch" ? (VoiceSearch.running ? "Listening…" : "Voice search")
            : root.indicatorKind.charAt(0).toUpperCase()+root.indicatorKind.slice(1)+" · "+Math.round(root.amount*100)+"%"
        font.bold: true
    }
    Item {
        Layout.fillWidth: true; Layout.preferredHeight: 3
        visible: ["volume","brightness","mic"].includes(root.indicatorKind)
        Rectangle { anchors.fill: parent; color: AbyssStyle.textColorMuted; opacity: 0.2 }
        Rectangle { width: parent.width*Math.max(0,Math.min(1,root.amount)); height: parent.height; color: AbyssStyle.accent }
    }
    AbyssLabel { visible: (root.indicatorKind === "volume" && Audio.muted) || (root.indicatorKind === "mic" && Audio.micMuted); text: "Muted"; color: AbyssStyle.textColorMuted }
    AbyssLabel { visible: GlobalStates.abyssOsdMessage.length > 0; text: GlobalStates.abyssOsdMessage; Layout.fillWidth: true }
    Item { Layout.fillHeight: true }
}
