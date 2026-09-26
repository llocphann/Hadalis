import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.abyss.looks

Flickable {
    id: root
    property string outputName: ""
    readonly property var output: Quickshell.screens.find(s => s.name === outputName) ?? null
    readonly property var monitor: output ? Brightness.getMonitorForScreen(output) : null
    signal closeRequested()
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: ResourceUsage.keepAlive(false,false)
    Component.onDestruction: ResourceUsage.releaseKeepAlive(false,false)
    ColumnLayout {
        id: column
        width: root.width
        spacing: AbyssStyle.sectionSpacing
        RowLayout {
            AbyssLabel { text: "System"; font.pixelSize: AbyssStyle.fontSize*1.4; font.bold: true; Layout.fillWidth: true }
            AbyssButton { glyph: "notifications"; description: "Notification history"; onClicked: GlobalStates.toggleNotificationCenter(root.outputName) }
            AbyssButton { glyph: "close"; description: "Close system panel"; onClicked: root.closeRequested() }
        }
        AbyssLabel { text: "CPU  "+Math.round(ResourceUsage.cpuUsage*100)+"%    "+ResourceUsage.cpuTemp+"°\nRAM  "+Math.round(ResourceUsage.memoryUsedPercentage*100)+"%\nGPU  "+Math.round(ResourceUsage.gpuUsage*100)+"%\nStorage  "+Math.round(ResourceUsage.diskUsedPercentage*100)+"%"; Layout.fillWidth: true }
        AbyssSeparator { Layout.fillWidth: true }
        AbyssLabel { text: "Volume · "+Math.round(Audio.value*100)+"%" }
        AbyssSlider { Layout.fillWidth: true; value: Audio.value; onMoved: Audio.setSinkVolume(value) }
        AbyssLabel { text: "Brightness"; visible: root.monitor !== null }
        AbyssSlider { visible: root.monitor !== null; Layout.fillWidth: true; value: root.monitor?.brightness ?? 0; onMoved: if (root.monitor) root.monitor.setBrightness(value) }
        RowLayout {
            AbyssButton { glyph: "wifi"; description: "Toggle Wi-Fi"; checked: Network.wifiEnabled; onClicked: Network.toggleWifi() }
            AbyssButton { glyph: "bluetooth"; description: "Toggle Bluetooth"; checked: BluetoothStatus.enabled; enabled: BluetoothStatus.available; onClicked: BluetoothStatus.toggle() }
            AbyssButton { glyph: "notifications_off"; description: "Do not disturb"; checked: Notifications.silent; onClicked: Notifications.toggleSilent() }
            AbyssButton { glyph: "volume_off"; description: "Mute audio"; onClicked: Audio.toggleMute() }
        }
        AbyssLabel { text: Network.connectionTooltip(); color: AbyssStyle.textColorMuted; Layout.fillWidth: true }
        AbyssSeparator { Layout.fillWidth: true }
        AbyssLabel { text: "Now Playing"; font.bold: true }
        Loader { Layout.fillWidth: true; source: "AbyssMediaSection.qml" }
        AbyssSeparator { Layout.fillWidth: true }
        AbyssLabel { text: "Locations"; font.bold: true }
        RowLayout {
            AbyssButton { text: "Home"; glyph: "home"; onClicked: Qt.openUrlExternally("file://"+Directories.homePath) }
            AbyssButton { text: "Downloads"; glyph: "download"; onClicked: Qt.openUrlExternally("file://"+Directories.downloadsPath) }
        }
        AbyssSeparator { Layout.fillWidth: true }
        AbyssLabel { text: "Weather"; font.bold: true }
        AbyssLabel { text: Weather.enabled ? Weather.data.temp+" · "+Weather.data.description+(Weather.showVisibleCity ? "\n"+Weather.visibleCity : "") : "Weather is disabled"; Layout.fillWidth: true }
        RowLayout {
            AbyssButton { text: "Settings"; glyph: "settings"; onClicked: GlobalStates.openSettingsPage(1) }
            AbyssButton { text: "Session"; glyph: "power_settings_new"; onClicked: GlobalStates.sessionOpen = true }
        }
    }
}
