import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import qs.modules.abyss.looks
import qs.modules.common
import qs.modules.common.functions
import "WullExpressions.js" as Expressions
import "WullPreferences.js" as Preferences
import "CompanionMotion.js" as Motion
import "WullPose.js" as Pose
import "OctoRig.js" as OctoRig

Item {
    id: root
    objectName: "wullLiquidBody"
    property string character: "aqua"
    property bool tentacleGrip: false
    property real gripProgress: 0
    readonly property bool octopus: character==="octo"
    readonly property var curves: Motion.forCharacter(character)
    readonly property var headCenter: project(0,OctoRig.geometry.headOffset,0)
    readonly property real headSize: OctoRig.geometry.headSize
    property string expression: "idle"
    property color accentColor: AbyssStyle.accent
    property real hoverAmount: hovered ? 1 : 0
    readonly property color liquidAccent: ColorUtils.colorWithLightness(accentColor,
        Math.min(.82,accentColor.hslLightness+hoverAmount*.035+tapPulse*.018))
    readonly property color reflectionColor: ColorUtils.colorWithLightness(accentColor, 0.85+hoverAmount*.04)
    property real energy: 0.45
    property real gazeX: 0
    property real gazeY: 0
    property bool motionEnabled: AbyssStyle.motionEnabled && visible
    property real motionScale: 1
    property bool effectsEnabled: Appearance.effectsEnabled && AbyssStyle.quality !== "performance"
    property string renderQuality: "quality"
    property real translucency: 0.16
    readonly property int qualityLevel: Preferences.renderTier(renderQuality, AbyssStyle.quality)
    readonly property bool detailedEffects: effectsEnabled && qualityLevel > 0
    property real squash: 0
    property real bob: 0
    property real sway: 0
    property real shimmer: 0
    property real orbitPhase: 0
    readonly property real orbitAngle: curves.sample("orbit", "angle", orbitPhase)
    property real stateSquash: 0
    property real stateStretch: 0
    property real stateLean: 0
    property real stateTip: 0
    property real orientationAngle: 0
    property real viewYaw: -15
    property real viewPitch: 0
    property real rollingAngle: 0
    readonly property real modelRoll:gait.roll+rollingAngle
    readonly property real modelYaw: viewYaw+gait.yaw
    readonly property real modelPitch: viewPitch+gait.pitch
    // These three angles feed five ShaderEffect instances (torso + four
    // limbs). Convert each shared pose angle once per pose revision instead of
    // repeating identical degree-to-radian work in every consumer.
    readonly property real modelYawRadians: modelYaw * Math.PI / 180
    readonly property real modelPitchRadians: modelPitch * Math.PI / 180
    readonly property real modelRollRadians: modelRoll * Math.PI / 180
    // Shader uniforms below are identical across repeated limb/droplet
    // delegates. Construct each shared QVector4D once per input revision.
    readonly property vector4d materialRenderingUniform: Qt.vector4d(qualityLevel, translucency, 0, 0)
    // Small hands/feet/orbital droplets cover very few pixels but otherwise
    // pay the same tiered liquid ray cost as the 76 px torso. Tier 0 keeps the
    // same implicit surface/material shader while dropping high-tier secondary
    // traces and studio-light detail that is sub-pixel at these sizes.
    readonly property vector4d smallMaterialRenderingUniform: Qt.vector4d(0, translucency, 0, 0)
    readonly property vector4d limbMotionUniform: Qt.vector4d(shimmer, 0, pulse, effectsEnabled ? 1 : 0)
    readonly property vector4d limbOpticsUniform: Qt.vector4d(modelYawRadians, 3, 0, 0)
    readonly property vector4d limbPoseUniform: Qt.vector4d(modelPitchRadians, modelRollRadians, 0, 0)
    readonly property vector4d dropletMotionUniform: Qt.vector4d(shimmer, 0, pulse, 0)
    readonly property var poseRotation: Pose.rotation(modelYaw,modelPitch,modelRoll)
    readonly property real poseScaleX: gait.scaleX
    readonly property real poseScaleY: gait.scaleY
    function project(x,y,z): var {return Pose.project(poseRotation,x,y,z,poseScaleX,poseScaleY)}
    property bool walking: false
    property bool flying: false
    property bool grounded: true
    property bool dragging: false
    property bool traveling: false
    property string motionAction: ""
    property real motionProgress: -1
    property real walkingDirection: 1
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0
    property real reveal: 1
    property real reactionPhase: 1
    readonly property real reactionLift: curves.sample("hop", "lift", reactionPhase) * 0.6
    property real reactionRipple: 0
    property real shine: 0
    property real tapPhase: 1
    property real tapPulse: 0
    property real tapX: 38
    property real tapY: 48
    readonly property var expressionProfile: Expressions.profile(expression)
    property real expressionSquash: expressionProfile.squash
    readonly property real motionAmount: motionEnabled ? AbyssStyle.motionIntensity * motionScale : 0
    readonly property bool hovered: hoverHandler.hovered
    // Qt reports handler positions in this item's already rotated coordinates.
    readonly property real hoverGazeX: Math.max(-1,Math.min(1,(hoverHandler.point.position.x-width/2)/(width/2)))
    readonly property real hoverGazeY: Math.max(-1,Math.min(1,(hoverHandler.point.position.y-height/2)/(height/2)))
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
    signal chatRequested()
    signal pressed()
    signal settingsRequested()
    function reactToTap(px,py): void {
        pressed()
        if (!motionEnabled) return
        tapX=Math.max(8,Math.min(width-8,px)); tapY=Math.max(12,Math.min(height-12,py))
        squashBurst.restart(); tapBurst.restart()
        reactionBounce.restart()
    }

    WullMotion {
        id: gait
        character: root.character
        walking: root.walking
        flying: root.flying
        action: root.motionAction
        progress: root.motionProgress
        direction: Math.abs(root.walkingDirection)>.05 ? root.walkingDirection : 1
        motionEnabled: root.motionEnabled && root.visible
    }
    WullMotion {
        id: gripMotion
        character: "octo"
        action: root.tentacleGrip ? "pull" : ""
        progress: root.gripProgress
        motionEnabled: root.tentacleGrip && root.motionEnabled && root.visible
    }

    // Preserve placement and native input bounds. The body itself is square.
    implicitWidth: 76
    implicitHeight: 92
    transformOrigin: Item.Bottom
    scale: 1 + squash * 0.035 + hoverAmount * 0.015
    rotation: orientationAngle + ((gait.active ? 0 : sway * 2.2) + stateLean * 5.0 + stateTip * 2.4 + expressionProfile.tilt * 4) * motionAmount
    transform: [
        Scale {
            origin.x: root.width * 0.5; origin.y: root.height * 0.5
            xScale: 1 + (root.stateSquash + root.expressionSquash) * 0.05 - root.stateStretch * 0.025 + root.squash * 0.06
            yScale: 1 - (root.stateSquash + root.expressionSquash) * 0.035 + root.stateStretch * 0.06 - root.squash * 0.05
        },
        Translate {
            y: (gait.active ? 0 : root.bob) * root.motionAmount + (1 - root.reveal) * 6 * root.motionAmount
        }
    ]
    Item {
        id: contact
        visible: root.grounded
        width: root.qualityLevel > 1 ? 102 : 94
        height: root.qualityLevel > 1 ? 18 : root.qualityLevel > 0 ? 15 : 13
        x: (root.width - width) * 0.5
        y: 78.3 - height * 0.5
        z: -1
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: contact.width * 0.5; centerY: contact.height * 0.5; centerRadius: contact.width * 0.5
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Qt.alpha(root.liquidAccent, 0.18) }
                    GradientStop { position: 1; color: "transparent" }
                }
                startX: 0; startY: contact.height * 0.5
                PathArc { x: contact.width; y: contact.height * 0.5; radiusX: contact.width * 0.5; radiusY: contact.height * 0.5 }
                PathArc { x: 0; y: contact.height * 0.5; radiusX: contact.width * 0.5; radiusY: contact.height * 0.5 }
            }
        }
        Repeater {
            model: 3
            Shape {
                id: rippleRing
                required property int index
                visible: root.softwareFallback || material.status === ShaderEffect.Error || !root.detailedEffects
                anchors.centerIn: parent
                width: contact.width * (0.55 + index * 0.18)
                height: contact.height * (0.50 + index * 0.24)
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                scale: 1 + Math.max(root.ripple, root.reactionRipple) * (0.03 + index * 0.015) + root.shimmer * 0.02
                ShapePath {
                    fillColor: "transparent"; strokeWidth: 0.65
                    strokeColor: Qt.alpha(root.liquidAccent, 0.78 - rippleRing.index * 0.20)
                    startX: 0; startY: rippleRing.height / 2
                    PathArc { x: rippleRing.width; y: rippleRing.height / 2; radiusX: rippleRing.width / 2; radiusY: rippleRing.height / 2 }
                    PathArc { x: 0; y: rippleRing.height / 2; radiusX: rippleRing.width / 2; radiusY: rippleRing.height / 2 }
                }
            }
        }
        ShaderEffect {
            anchors.fill: parent
            visible: root.detailedEffects && !root.softwareFallback && material.status !== ShaderEffect.Error
            property var surfaceSource: reflectionSource
            property color accent: root.liquidAccent
            property color specular: root.reflectionColor
            property vector4d motion: Qt.vector4d(root.shimmer, Math.max(root.ripple, root.reactionRipple), contact.width / material.width, 0)
            property vector4d rendering: Qt.vector4d(root.qualityLevel, 0, 0, 0)
            readonly property real contactSide: 19
            readonly property real contactDepth: 8
            property vector4d feet: Qt.vector4d(
                (contact.width*.5+root.project(-contactSide+gait.footX("foot0X"),-29.76+gait.footZ("foot0Z"),contactDepth).x)/contact.width,
                (contact.width*.5+root.project(contactSide+gait.footX("foot1X"),-29.76+gait.footZ("foot1Z"),contactDepth).x)/contact.width,
                1-Math.min(1, gait.footZ("foot0Z")/2), 1-Math.min(1, gait.footZ("foot1Z")/2))
            fragmentShader: Qt.resolvedUrl("WaterDropletContact.frag.qsb")
        }
    }
    ShaderEffectSource {
        id: reflectionSource
        objectName: "wullFloorReflectionSource"
        sourceItem: root.grounded && root.detailedEffects && !root.softwareFallback && material.status !== ShaderEffect.Error ? reflectionLayer : null
        sourceRect: Qt.rect(0, 7, 76, 82)
        // The reflection is finally compressed into a 13-18 px-tall puddle
        // and sampled with a three-tap softening kernel. A 2x capture at tier 2
        // quadruples offscreen pixels without preserving visible extra detail.
        textureSize: Qt.size(76, 82)
        smooth: true
        live: root.visible && root.grounded && root.detailedEffects
        visible: false
    }
    // Reflect only our body, limbs, bubbles and face; never desktop content.
    Item {
        id: reflectionLayer
        width: root.width; height: root.height
        // Exactly two side arms and two ground feet, with distinct rig tracks.
        Repeater {
            objectName: "wullWaterLimbs"
            model: root.octopus ? 0 : 4
            Item {
                id: waterFoot
                required property int index
                objectName: index<2 ? "wullHand"+index : "wullFoot"+(index-2)
                readonly property bool hand: index < 2
                readonly property real side: index % 2 === 0 ? -1 : 1
                readonly property string xTrack: (hand ? "arm"+index : "foot"+(index-2)) + "X"
                readonly property string zTrack: (hand ? "arm"+index : "foot"+(index-2)) + "Z"
                readonly property real stepX: gait.footX(xTrack)
                readonly property real stepZ: gait.footZ(zTrack)
                readonly property var spatial: root.project(side*(hand ? 34 : 19)+stepX,
                    46.14-(hand ? 53.3 : 75.9)+stepZ,8)
                readonly property real depth: spatial.z
                width: hand ? 10.5 : 14
                height: width
                x:38+spatial.x-width/2
                y:46.14-spatial.y-height/2+root.reactionLift*root.motionAmount+gait.lift
                z: depth >= 0 ? 1 : -1
                ShaderEffect {
                    anchors.fill: parent
                    visible: !root.softwareFallback && material.status !== ShaderEffect.Error
                    property color accent: root.liquidAccent
                    property color specular: root.reflectionColor
                    property vector4d motion: root.limbMotionUniform
                    property vector4d optics: root.limbOpticsUniform
                    property vector4d rendering: root.smallMaterialRenderingUniform
                    property vector4d pose: root.limbPoseUniform
                    fragmentShader: Qt.resolvedUrl("WaterDropletMaterial.frag.qsb")
                }
                Shape {
                    anchors.fill: parent
                    visible: root.softwareFallback || material.status === ShaderEffect.Error
                    opacity: 1 - Math.max(0, Math.min(0.35, root.translucency)) * 0.25
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: 0.45; strokeColor: root.reflectionColor
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: waterFoot.height
                            GradientStop { position: 0; color: Qt.darker(root.liquidAccent, 1.4) }
                            GradientStop { position: 0.36; color: root.reflectionColor }
                            GradientStop { position: 0.70; color: root.liquidAccent }
                            GradientStop { position: 1; color: root.reflectionColor }
                        }
                        startX: 0; startY: waterFoot.height / 2
                        PathArc { x: waterFoot.width; y: waterFoot.height / 2; radiusX: waterFoot.width / 2; radiusY: waterFoot.height / 2 }
                        PathArc { x: 0; y: waterFoot.height / 2; radiusX: waterFoot.width / 2; radiusY: waterFoot.height / 2 }
                    }
                }
            }
        }
        Loader {
            active: root.octopus
            sourceComponent: OctoTentacles {
                body: root
                motion: gait
            }
        }
        Loader {
            active: root.tentacleGrip && !root.octopus
            z: -.5
            sourceComponent: OctoTentacles {
                body: root;motion: gripMotion;gripping: true;tentacleIndices: [1,2]
                objectName: "octoGripBack"
                opacity: Math.min(1,gripMotion.sample("gripRise")*4)
            }
        }
        Loader {
            active: root.tentacleGrip && !root.octopus
            z: .5
            sourceComponent: OctoTentacles {
                body: root;motion: gripMotion;gripping: true;tentacleIndices: [0,3]
                objectName: "octoGripFront"
                opacity: Math.min(1,gripMotion.sample("gripRise")*4)
            }
        }
        Item {
            id: torso
            width: root.width; height: root.height
            y: gait.lift + root.reactionLift * root.motionAmount
            // Rounded vector fallback for software/error; volume optics require a GPU.
            Rectangle {
                visible:root.octopus && (root.softwareFallback || material.status===ShaderEffect.Error)
                x:material.x;y:material.y;width:material.width;height:material.height
                radius:width/2
                gradient:Gradient {
                    GradientStop {position:0;color:Qt.darker(root.liquidAccent,1.7)}
                    GradientStop {position:.6;color:root.liquidAccent}
                    GradientStop {position:1;color:root.reflectionColor}
                }
            }
            Shape {
                x: 0; y: 7; width: 76; height: 76
                visible: !root.octopus && (GraphicsInfo.api === GraphicsInfo.Software || material.status === ShaderEffect.Error)
                opacity: 1 - Math.max(0, Math.min(0.35, root.translucency)) * 0.55
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1; strokeColor: root.reflectionColor
                    fillGradient: LinearGradient {
                        x1: 38; y1: 0; x2: 38; y2: 76
                        GradientStop { position: 0; color: Qt.darker(root.liquidAccent, 2.2) }
                        GradientStop { position: 0.55; color: root.liquidAccent }
                        GradientStop { position: 1; color: Qt.lighter(root.liquidAccent, 1.65) }
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
                objectName:"wullVolumeMaterial"
                x: root.octopus ? 38+root.headCenter.x-root.headSize/2 : 0
                y: root.octopus ? 46.14-root.headCenter.y-root.headSize/2 : 7
                width: root.octopus ? root.headSize : 76; height: width
                visible: GraphicsInfo.api !== GraphicsInfo.Software
                property color accent: root.liquidAccent
                property color specular: root.reflectionColor
                property vector4d motion: Qt.vector4d(root.shimmer, root.stateTip + root.sway * 0.25,
                    Math.max(root.pulse,root.tapPulse*.65) + root.hoverAmount*.16, root.effectsEnabled ? 1 : 0)
                property vector4d optics: Qt.vector4d(root.modelYawRadians, root.octopus ? 4 : 0, 0, 0)
                property vector4d rendering: root.materialRenderingUniform
                property vector4d pose:Qt.vector4d(root.modelPitchRadians,root.modelRollRadians,root.poseScaleX-1,root.poseScaleY-1)
                fragmentShader: Qt.resolvedUrl("WaterDropletMaterial.frag.qsb")
            }
            // Decorative droplets fit the enclosing host; the body hitbox stays 76x92.
            Repeater {
                objectName: "wullExternalDroplets"
                model: !root.effectsEnabled ? 0 : root.qualityLevel > 1 ? 8 : root.qualityLevel > 0 ? 6 : 3
                Item {
                    id: floatingDroplet
                    required property int index
                    readonly property real angle: root.orbitAngle + Expressions.bubblePhase[index]
                    readonly property real orbitCos: Math.cos(angle)
                    readonly property real orbitSin: Math.sin(angle)
                    readonly property var spatial:root.project(47*orbitCos,4.14-37*orbitSin,25*orbitSin)
                    readonly property real depth:spatial.z
                    x:38+spatial.x-width/2
                    y:46.14-spatial.y-height/2
                    z: depth < 0 ? -1 : 2
                    opacity: depth < 0 ? 0.78 : 1
                    width: Expressions.dropletSize[index]; height: width
                    ShaderEffect {
                        anchors.fill: parent
                        visible: !root.softwareFallback && material.status !== ShaderEffect.Error
                        property color accent: root.liquidAccent
                        property color specular: root.reflectionColor
                        property vector4d motion: root.dropletMotionUniform
                        property vector4d optics: Qt.vector4d(0, 1, 0, 0)
                        property vector4d rendering: root.smallMaterialRenderingUniform
                        property vector4d pose:Qt.vector4d(0,0,0,0)
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
                                GradientStop { position: 0.4; color: Qt.alpha(root.liquidAccent, 0.18) }
                                GradientStop { position: 1; color: root.liquidAccent }
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
                opacity:Math.max(0,Math.min(1,root.poseRotation[8]*5))
                transform:Matrix4x4 {
                    matrix: {
                        const m=Pose.faceMatrix(root.poseRotation,root.poseScaleX,root.poseScaleY,38,46.14,root.octopus ? 24 : 26)
                        return Qt.matrix4x4(m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8],m[9],m[10],m[11],m[12],m[13],m[14],m[15])
                    }
                }
                WaterDropletFace {
                    width: parent.width; height: parent.height
                    y: root.octopus ? -7 : 0
                    scale: root.octopus ? .9 : 1
                    transformOrigin: Item.TopLeft
                    transform: Translate {x:root.octopus ? 3.8 : 0;y:root.octopus ? 5.4 : 0}
                    expression: root.expression
                    cheeksVisible: !root.octopus
                    viewYaw: root.modelYaw
                    accent: root.liquidAccent
                    eyeOpen: root.eyeOpen
                    mouthCurve: root.mouthCurve
                    // Pointer feedback is interpolated locally, never streamed over IPC.
                    // The actor projects observed coordinates into this face's
                    // orientation, including sideways and upper water rims.
                    gazeX: root.gazeX
                    gazeY: root.gazeY
                    microX: root.motionEnabled && !root.traveling ? root.sway*.16 : 0
                    microY: root.motionEnabled && !root.traveling ? root.bob*.055 : 0
                    pulse: root.pulse
                    motionEnabled: root.motionEnabled
                    qualityLevel: root.qualityLevel
                }
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
                strokeColor: Qt.alpha(root.liquidAccent, 0.65)
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
        model: root.effectsEnabled && root.tapPhase<1 ? 2 : 0
        Shape {
            id: tapRing
            required property int index
            objectName: "wullTapRipple"+index
            width: 36+index*12; height: width
            x: root.tapX-width/2; y: root.tapY-height/2
            scale: .35+root.tapPhase*(1.1+index*.2)
            opacity: (1-root.tapPhase)*(.6-index*.15)
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: root.reflectionColor; strokeWidth: .8
                startX: 0; startY: tapRing.height/2
                PathArc { x: tapRing.width; y: tapRing.height/2; radiusX: tapRing.width/2; radiusY: tapRing.height/2 }
                PathArc { x: 0; y: tapRing.height/2; radiusX: tapRing.width/2; radiusY: tapRing.height/2 }
            }
        }
    }
    Repeater {
        model: root.effectsEnabled && root.shine > 0 ? 5 : 0
        Shape {
            required property int index
            x: Expressions.shineX[index]
            y: Expressions.shineY[index]
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
        id: primaryTap
        enabled: root.enabled && !root.dragging
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.DragThreshold
        onTapped: root.reactToTap(point.position.x,point.position.y)
        onDoubleTapped: root.chatRequested()
    }
    TapHandler {
        enabled: root.enabled
        acceptedButtons: Qt.RightButton
        onTapped: root.settingsRequested()
    }
    onMotionEnabledChanged: {
        if (!motionEnabled) {
            squashBurst.stop(); reactionBounce.stop(); shineBurst.stop(); tapBurst.stop()
            squash = 0; bob = 0; sway = 0; orbitPhase = 0; reactionPhase = 1; reactionRipple = 0; shine = 0; tapPhase = 1; tapPulse = 0
        }
    }
    onExpressionChanged: {
        if (motionEnabled && ["happy", "excited", "surprised", "alert"].includes(expression)) {
            reactionBounce.restart()
            if (["happy", "excited"].includes(expression) && effectsEnabled) shineBurst.restart()
        }
    }
    Behavior on accentColor { enabled: root.motionEnabled; ColorAnimation { duration: 480 } }
    Behavior on hoverAmount { enabled: root.motionEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
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
    ParallelAnimation {
        id: tapBurst
        NumberAnimation { target: root; property: "tapPhase"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "tapPulse"; from: 1; to: 0; duration: 500; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: reactionBounce
        NumberAnimation { target: root; property: "reactionPhase"; from: 0; to: 1; duration: curves.clips.hop.duration }
        NumberAnimation { target: root; property: "reactionRipple"; from: 1; to: 0; duration: curves.clips.hop.duration; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: shineBurst
        NumberAnimation { target: root; property: "shine"; to: 1; duration: 160 }
        NumberAnimation { target: root; property: "shine"; to: 0; duration: 850 }
    }
    SequentialAnimation on bob {
        running: root.motionEnabled && root.visible && !gait.active; loops: Animation.Infinite
        NumberAnimation { to: -1.2 - root.energy * 2.4; duration: 1570; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.6 + root.energy * 1.2; duration: 2110; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on sway {
        running: root.motionEnabled && root.visible && !gait.active; loops: Animation.Infinite
        NumberAnimation { to: 0.45 + root.energy; duration: 2390; easing.type: Easing.InOutSine }
        NumberAnimation { to: -0.3 - root.energy * 0.7; duration: 3170; easing.type: Easing.InOutSine }
    }
    SequentialAnimation on shimmer {
        running: root.motionEnabled && root.visible && root.effectsEnabled; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 4300; easing.type: Easing.InOutSine }
    }
    NumberAnimation on orbitPhase {
        running: root.motionEnabled && root.visible && root.effectsEnabled
        from: 0; to: 1; duration: curves.clips.orbit.duration
        loops: Animation.Infinite
    }
}
