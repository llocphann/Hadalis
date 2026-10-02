import QtQuick
import QtQuick.Shapes
import qs.modules.abyss.looks

Item {
    id: root
    property real energy: 0.45
    property real gazeX: 0
    property real gazeY: 0
    property bool motionEnabled: AbyssStyle.motionEnabled && visible
    property real squash: 0
    property real bob: 0
    property real sway: 0
    property real shimmer: 0
    property real stateSquash: 0
    property real stateStretch: 0
    property real stateLean: 0
    property real stateTip: 0
    // Static attachment orientation is independent of alive local sway/lean.
    property real orientationAngle: 0
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0
    readonly property bool hovered: hoverHandler.hovered
    signal pressed()

    implicitWidth: 76
    implicitHeight: 92
    transformOrigin: Item.Bottom

    scale: 1 + squash * 0.035
    y: bob
    rotation: orientationAngle + sway * 2.2 + stateLean * 5.0 + stateTip * 2.4
    transform: Scale {
        origin.x: root.width * 0.5
        origin.y: root.height
        xScale: 1 + root.stateSquash * 0.05 - root.stateStretch * 0.025
        yScale: 1 - root.stateSquash * 0.035 + root.stateStretch * 0.06
    }

    Rectangle {
        z: -1
        anchors.centerIn: parent
        width: parent.width * (0.82 + root.pulse * 0.18)
        height: parent.height * (0.78 + root.pulse * 0.20)
        radius: width * 0.5
        color: Qt.alpha(AbyssStyle.accent, 0.16)
        opacity: root.pulse * 0.48
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        ShapePath {
            strokeWidth: 1.2
            strokeColor: Qt.alpha(AbyssStyle.specular, 0.58)
            fillGradient: LinearGradient {
                x1: 8; y1: 8; x2: root.width - 4; y2: root.height
                GradientStop { position: 0; color: Qt.lighter(AbyssStyle.accent, 1.12) }
                GradientStop { position: 0.42; color: AbyssStyle.surfaceRaised }
                GradientStop { position: 1; color: AbyssStyle.surfaceDeep }
            }
            startX: root.width * 0.5; startY: 2
            // Six round Bézier lobes: a gently flattened soft tip and fuller
            // shoulders, instead of the previous sharp triangular outline.
            PathCubic { x: root.width * 0.16; y: root.height * 0.33; control1X: root.width * 0.42; control1Y: 2; control2X: root.width * 0.23; control2Y: root.height * 0.15 }
            PathCubic { x: root.width * 0.035; y: root.height * 0.57; control1X: root.width * 0.08; control1Y: root.height * 0.41; control2X: root.width * 0.035; control2Y: root.height * 0.47 }
            PathCubic { x: root.width * 0.5; y: root.height - 3; control1X: root.width * 0.008; control1Y: root.height * 0.83; control2X: root.width * 0.25; control2Y: root.height - 3 }
            PathCubic { x: root.width * 0.965; y: root.height * 0.57; control1X: root.width * 0.75; control1Y: root.height - 3; control2X: root.width * 0.992; control2Y: root.height * 0.83 }
            PathCubic { x: root.width * 0.84; y: root.height * 0.33; control1X: root.width * 0.965; control1Y: root.height * 0.47; control2X: root.width * 0.92; control2Y: root.height * 0.41 }
            PathCubic { x: root.width * 0.5; y: 2; control1X: root.width * 0.77; control1Y: root.height * 0.15; control2X: root.width * 0.58; control2Y: 2 }
        }
    }

    Rectangle {
        width: 17; height: 28; radius: 10
        x: 15 + shimmer * 5; y: 20 + shimmer * 3
        rotation: 24
        color: Qt.alpha(AbyssStyle.specular, 0.42)
    }

    // Counter-rotate the COMPLETE face around the body center; all four
    // panel orientations keep readable upright eyes, cheeks and mouth.
    Item {
        id: faceOverlay
        anchors.fill: parent
        transformOrigin: Item.Center
        rotation: -root.orientationAngle

        // Larger paired eyes and layered moving catchlights stay procedural.
        Row {
            spacing: 15
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
            Repeater {
                model: 2
                Item {
                    width: 14; height: 18
                    Rectangle {
                        width: parent.width
                        height: Math.max(1, parent.height * root.eyeOpen)
                        anchors.centerIn: parent
                        radius: width / 2
                        color: AbyssStyle.textColor
    
                        Rectangle {
                            width: 6; height: Math.min(7, parent.height)
                            radius: width / 2
                            x: Math.max(1, Math.min(parent.width - width - 1, 3 + root.gazeX * 2))
                            y: Math.max(0, Math.min(parent.height - height, (parent.height - height) * 0.5 + root.gazeY * 2))
                            color: AbyssStyle.surfaceDeep
                        }
                        Rectangle {
                            width: 3; height: Math.min(3, parent.height)
                            radius: 2
                            x: 2; y: Math.min(2, Math.max(0, parent.height - height))
                            color: AbyssStyle.specular
                        }
                        Rectangle {
                            width: 1.5; height: Math.min(1.5, parent.height)
                            radius: 1
                            x: 10; y: Math.min(9, Math.max(0, parent.height - height))
                            color: Qt.alpha(AbyssStyle.specular, 0.8)
                        }
                    }
                }
            }
        }
    
        // Two small warm cheek glints; body, pupil and specular colors still
        // track the desktop theme and no reference artwork enters runtime.
        Row {
            spacing: 37
            anchors.horizontalCenter: parent.horizontalCenter
            y: 63
            Repeater {
                model: 2
                Rectangle {
                    width: 9; height: 5; radius: 2.5
                    color: Qt.rgba(1.0, 0.42, 0.58, 0.42)
                    opacity: 0.54 + root.pulse * 0.23
                }
            }
        }
    
        Shape {
            width: 24; height: 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: 67
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(AbyssStyle.textColor, 0.86)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                startX: 3; startY: 6 - root.mouthCurve * 2
                PathCubic {
                    x: 21; y: 6 - root.mouthCurve * 2
                    control1X: 8; control1Y: 6 + root.mouthCurve * 8
                    control2X: 16; control2Y: 6 + root.mouthCurve * 8
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.pressed()
            if (root.motionEnabled)
                squashBurst.restart()
        }
    }

    Behavior on stateSquash {
        enabled: root.motionEnabled
        SpringAnimation { spring: 3.2; damping: 0.34 }
    }
    Behavior on stateStretch {
        enabled: root.motionEnabled
        SpringAnimation { spring: 2.8; damping: 0.36 }
    }
    Behavior on stateLean {
        enabled: root.motionEnabled
        SpringAnimation { spring: 2.5; damping: 0.42 }
    }
    Behavior on stateTip {
        enabled: root.motionEnabled
        SpringAnimation { spring: 2.4; damping: 0.44 }
    }
    Behavior on eyeOpen {
        enabled: root.motionEnabled
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }
    Behavior on mouthCurve {
        enabled: root.motionEnabled
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on pulse {
        enabled: root.motionEnabled
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: squashBurst
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 85; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: -0.35; duration: 150; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "squash"; to: 0; duration: 210; easing.type: Easing.OutCubic }
    }
    SequentialAnimation on bob {
        running: root.motionEnabled; loops: Animation.Infinite
        NumberAnimation { to: -1.2 - root.energy * 2.4; duration: 1570; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.6 + root.energy * 1.2; duration: 2110; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on sway {
        running: root.motionEnabled; loops: Animation.Infinite
        NumberAnimation { to: 0.45 + root.energy; duration: 2390; easing.type: Easing.InOutSine }
        NumberAnimation { to: -0.3 - root.energy * 0.7; duration: 3170; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on shimmer {
        running: root.motionEnabled && AbyssStyle.quality !== "performance"; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 4300; easing.type: Easing.InOutSine }
    }
}
