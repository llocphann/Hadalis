import QtQuick
import Quickshell
import qs.modules.sidebarLeft

Item {
    id: root
    property string outputName: ""
    property var participant: null
    signal closeRequested()
    SidebarLeftContent {
        anchors.fill: parent
        sidebarWidth: root.width
        sidebarPadding: 8
        screenWidth: root.participant?.width ?? 1920
        screenHeight: root.height
        panelScreen: Quickshell.screens.find(s => s.name === root.outputName) ?? null
        externalConnectedSurface: true
        panelVisible: root.participant?.open ?? true
    }
}
