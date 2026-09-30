import QtQuick
import qs.modules.abyss.looks

Item {
    id: root
    property string edge: "top"
    property real edgeOffset: 120
    property real reveal: 1
    property real gazeX: 0
    property real gazeY: 0
    property bool interactive: true
    readonly property bool verticalEdge: edge === "left" || edge === "right"
    signal activated()

    implicitWidth: verticalEdge ? 98 : 112
    implicitHeight: verticalEdge ? 112 : 98
    visible: reveal > 0.001

    WaterDropletBody {
        id: droplet
        width: 76; height: 92
        gazeX: root.gazeX
        gazeY: root.gazeY
        enabled: root.interactive
        opacity: root.reveal
        rotation: root.edge === "left" ? 90 : root.edge === "right" ? -90 : root.edge === "bottom" ? 180 : 0
        transformOrigin: Item.Bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        onPressed: root.activated()
    }

    Rectangle {
        z: -1
        width: root.verticalEdge ? 10 : 58
        height: root.verticalEdge ? 58 : 10
        radius: 6
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        color: Qt.alpha(AbyssStyle.accent, 0.16)
        border.color: Qt.alpha(AbyssStyle.specular, 0.2)
    }
}
