import QtQuick
import Quickshell
import qs.modules.sidebarRight

Item {
    id: root
    property string outputName: ""
    property var participant: null
    readonly property real preferredContentHeight:sidebar.preferredContentHeight
    signal closeRequested()
    CompactSidebarRightContent {
        id:sidebar
        anchors.fill: parent
        sidebarWidth: root.width
        sidebarPadding: 8
        screenWidth: root.participant?.width ?? 1920
        screenHeight: root.participant?.height ?? 1080
        panelScreen: Quickshell.screens.find(s => s.name === root.outputName) ?? null
        externalConnectedSurface: true
        panelVisible: root.participant?.open ?? true
    }
}
