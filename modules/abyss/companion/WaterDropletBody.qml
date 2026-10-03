import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs.modules.abyss.looks
import qs.modules.common
import qs.modules.common.functions
import "WullExpressions.js" as Expressions

Item {
    id: root
    property string expression: "idle"
    property color accentColor: AbyssStyle.accent
    readonly property color reflectionColor: ColorUtils.colorWithLightness(accentColor, 0.85)
    property real energy: 0.45
    property real gazeX: 0
    property real gazeY: 0
    property bool motionEnabled: AbyssStyle.motionEnabled && visible
    property bool effectsEnabled: Appearance.effectsEnabled && AbyssStyle.quality !== "performance"
    property real squash: 0
    property real bob: 0
    property real sway: 0
    property real shimmer: 0
    property real stateSquash: 0
    property real stateStretch: 0
    property real stateLean: 0
    property real stateTip: 0
    property real orientationAngle: 0
    property real viewYaw: -15
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0
    property real reveal: 1
    property real reactionLift: 0
    property real reactionRipple: 0
    property real shine: 0
    readonly property var expressionProfile: Expressions.profile(expression)
    property real expressionSquash: expressionProfile.squash
    readonly property real motionAmount: motionEnabled ? AbyssStyle.motionIntensity : 0
    readonly property bool hovered: hoverHandler.hovered
    // QSB reflection reuse may leave status Uncompiled after drawing. A real
    // presented frame and a supported API are the authoritative readiness.
    property bool framePresented: false
    readonly property bool softwareFallback: GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool materialReady: framePresented && GraphicsInfo.api !== GraphicsInfo.Software
        && GraphicsInfo.api !== GraphicsInfo.Null && material.status !== ShaderEffect.Error
    Window.onWindowChanged: root.framePresented = false
    Connections {
        target: root.Window.window
        enabled: !root.framePresented
        function onFrameSwapped(): void { root.framePresented = true }
    }
    signal pressed()

    // Preserve placement and native input bounds. The body itself is square.
    implicitWidth: 76
    implicitHeight: 92
    transformOrigin: Item.Bottom
    scale: 1 + squash * 0.035 + (hovered ? 0.015 : 0)
    rotation: orientationAngle + sway * 2.2 + stateLean * 5.0 + stateTip * 2.4 + expressionProfile.tilt * 4
    transform: [
        Scale {
            origin.x: root.width * 0.5; origin.y: root.height * 0.5
            xScale: 1 + (root.stateSquash + root.expressionSquash) * 0.05 - root.stateStretch * 0.025 + root.squash * 0.06
            yScale: 1 - (root.stateSquash + root.expressionSquash) * 0.035 + root.stateStretch * 0.06 - root.squash * 0.05
        },
        Translate {
            y: (root.bob + root.reactionLift) * root.motionAmount + (1 - root.reveal) * 6 * root.motionAmount
        }
    ]
    Item {
        id: contact
        x: -9; y: 72.5; width: 94; height: 13; z: -1
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 47; centerY: 6.5; centerRadius: 47
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Qt.alpha(root.accentColor, 0.18) }
                    GradientStop { position: 1; color: "transparent" }
                }
                startX: 0; startY: 6.5
                PathArc { x: 94; y: 6.5; radiusX: 47; radiusY: 6.5 }
                PathArc { x: 0; y: 6.5; radiusX: 47; radiusY: 6.5 }
            }
        }
        Repeater {
            model: 3
            Shape {
                id: rippleRing
                required property int index
                visible: root.softwareFallback || material.status === ShaderEffect.Error || !root.effectsEnabled
                anchors.centerIn: parent
                width: contact.width * (0.55 + index * 0.18)
                height: contact.height * (0.50 + index * 0.24)
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                scale: 1 + Math.max(root.ripple, root.reactionRipple) * (0.03 + index * 0.015) + root.shimmer * 0.02
                ShapePath {
                    fillColor: "transparent"; strokeWidth: 0.65
                    strokeColor: Qt.alpha(root.accentColor, 0.78 - rippleRing.index * 0.20)
                    startX: 0; startY: rippleRing.height / 2
                    PathArc { x: rippleRing.width; y: rippleRing.height / 2; radiusX: rippleRing.width / 2; radiusY: rippleRing.height / 2 }
                    PathArc { x: 0; y: rippleRing.height / 2; radiusX: rippleRing.width / 2; radiusY: rippleRing.height / 2 }
                }
            }
        }
        ShaderEffect {
            anchors.fill: parent
            visible: root.effectsEnabled && !root.softwareFallback && material.status !== ShaderEffect.Error
            property var surfaceSource: reflectionSource
            property color accent: root.accentColor
            property color specular: root.reflectionColor
            property vector4d motion: Qt.vector4d(root.shimmer, Math.max(root.ripple, root.reactionRipple), contact.width / material.width, 0)
            fragmentShader: Qt.resolvedUrl("WaterDropletContact.frag.qsb")
        }
    }
    ShaderEffectSource {
        id: reflectionSource
        sourceItem: root.effectsEnabled && !root.softwareFallback && material.status !== ShaderEffect.Error ? reflectionLayer : null
        sourceRect: Qt.rect(0, 7, 76, 76)
        textureSize: Qt.size(76, 76)
        smooth: true
        live: root.visible && root.effectsEnabled
        visible: false
    }
    // Only our body and face enter the floor reflection, never desktop content.
    Item {
        id: reflectionLayer
        width: root.width; height: root.height
        // Rounded vector fallback for software/error; volume optics require a GPU.
        Shape {
            x: 0; y: 7; width: 76; height: 76
            visible: GraphicsInfo.api === GraphicsInfo.Software || material.status === ShaderEffect.Error
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1; strokeColor: root.reflectionColor
                fillGradient: LinearGradient {
                    x1: 38; y1: 0; x2: 38; y2: 76
                    GradientStop { position: 0; color: Qt.darker(root.accentColor, 2.2) }
                    GradientStop { position: 0.55; color: root.accentColor }
                    GradientStop { position: 1; color: Qt.lighter(root.accentColor, 1.65) }
                }
                startX: 38; startY: 4.2
                PathCubic { x: 15; y: 28.5; control1X: 32; control1Y: 14; control2X: 23; control2Y: 21 }
                PathCubic { x: 5.1; y: 47.3; control1X: 8; control1Y: 34; control2X: 5.1; control2Y: 41 }
                PathCubic { x: 38; y: 69.9; control1X: 5.1; control1Y: 62; control2X: 16; control2Y: 69.9 }
                PathCubic { x: 70.9; y: 47.3; control1X: 60; control1Y: 69.9; control2X: 71; control2Y: 62 }
                PathCubic { x: 61; y: 28.5; control1X: 70.9; control1Y: 41; control2X: 68; control2Y: 34 }
                PathCubic { x: 38; y: 4.2; control1X: 53; control1Y: 21; control2X: 44; control2Y: 14 }
            }
        }
        ShaderEffect {
            id: material
            x: 0; y: 7; width: 76; height: 76
            visible: GraphicsInfo.api !== GraphicsInfo.Software
            property color accent: root.accentColor
            property color specular: root.reflectionColor
            property vector4d motion: Qt.vector4d(root.shimmer, root.stateTip + root.sway * 0.25,
                root.pulse + (root.hovered ? 0.25 : 0), root.effectsEnabled ? 1 : 0)
            property vector4d optics: Qt.vector4d(root.viewYaw * Math.PI / 180, 0, 0, 0)
            fragmentShader: Qt.resolvedUrl("WaterDropletMaterial.frag.qsb")
        }
        // Decorative droplets fit the enclosing host; the body hitbox stays 76x92.
        Repeater {
            model: root.effectsEnabled ? 8 : 0
            Item {
                id: floatingDroplet
                required property int index
                x: [-13, 77, 6, 73.5, 20, 68, -3, 80][index]
                y: [42.5, 52, 25.5, 34.5, 13, 24, 65, 44][index] - root.shimmer * (index + 1) * 0.25
                width: [13.5, 14, 11, 6.5, 4, 4.5, 4, 3][index]; height: width
                ShaderEffect {
                    anchors.fill: parent
                    visible: !root.softwareFallback && material.status !== ShaderEffect.Error
                    property color accent: root.accentColor
                    property color specular: root.reflectionColor
                    property vector4d motion: Qt.vector4d(root.shimmer, 0, root.pulse, 0)
                    property vector4d optics: Qt.vector4d(0, 1, 0, 0)
                    fragmentShader: Qt.resolvedUrl("WaterDropletMaterial.frag.qsb")
                }
                Shape {
                    anchors.fill: parent
                    visible: root.softwareFallback || material.status === ShaderEffect.Error
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 0.4; strokeColor: root.reflectionColor
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: floatingDroplet.height
                            GradientStop { position: 0; color: root.reflectionColor }
                            GradientStop { position: 0.4; color: Qt.alpha(root.accentColor, 0.18) }
                            GradientStop { position: 1; color: root.accentColor }
                        }
                        startX: 0; startY: floatingDroplet.height / 2
                        PathArc { x: floatingDroplet.width; y: floatingDroplet.height / 2; radiusX: floatingDroplet.width / 2; radiusY: floatingDroplet.height / 2 }
                        PathArc { x: 0; y: floatingDroplet.height / 2; radiusX: floatingDroplet.width / 2; radiusY: floatingDroplet.height / 2 }
                    }
                }
            }
        }
        Item {
            id: faceOverlay
            anchors.fill: parent
            transformOrigin: Item.Center
            rotation: -root.orientationAngle
            opacity: Math.max(0, Math.cos(root.viewYaw * Math.PI / 180))
            transform: [
                Scale { origin.x: 38; origin.y: 60; xScale: Math.max(0.01, Math.cos(root.viewYaw * Math.PI / 180)) },
                Translate { x: 18 * Math.sin(root.viewYaw * Math.PI / 180) }
            ]
            WaterDropletFace {
                anchors.fill: parent
                expression: root.expression
                viewYaw: root.viewYaw
                accent: root.accentColor
                eyeOpen: root.eyeOpen
                mouthCurve: root.mouthCurve
                // Pointer feedback is interpolated locally, never streamed over IPC.
                gazeX: root.hovered ? Math.max(-1, Math.min(1, (hoverHandler.point.position.x - root.width * 0.5) / (root.width * 0.5))) : root.gazeX
                gazeY: root.hovered ? Math.max(-1, Math.min(1, (hoverHandler.point.position.y - root.height * 0.5) / (root.height * 0.5))) : root.gazeY
                pulse: root.pulse
                motionEnabled: root.motionEnabled
            }
        }
    }
    Item {
        id: workingOrbit
        x: 0; y: 34; width: 76; height: 14
        visible: root.expressionProfile.orbit && root.effectsEnabled
        rotation: -12 + root.shimmer * 24
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeWidth: 0.6
                strokeColor: Qt.alpha(root.accentColor, 0.65)
                startX: 0; startY: workingOrbit.height / 2
                PathArc { x: workingOrbit.width; y: workingOrbit.height / 2; radiusX: workingOrbit.width / 2; radiusY: workingOrbit.height / 2 }
                PathArc { x: 0; y: workingOrbit.height / 2; radiusX: workingOrbit.width / 2; radiusY: workingOrbit.height / 2 }
            }
        }
        Rectangle {
            x: workingOrbit.width / 2 + (workingOrbit.width / 2 - 3) * Math.cos(root.shimmer * Math.PI * 2) - 1.5
            y: workingOrbit.height / 2 + workingOrbit.height / 2 * Math.sin(root.shimmer * Math.PI * 2) - 1.5
            width: 3; height: 3; radius: 1.5; color: "#d7fbff"
        }
    }
    HoverHandler { id: hoverHandler; enabled: root.enabled }
    Repeater {
        model: root.effectsEnabled && root.shine > 0 ? 5 : 0
        Shape {
            required property int index
            x: [9, 64, 4, 66, 58][index]
            y: [20, 14, 48, 43, 73][index]
            width: 5; height: 5; opacity: root.shine
            ShapePath {
                fillColor: "#fff2b6"; strokeWidth: 0
                startX: 2.5; startY: 0
                PathLine { x: 3.2; y: 1.8 }
                PathLine { x: 5; y: 2.5 }
                PathLine { x: 3.2; y: 3.2 }
                PathLine { x: 2.5; y: 5 }
                PathLine { x: 1.8; y: 3.2 }
                PathLine { x: 0; y: 2.5 }
                PathLine { x: 1.8; y: 1.8 }
                PathLine { x: 2.5; y: 0 }
            }
        }
    }
    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.pressed()
            if (root.motionEnabled) squashBurst.restart()
        }
    }
    onMotionEnabledChanged: {
        if (!motionEnabled) {
            squashBurst.stop(); reactionBounce.stop(); shineBurst.stop()
            squash = 0; bob = 0; sway = 0; reactionLift = 0; reactionRipple = 0; shine = 0
        }
    }
    onExpressionChanged: {
        if (motionEnabled && ["happy", "excited", "surprised", "alert"].includes(expression)) {
            reactionBounce.restart()
            if (["happy", "excited"].includes(expression) && effectsEnabled) shineBurst.restart()
        }
    }
    Behavior on accentColor { enabled: root.motionEnabled; ColorAnimation { duration: 480 } }
    Behavior on viewYaw { enabled: root.motionEnabled; NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
    Behavior on expressionSquash { enabled: root.motionEnabled; SpringAnimation { spring: 3; damping: 0.42 } }
    Behavior on stateSquash { enabled: root.motionEnabled; SpringAnimation { spring: 3.2; damping: 0.34 } }
    Behavior on stateStretch { enabled: root.motionEnabled; SpringAnimation { spring: 2.8; damping: 0.36 } }
    Behavior on stateLean { enabled: root.motionEnabled; SpringAnimation { spring: 2.5; damping: 0.42 } }
    Behavior on stateTip { enabled: root.motionEnabled; SpringAnimation { spring: 2.4; damping: 0.44 } }
    Behavior on eyeOpen { enabled: root.motionEnabled; NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    Behavior on mouthCurve { enabled: root.motionEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on pulse { enabled: root.motionEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    SequentialAnimation {
        id: squashBurst
        NumberAnimation { target: root; property: "squash"; to: 1; duration: 85; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "squash"; to: -0.35; duration: 150; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "squash"; to: 0; duration: 210; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: reactionBounce
        ParallelAnimation {
            NumberAnimation { target: root; property: "reactionLift"; to: -4; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "reactionRipple"; to: 1; duration: 160 }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "reactionLift"; to: 0; duration: 440; easing.type: Easing.OutBounce }
            NumberAnimation { target: root; property: "reactionRipple"; to: 0; duration: 650; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: shineBurst
        NumberAnimation { target: root; property: "shine"; to: 1; duration: 160 }
        NumberAnimation { target: root; property: "shine"; to: 0; duration: 850 }
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
        running: root.motionEnabled && root.effectsEnabled; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 4300; easing.type: Easing.InOutSine }
    }
}
