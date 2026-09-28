pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.modules.abyss.looks
import qs.modules.sidebarRight.wifiNetworks
import qs.modules.sidebarRight.bluetoothDevices

// Keep the mature connection forms inside the existing Screen Edge host.
Item {
    id: root
    property string kind: "wifi"
    implicitWidth: 380
    implicitHeight: 500
    property alias dialog: form.item
    signal closeRequested()
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            AbyssButton {
                glyph: root.kind === "wifi" ? Network.materialSymbol : BluetoothStatus.activeIcon
                text: (root.kind === "wifi" ? Network.wifiEnabled : BluetoothStatus.enabled) ? "On" : "Off"
                description: root.kind === "wifi" ? "Wi-Fi radio" : "Bluetooth radio"
                enabled: root.kind === "wifi" || BluetoothStatus.available
                checked: root.kind === "wifi" ? Network.wifiEnabled : BluetoothStatus.enabled
                onClicked: root.kind === "wifi" ? Network.toggleWifi() : BluetoothStatus.toggle()
            }
            Item { Layout.fillWidth: true }
            AbyssButton {
                glyph: "refresh"
                text: root.kind === "wifi" ? (Network.wifiScanning ? "Scanning…" : "Scan")
                    : (Bluetooth.defaultAdapter?.discovering ?? false) ? "Stop scan" : "Scan"
                enabled: root.kind === "wifi" ? Network.wifiEnabled && !Network.wifiScanning : BluetoothStatus.enabled
                onClicked: {
                    if (root.kind === "wifi") Network.rescanWifi()
                    else if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                }
            }
        }
        Loader {
            id: form
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.kind === "wifi" ? wifi : bluetooth
        }
    }
    Component {
        id: wifi
        WifiDialog { embeddedPresentation: true; show: true; onDismiss: root.closeRequested() }
    }
    Component {
        id: bluetooth
        BluetoothDialog { embeddedPresentation: true; show: true; onDismiss: root.closeRequested() }
    }
}
