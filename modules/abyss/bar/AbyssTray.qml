pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import qs.modules.bar as SharedTray

// Reuse only the existing tray icon/menu interaction, without a module surface.
Item {
    id: root
    property bool vertical: false
    Repeater {
        model: SystemTray.items.values
        SharedTray.SysTrayItem {
            required property var modelData
            required property int index
            item: modelData
            x: root.vertical ? (root.width-width)/2 : index*26
            y: root.vertical ? index*26 : (root.height-height)/2
            width: 22
            height: 22
        }
    }
}
