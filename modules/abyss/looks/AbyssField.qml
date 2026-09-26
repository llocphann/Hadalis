import QtQuick
import qs.modules.common

Item {
    id: root
    property var records: []
    property var edgeInsets: ({left:8,top:8,right:8,bottom:8})
    readonly property int capacity: 12
    readonly property bool ready: pass.status === ShaderEffect.Compiled
    readonly property string diagnostic: pass.log
    function packed(index) {
        const r = root.records[index]?.surface
        return r ? Qt.vector4d(r.x,r.y,r.width,r.height) : Qt.vector4d(0,0,0,0)
    }
    ShaderEffect {
        id: pass
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("AbyssField.frag.qsb")
        readonly property vector4d viewport: Qt.vector4d(root.width,root.height,0,0)
        readonly property vector4d insets: Qt.vector4d(root.edgeInsets.left,root.edgeInsets.top,root.edgeInsets.right,root.edgeInsets.bottom)
        readonly property vector4d material: Qt.vector4d(AbyssStyle.perimeterRadius,AbyssStyle.connectionDepth,AbyssStyle.neckRadius,AbyssStyle.highlightStrength)
        readonly property color surface: AbyssStyle.surface
        readonly property color raised: AbyssStyle.surfaceRaised
        readonly property color rim: AbyssStyle.specular
        readonly property color shadow: AbyssStyle.shadow
        readonly property color glow: AbyssStyle.glow
        readonly property vector4d rect0: root.packed(0)
        readonly property vector4d rect1: root.packed(1)
        readonly property vector4d rect2: root.packed(2)
        readonly property vector4d rect3: root.packed(3)
        readonly property vector4d rect4: root.packed(4)
        readonly property vector4d rect5: root.packed(5)
        readonly property vector4d rect6: root.packed(6)
        readonly property vector4d rect7: root.packed(7)
        readonly property vector4d rect8: root.packed(8)
        readonly property vector4d rect9: root.packed(9)
        readonly property vector4d rect10: root.packed(10)
        readonly property vector4d rect11: root.packed(11)
        onStatusChanged: if (status === ShaderEffect.Error) console.error("[AbyssField]", log)
    }
}
