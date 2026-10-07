import QtQuick
import QtQuick.Shapes
import "OctoRig.js" as Rig

// Editable Blender curves, projected in the head's 3D pose. Each
// trimmed quad traces a tapered volume; there are no sprite frames or clocks.
Item {
    id: root
    required property var body
    required property var motion
    property bool gripping: false
    property var tentacleIndices: [0,1,2,3]
    width: body.width; height: body.height
    Repeater {
        model: root.tentacleIndices
        Item {
            id: arm
            required property int modelData
            readonly property int index: modelData
            objectName: "octoTentacle"+index
            readonly property var curve: root.gripping
                ? Rig.gripControls(index,root.motion.sample("gripRise"),root.motion.sample("gripWrap"))
                : Rig.controls(index,root.motion.curl(index),root.motion.sample("tentacle"+index+"Lift"),root.motion.sample("tentacle"+index+"Reach")*root.motion.direction)
            readonly property var points: curve.map(p=>root.body.project(p.x,p.y,p.z))
            readonly property var bounds: {
                const radius=(Rig.geometry.rootRadius+1)*Math.max(root.body.poseScaleX,root.body.poseScaleY,1/(root.body.poseScaleX*root.body.poseScaleY))
                return {left:Math.min(...points.map(p=>p.x))-radius,right:Math.max(...points.map(p=>p.x))+radius,
                    bottom:Math.min(...points.map(p=>p.y))-radius,top:Math.max(...points.map(p=>p.y))+radius}
            }
            x:38+bounds.left; y:46.14-bounds.top+root.motion.lift+root.body.reactionLift*root.body.motionAmount
            width:bounds.right-bounds.left; height:bounds.top-bounds.bottom
            z:points.reduce((sum,p)=>sum+p.z,0)/points.length
            readonly property real radialScale: Math.sqrt(root.body.poseScaleX*root.body.poseScaleY)
            function control(i): vector4d {const p=points[i];return Qt.vector4d(p.x/35.34884,p.y/35.34884,p.z/35.34884,curve[i].r*radialScale/35.34884)}
            ShaderEffect {
                id: material
                objectName:"octoTentacleMaterial"+arm.index
                anchors.fill: parent
                visible: !root.body.softwareFallback
                property color accent: root.body.liquidAccent
                property color specular: root.body.reflectionColor
                property vector4d motion: root.body.limbMotionUniform
                property vector4d optics: Qt.vector4d(0,3,0,0)
                property vector4d rendering: root.body.smallMaterialRenderingUniform
                property vector4d pose: Qt.vector4d(0,0,0,0)
                property vector4d curve0: arm.control(0)
                property vector4d curve1: arm.control(1)
                property vector4d curve2: arm.control(2)
                property vector4d curve3: arm.control(3)
                property vector4d bounds: Qt.vector4d(arm.bounds.left/35.34884,arm.bounds.bottom/35.34884,arm.width/35.34884,arm.height/35.34884)
                fragmentShader: Qt.resolvedUrl("OctoTentacle.frag.qsb")
            }
            Shape {
                visible:root.body.softwareFallback || material.status===ShaderEffect.Error
                anchors.fill:parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor:"transparent";strokeColor:root.body.liquidAccent;strokeWidth:7
                    capStyle:ShapePath.RoundCap
                    startX:arm.points[0].x-arm.bounds.left;startY:arm.bounds.top-arm.points[0].y
                    PathCubic {
                        x:arm.points[3].x-arm.bounds.left;y:arm.bounds.top-arm.points[3].y
                        control1X:arm.points[1].x-arm.bounds.left;control1Y:arm.bounds.top-arm.points[1].y
                        control2X:arm.points[2].x-arm.bounds.left;control2Y:arm.bounds.top-arm.points[2].y
                    }
                }
            }
        }
    }
}
