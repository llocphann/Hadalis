import QtQuick
import qs.modules.controlPanel

Item {
    id: root
    property var participant: null
    ControlPanelContent {
        anchors.fill: parent
        embeddedSurface: true
        screenWidth: root.participant?.width ?? 1920
        screenHeight: root.participant?.height ?? 1080
    }
}
