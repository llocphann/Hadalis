import QtQuick
import qs
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry

// This host never paints a panel. Its geometry record is consumed by the one
// output field, and its clipped content rectangle is the entire input region.
Item {
    id: root
    required property string edge
    property string outputName: ""
    property bool open: false
    property real along: 0
    property real span: 380
    property real depth: 320
    property real padding: AbyssStyle.contentPadding
    property var edgeInsets: ({left:8,top:8,right:8,bottom:8})
    property var obstacles: []
    property string source: ""
    property string contentKind: ""
    property real progress: open ? 1 : 0
    readonly property var record: Geometry.panel(width,height,edgeInsets,edge,along,span,depth,progress,padding,obstacles)
    readonly property Item contentItem: content
    readonly property bool ready: content.status === Loader.Ready
    readonly property rect inputBounds: open && ready
        ? Qt.rect(content.x,content.y,content.width,content.height) : Qt.rect(0,0,0,0)
    signal closeRequested()
    Behavior on progress {
        NumberAnimation {
            duration: AbyssStyle.motionNormal
            easing.type: root.open ? (AbyssStyle.motionOvershoot > 0 ? Easing.OutBack : Easing.OutCubic) : Easing.InCubic
            easing.overshoot: 0.4
        }
    }
    Loader {
        id: content
        x: root.record.content.x; y: root.record.content.y
        width: root.record.content.width; height: root.record.content.height
        active: root.progress > 0.001 && GlobalStates.deferredPanelsReady
        source: root.source
        clip: true
        opacity: Math.min(1,root.progress*1.5)
        enabled: root.open
        onLoaded: {
            if (item.outputName !== undefined) item.outputName = Qt.binding(() => root.outputName)
            if (item.kind !== undefined) item.kind = Qt.binding(() => root.contentKind)
            if (item.edge !== undefined) item.edge = Qt.binding(() => root.edge)
            if (item.closeRequested !== undefined) item.closeRequested.connect(root.closeRequested)
        }
    }
}
