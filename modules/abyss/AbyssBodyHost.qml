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
    property string identity: ""
    property var controller: null
    readonly property var liquidController: controller
    property Item embeddedItem: null
    property bool largeSurface: false
    readonly property real mass: Math.max(1,span*depth/90000)
    property bool initialized: false
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
    readonly property var record: Geometry.panel(width,height,edgeInsets,edge,along,span,depth,progress,padding,obstacles,largeSurface)
    readonly property Item contentItem: content
    readonly property bool ready: embeddedItem !== null || content.status === Loader.Ready
    readonly property Item contentParent: contentFrame
    readonly property rect inputBounds: open && ready
        ? Qt.rect(contentFrame.x,contentFrame.y,contentFrame.width,contentFrame.height) : Qt.rect(0,0,0,0)
    signal closeRequested()
    AbyssParticipant {
        identity: root.identity
        controller: root.controller
        geometry: root.record
        inputBounds: root.inputBounds
        mass: root.mass
    }
    function react(opening): void {
        if (controller) controller.impulse(edge,along+span/2,span,opening ? 0.85 : -0.65,mass,opening ? "open" : "close")
    }
    onOpenChanged: if (initialized) react(open)
    Component.onCompleted: {
        initialized = true
        if (open) Qt.callLater(() => { if (root.open) root.react(true) })
    }
    Keys.onEscapePressed: root.closeRequested()
    Behavior on progress {
        id: deformation
        enabled: AbyssStyle.motionEnabled
        SequentialAnimation {
            NumberAnimation {
                to: deformation.targetValue > 0 ? deformation.targetValue+AbyssStyle.motionOvershoot : 0
                duration: Math.round(AbyssStyle.motionNormal*(1+Math.min(0.5,Math.sqrt(root.mass)*0.1)))
                easing.type: root.open ? Easing.OutCubic : Easing.InCubic
            }
            NumberAnimation {
                to: deformation.targetValue
                duration: root.open && AbyssStyle.motionOvershoot > 0 ? Math.round(AbyssStyle.motionSettle*(1+Math.min(0.5,Math.sqrt(root.mass)*0.1))) : 0
                easing.type: Easing.OutCubic
            }
        }
    }
    Item {
        id: contentFrame
        x: root.record.content.x; y: root.record.content.y
        width: root.record.content.width; height: root.record.content.height
        clip: true
        opacity: Math.min(1,root.progress*1.5)
        enabled: root.open
    }
    Loader {
        id: content
        // Keep the Loader geometry/API used by ordinary content adapters.
        x: root.record.content.x; y: root.record.content.y
        width: root.record.content.width; height: root.record.content.height
        active: !root.embeddedItem && root.progress > 0.001 && GlobalStates.deferredPanelsReady
        source: root.source
        clip: true
        opacity: Math.min(1,root.progress*1.5)
        enabled: root.open
        onLoaded: {
            if (item.participant !== undefined) item.participant = root
            if (item.outputName !== undefined) item.outputName = Qt.binding(() => root.outputName)
            if (item.kind !== undefined) item.kind = Qt.binding(() => root.contentKind)
            if (item.edge !== undefined) item.edge = Qt.binding(() => root.edge)
            if (item.closeRequested !== undefined) item.closeRequested.connect(root.closeRequested)
        }
    }
}
