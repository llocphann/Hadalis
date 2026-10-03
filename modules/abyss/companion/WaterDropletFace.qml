import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs.modules.abyss.looks
import qs.modules.common.functions
import "WullExpressions.js" as Expressions

Item {
    id: root
    property string expression: "idle"
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real gazeX: 0
    property real gazeY: 0
    property real viewYaw: 0
    property real pulse: 0
    property color accent: AbyssStyle.accent
    property bool motionEnabled: true
    readonly property var profile: Expressions.profile(expression)
    readonly property real unit: width / 76
    readonly property color ink: Qt.hsla(Math.max(0, accent.hslHue), accent.hslSaturation * 0.78, 0.065, 1)
    Repeater {
        model: 2
        Item {
            id: eye
            required property int index
            x: (index === 0 ? 18 : 44) * root.unit
            y: 46 * root.unit
            width: 14 * root.unit; height: 16 * root.unit
            rotation: root.profile.worried ? (index === 0 ? 13 : -13) : 0
            scale: root.profile.eyeScale * 0.83 * (1 + (index === 0 ? 1 : -1) * Math.sin(root.viewYaw * Math.PI / 180) * 0.25)
            Behavior on scale { enabled: root.motionEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Item {
                anchors.fill: parent
                opacity: !root.profile.smilingEyes && !root.profile.closedEyes ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { enabled: root.motionEnabled; NumberAnimation { duration: 160 } }
                transform: Scale {
                    origin.x: eye.width * 0.5; origin.y: eye.height * 0.5
                    yScale: Math.max(0.06, root.eyeOpen)
                }
                ShaderEffect {
                    id: cornea
                    anchors.fill: parent; anchors.margins: -root.unit
                    visible: GraphicsInfo.api !== GraphicsInfo.Software && status !== ShaderEffect.Error
                    property color accent: root.accent
                    property color specular: ColorUtils.colorWithLightness(root.accent, 0.85)
                    property vector4d motion: Qt.vector4d(0, 0, 0, 0)
                    property vector4d optics: Qt.vector4d(0, 2, root.gazeX, root.gazeY)
                    fragmentShader: Qt.resolvedUrl("WaterDropletMaterial.frag.qsb")
                }
                Item {
                    anchors.fill: parent
                    visible: GraphicsInfo.api === GraphicsInfo.Software || cornea.status === ShaderEffect.Error
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: root.unit * 0.65
                            strokeColor: Qt.alpha(root.accent, 0.68)
                            fillGradient: RadialGradient {
                                centerX: eye.width * 0.52; centerY: eye.height * 0.93
                                centerRadius: eye.height * 0.91
                                focalX: centerX; focalY: centerY
                                GradientStop { position: 0; color: Qt.lighter(root.accent, 1.05) }
                                GradientStop { position: 0.25; color: Qt.darker(root.accent, 1.25) }
                                GradientStop { position: 0.50; color: root.ink }
                                GradientStop { position: 1; color: "#010610" }
                            }
                            startX: eye.width * 0.5; startY: 0
                            PathCubic { x: eye.width; y: eye.height * 0.5; control1X: eye.width * 0.82; control1Y: 0; control2X: eye.width; control2Y: eye.height * 0.20 }
                            PathCubic { x: eye.width * 0.5; y: eye.height; control1X: eye.width; control1Y: eye.height * 0.82; control2X: eye.width * 0.82; control2Y: eye.height }
                            PathCubic { x: 0; y: eye.height * 0.5; control1X: eye.width * 0.18; control1Y: eye.height; control2X: 0; control2Y: eye.height * 0.82 }
                            PathCubic { x: eye.width * 0.5; y: 0; control1X: 0; control1Y: eye.height * 0.20; control2X: eye.width * 0.18; control2Y: 0 }
                        }
                    }
                    Shape {
                        x: 2 * root.unit; y: 10 * root.unit
                        width: 10 * root.unit; height: 7 * root.unit
                        opacity: 0.65
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: 0
                            fillGradient: RadialGradient {
                                centerX: 5 * root.unit; centerY: 4 * root.unit
                                centerRadius: 3.4 * root.unit
                                focalX: centerX; focalY: centerY
                                GradientStop { position: 0; color: "#b2fcff" }
                                GradientStop { position: 0.35; color: root.accent }
                                GradientStop { position: 1; color: Qt.alpha(root.accent, 0) }
                            }
                            startX: 0; startY: 3.5 * root.unit
                            PathArc { x: 10 * root.unit; y: 3.5 * root.unit; radiusX: 5 * root.unit; radiusY: 3.5 * root.unit }
                            PathArc { x: 0; y: 3.5 * root.unit; radiusX: 5 * root.unit; radiusY: 3.5 * root.unit }
                        }
                    }
                    Rectangle {
                        x: (2.5 + root.gazeX * 1.5) * root.unit; y: (2.4 + root.gazeY) * root.unit
                        width: 4.0 * root.unit; height: 3.2 * root.unit
                        radius: width / 2; rotation: -25; color: "#f1fdff"
                    }
                    Rectangle {
                        x: (9 + root.gazeX) * root.unit; y: (10 + root.gazeY) * root.unit
                        width: 2.2 * root.unit; height: width; radius: width / 2; color: "#d3f9ff"
                    }
                    Rectangle {
                        x: 4 * root.unit; y: 13 * root.unit
                        width: 4.8 * root.unit; height: 2.6 * root.unit; radius: height / 2
                        rotation: -25; color: Qt.alpha(Qt.lighter(root.accent, 1.5), 0.75)
                    }
                }
            }
            Shape {
                anchors.fill: parent
                opacity: root.profile.smilingEyes || root.profile.closedEyes ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { enabled: root.motionEnabled; NumberAnimation { duration: 160 } }
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: root.ink
                    strokeWidth: 1.8 * root.unit; capStyle: ShapePath.RoundCap
                    startX: root.unit; startY: 10 * root.unit
                    PathCubic {
                        x: 13 * root.unit; y: 10 * root.unit
                        control1X: 3 * root.unit; control2X: 11 * root.unit
                        control1Y: (root.profile.smilingEyes ? 3 : 15) * root.unit
                        control2Y: control1Y
                    }
                }
            }
            Shape {
                x: -root.unit; y: -4 * root.unit
                width: eye.width + 2 * root.unit; height: 4 * root.unit
                visible: root.profile.worried
                ShapePath {
                    fillColor: "transparent"; strokeColor: root.ink
                    strokeWidth: root.unit; capStyle: ShapePath.RoundCap
                    startX: 0; startY: (eye.index === 0 ? 3 : 0) * root.unit
                    PathLine { x: 15 * root.unit; y: (eye.index === 0 ? 0 : 3) * root.unit }
                }
            }
        }
    }
    Repeater {
        model: 2
        Shape {
            required property int index
            x: (index === 0 ? 12.5 : 53.5) * root.unit; y: 60 * root.unit
            width: 9 * root.unit; height: 9 * root.unit
            opacity: 0.55 + root.pulse * 0.18
            antialiasing: true
            transform: Scale {
                origin.x: 4.5 * root.unit; origin.y: 4.5 * root.unit
                xScale: 1.4; yScale: 0.68
            }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 4.5 * root.unit; centerY: 4.5 * root.unit
                    centerRadius: 4.5 * root.unit
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: "#ffb6dc" }
                    GradientStop { position: 0.20; color: "#ff8dc9" }
                    GradientStop { position: 1; color: "#00ff8dc9" }
                }
                startX: 0; startY: 4.5 * root.unit
                PathArc { x: 9 * root.unit; y: 4.5 * root.unit; radiusX: 4.5 * root.unit; radiusY: 4.5 * root.unit }
                PathArc { x: 0; y: 4.5 * root.unit; radiusX: 4.5 * root.unit; radiusY: 4.5 * root.unit }
            }
        }
    }
    Item {
        id: mouth
        x: 31 * root.unit; y: 58 * root.unit
        width: 14 * root.unit; height: 10 * root.unit
        scale: root.profile.openMouth || root.expression === "surprised" ? 0.80 : 0.55
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 6 * root.unit; height: 8 * root.unit; radius: width / 2
            color: root.ink; visible: root.expression === "surprised"
        }
        Shape {
            anchors.fill: parent
            visible: root.expression !== "surprised"; antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.profile.openMouth ? root.ink : "transparent"
                strokeColor: root.ink; strokeWidth: 1.5 * root.unit
                capStyle: ShapePath.RoundCap
                startX: 2 * root.unit; startY: 2 * root.unit
                PathCubic {
                    x: 12 * root.unit; y: 2 * root.unit
                    control1X: 4 * root.unit; control2X: 10 * root.unit
                    control1Y: (root.profile.worried ? -2 : root.profile.openMouth ? 12 : 5 + root.mouthCurve * 3) * root.unit
                    control2Y: control1Y
                }
                PathLine { x: root.profile.openMouth ? 2 * root.unit : 12 * root.unit; y: 2 * root.unit }
            }
        }
        Rectangle {
            x: 5 * root.unit; y: 5 * root.unit
            width: 5 * root.unit; height: 2.5 * root.unit; radius: height / 2
            color: "#ee8abb"; visible: root.profile.openMouth && root.expression !== "surprised"
        }
    }
    Text {
        x: 58 * root.unit; y: 22 * root.unit
        text: root.profile.mark; color: "#d9faff"
        font.pixelSize: (root.expression === "sleepy" ? 8 : 13) * root.unit
        font.bold: true
        rotation: root.expression === "sleepy" ? -15 : 10
    }
}
