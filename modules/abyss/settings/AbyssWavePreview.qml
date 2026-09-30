import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.abyss
import qs.modules.abyss.looks
import "../looks/AbyssGeometry.js" as Geometry
Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: 160
    property bool expanded: false
    property real progress: expanded ? 1 : 0
    Behavior on progress { NumberAnimation { duration: AbyssStyle.motionNormal } }
    AbyssField {
        id: field;anchors.fill:parent
        edgeInsets: ({left:12,top:24,right:12,bottom:12})
        records: [Geometry.panel(width,height,edgeInsets,"top",width*.35,width*.3,58,root.progress,12)]
        waveTexture: waves.texture
    }
    AbyssWaveController {
        id: waves
        parent: field
        outputWidth: field.width;outputHeight:field.height
        presented: root.visible
        wavesEnabled: true
    }
    StyledText { anchors.centerIn:parent;text:"Click to test a wave · "+waves.mode }
    TapHandler {
        onTapped: eventPoint => {
            root.expanded=!root.expanded
            waves.impulse("top",eventPoint.position.x,100,root.expanded ? 1 : -.7,2,root.expanded ? "open" : "close")
        }
    }
}
