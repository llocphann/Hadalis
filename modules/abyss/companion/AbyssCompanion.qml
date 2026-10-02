import QtQuick
import qs.modules.abyss.looks

Item {
    id: root
    property string edge: "top"
    property real edgeOffset: 120
    property real reveal: 1
    property real gazeX: 0
    property real gazeY: 0
    property real energy: 0.45
    property real bodySquash: 0
    property real bodyStretch: 0
    property real bodyLean: 0
    property real bodyTip: 0
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0
    property bool interactive: true
    readonly property bool verticalEdge: edge === "left" || edge === "right"
    readonly property bool hovered: droplet.hovered
    signal activated()

    implicitWidth: verticalEdge ? 98 : 112
    implicitHeight: verticalEdge ? 112 : 98
    visible: reveal > 0.001

    Behavior on reveal {
        enabled: AbyssStyle.motionEnabled
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    WaterDropletBody {
        id: droplet
        width: 76; height: 92
        visible: root.visible
        gazeX: root.gazeX
        gazeY: root.gazeY
        energy: root.energy
        stateSquash: root.bodySquash
        stateStretch: root.bodyStretch
        stateLean: root.bodyLean
        stateTip: root.bodyTip
        ripple: root.ripple
        eyeOpen: root.eyeOpen
        mouthCurve: root.mouthCurve
        pulse: root.pulse
        enabled: root.interactive
        opacity: root.reveal
        orientationAngle: root.edge === "left" ? 90 : root.edge === "right" ? -90 : root.edge === "bottom" ? 180 : 0
        // Centered bounds contain the rotated clickable body for all four
        // output edges. Verified in the offscreen four-edge prototype; keep
        // compositor input-mask changes as a separate qualification gate.
        transformOrigin: Item.Center
        anchors.centerIn: parent
        onPressed: root.activated()
    }

    Rectangle {
        z: -1
        width: root.verticalEdge ? 10 : 58
        height: root.verticalEdge ? 58 : 10
        radius: 6
        // Real nested AbyssField capture showed the previous strip sitting
        // on the OUTER tip side of rotated Wull. The soft base always points
        // INWARD to the field: bottom for top, top for bottom, right for
        // left and left for right. Keep this shadow behind the actual body.
        anchors.horizontalCenter: root.verticalEdge ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.verticalEdge ? parent.verticalCenter : undefined
        anchors.left: root.edge === "right" ? parent.left : undefined
        anchors.right: root.edge === "left" ? parent.right : undefined
        anchors.top: root.edge === "bottom" ? parent.top : undefined
        anchors.bottom: root.edge === "top" ? parent.bottom : undefined
        scale: 1 + root.ripple * 0.16
        opacity: 0.72 + root.ripple * 0.28
        color: Qt.alpha(AbyssStyle.accent, 0.16 + root.pulse * 0.10)
        border.color: Qt.alpha(AbyssStyle.specular, 0.2 + root.pulse * 0.16)

        Behavior on scale {
            enabled: AbyssStyle.motionEnabled
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
