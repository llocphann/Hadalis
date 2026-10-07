import QtQuick
import QtQuick.Shapes
import qs.modules.abyss.looks
import "WullTravel.js" as Travel

// Two finite water openings inside the existing output surface. No idle clock,
// capture texture, input handler or additional native window is needed.
Item {
    id:root
    property var presence:null
    visible:presence?.portalActive ?? false
    readonly property real progress:presence?.portalProgress ?? 0
    readonly property real opening:Travel.opening(progress)
    Repeater {
        model:root.visible ? [root.presence.portalSource,root.presence.portalDestination] : []
        delegate:Item {
            id:mouth
            required property var modelData
            required property int index
            objectName:index===0 ? "wullPortalSource" : "wullPortalDestination"
            readonly property real unit:root.presence.scene?.scale ?? 1
            width:106*unit;height:144*unit
            x:modelData.x+(root.presence.scene.hostWidth-width)/2
            y:modelData.y+(root.presence.scene.hostHeight-height)/2
            opacity:root.opening
            scale:Math.max(.01,root.opening)
            rotation:modelData.edge==="left" || modelData.edge==="right" ? 90 : 0
            Shape {
                anchors.fill:parent
                preferredRendererType:Shape.CurveRenderer
                ShapePath {
                    strokeColor:AbyssStyle.accent;strokeWidth:3*mouth.unit
                    fillColor:Qt.rgba(AbyssStyle.accent.r*.12,AbyssStyle.accent.g*.12,AbyssStyle.accent.b*.12,.92)
                    PathAngleArc {centerX:mouth.width/2;centerY:mouth.height/2;radiusX:mouth.width*.42;radiusY:mouth.height*.46;startAngle:0;sweepAngle:360}
                }
            }
            Repeater {
                model:4
                delegate:Shape {
                    id:curl
                    required property int index
                    anchors.fill:parent;opacity:.72-index*.12
                    preferredRendererType:Shape.CurveRenderer
                    ShapePath {
                        strokeColor:AbyssStyle.accent;strokeWidth:(1.8-index*.2)*mouth.unit
                        fillColor:"transparent";capStyle:ShapePath.RoundCap
                        PathAngleArc {
                            centerX:mouth.width/2;centerY:mouth.height/2
                            radiusX:mouth.width*(.38-curl.index*.055)
                            radiusY:mouth.height*(.42-curl.index*.055)
                            startAngle:root.progress*720+curl.index*93+mouth.index*180
                            sweepAngle:235
                        }
                    }
                }
            }
        }
    }
}
