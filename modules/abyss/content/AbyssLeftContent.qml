import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.abyss.looks

Item {
    id: root
    property string outputName: ""
    property string tab: "tools"
    signal closeRequested()
    ColumnLayout {
        anchors.fill: parent
        spacing: AbyssStyle.sectionSpacing
        RowLayout {
            Layout.fillWidth: true
            AbyssLabel { text: "Abyss"; font.pixelSize: AbyssStyle.fontSize*1.4; font.bold: true; Layout.fillWidth: true }
            AbyssButton { glyph: "close"; description: "Close feature panel"; onClicked: root.closeRequested() }
        }
        RowLayout {
            AbyssButton { text: "Tools"; checked: root.tab === "tools"; onClicked: root.tab = "tools" }
            AbyssButton { text: "AI"; checked: root.tab === "ai"; onClicked: root.tab = "ai" }
            AbyssButton { text: "Music"; checked: root.tab === "music"; onClicked: root.tab = "music" }
        }
        AbyssSeparator { Layout.fillWidth: true }
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            active: root.tab !== "tools"
            source: root.tab === "ai" ? "../../sidebarLeft/AiChat.qml" : "../../sidebarLeft/LocalMusicView.qml"
        }
        ColumnLayout {
            visible: root.tab === "tools"
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: AbyssStyle.sectionSpacing
            AbyssButton { text: "Applications & workspaces"; glyph: "apps"; Layout.fillWidth: true; onClicked: GlobalStates.toggleOverview(root.outputName) }
            AbyssButton { text: "Clipboard history"; glyph: "content_paste"; Layout.fillWidth: true; onClicked: GlobalStates.clipboardOpen = true }
            AbyssButton { text: "Wallpaper"; glyph: "wallpaper"; Layout.fillWidth: true; onClicked: GlobalStates.wallpaperSelectorOpen = true }
            AbyssButton { text: "Screenshot"; glyph: "screenshot_region"; Layout.fillWidth: true; onClicked: GlobalStates.openRegionScreenshot() }
            AbyssButton { text: "Settings"; glyph: "settings"; Layout.fillWidth: true; onClicked: GlobalStates.openSettingsSection(10,"abyss") }
            Item { Layout.fillHeight: true }
        }
    }
}
