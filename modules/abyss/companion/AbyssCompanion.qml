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
        width: root.verticalEdge ? 10 : 28
        height: root.verticalEdge ? 28 : 10
        radius: 5
        // Two real nested shader captures showed the bright full-width
        // strip stays detached; swapping side anchors moved it AWAY from
        // the observed field rim. Use compact, theme-matched base necks:
        // side anchors remain rim-facing while the bottom neck meets
        // the upright rounded base. Keep these behind the live body.
        anchors.horizontalCenter: root.verticalEdge ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.verticalEdge ? parent.verticalCenter : undefined
        anchors.left: root.edge === "left" ? parent.left : undefined
        anchors.right: root.edge === "right" ? parent.right : undefined
        anchors.top: root.edge === "bottom" ? parent.top : undefined
        anchors.bottom: root.edge === "top" ? parent.bottom : undefined
        scale: 1 + root.ripple * 0.16
        opacity: 0.88 + root.ripple * 0.12
        // Same source material as real AbyssField.surface (theme-linked).
        // Reduce only the separate neck highlight, never the live body.
        color: AbyssStyle.surface
        border.color: Qt.alpha(AbyssStyle.specular, 0.08 + root.pulse * 0.04)

        Behavior on scale {
            enabled: AbyssStyle.motionEnabled
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
