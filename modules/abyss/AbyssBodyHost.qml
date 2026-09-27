import QtQuick
import qs
import qs.modules.common
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry
import "looks/AbyssWave.js" as Wave

// This host never paints a panel. Its geometry record is consumed by the one
// output field, and its clipped content rectangle is the entire input region.
Item {
    id: root
    required property string edge
    property string joinedEdge: ""
    readonly property string attachedEdge: edge
    property string outputName: ""
    property string identity: ""
    property var controller: null
    readonly property var liquidController: controller
    property Item embeddedItem: null
    property bool animatePresentation: true
    property bool stableContentSize: false
    property bool largeSurface: false
    readonly property real waveInfluence: Wave.bodyStrength(Config.options?.abyss?.waves)
    readonly property real mass: Math.max(1,span*depth/90000)
    property bool initialized: false
    property bool open: false
    property int activationOrder: 0
    property int placementPriority: identity === "dialog" ? 2 : ["utility","edgeEditor"].includes(identity) ? 1 : identity === "dock" ? -1 : 0
    readonly property var placement: controller?.bodyPlacements?.[identity] ?? null
    readonly property bool placementVisible: placement?.visible !== false
    readonly property bool presented: open && placementVisible
    property real along: 0
    property real span: 380
    property real depth: 320
    property real padding: AbyssStyle.contentPadding
    property var edgeInsets: ({left:8,top:8,right:8,bottom:8})
    property var obstacles: []
    property string source: ""
    property string contentKind: ""
    property real progress: presented ? 1 : 0
    readonly property var requestedRecord: Geometry.panel(width,height,edgeInsets,edge,along,span,depth,1,padding,[],largeSurface)
    readonly property var record: Geometry.joinCorner(Geometry.placedPanel(width,height,edgeInsets,edge,along,span,depth,progress,padding,obstacles,largeSurface,placement),joinedEdge,width,height,edgeInsets)
    readonly property var targetRecord: Geometry.placedPanel(width,height,edgeInsets,edge,along,span,depth,1,padding,obstacles,largeSurface,placement)
    readonly property Item contentItem: content
    readonly property bool ready: embeddedItem !== null || content.status === Loader.Ready
    readonly property Item contentParent: contentFrame
    readonly property rect inputBounds: presented && ready
        ? Qt.rect(contentFrame.x,contentFrame.y,contentFrame.width,contentFrame.height) : Qt.rect(0,0,0,0)
    signal closeRequested()
    AbyssParticipant {
        identity: root.identity
        controller: root.controller
        geometry: root.record
        placementRequest: ({id:root.identity,open:root.open,order:root.activationOrder,
            priority:root.placementPriority,
            record:root.requestedRecord})
        inputBounds: root.inputBounds
        mass: root.mass
    }
    function react(opening): void {
        if (controller) controller.impulse(edge,along+span/2,span,(opening ? 0.85 : -0.65)*waveInfluence,mass,opening ? "open" : "close")
    }
    function markOpened(): void { if (open && controller?.nextPresentationOrder) activationOrder=controller.nextPresentationOrder() }
    onOpenChanged: if (initialized) { markOpened();react(open) }
    onEmbeddedItemChanged: if (initialized) markOpened()
    onContentKindChanged: if (initialized) markOpened()
    onControllerChanged: if (initialized) markOpened()
    Component.onCompleted: {
        initialized = true
        markOpened()
        if (open) Qt.callLater(() => { if (root.open) root.react(true) })
    }
    Keys.onEscapePressed: root.closeRequested()
    Behavior on progress {
        id: deformation
        enabled: root.animatePresentation && AbyssStyle.motionEnabled
        SequentialAnimation {
            NumberAnimation {
                to: deformation.targetValue > 0 ? deformation.targetValue+AbyssStyle.motionOvershoot : 0
                duration: Math.round(AbyssStyle.motionNormal*(1+Math.min(0.5,Math.sqrt(root.mass)*0.1)))
                easing.type: root.presented ? Easing.OutCubic : Easing.InCubic
            }
            NumberAnimation {
                to: deformation.targetValue
                duration: root.presented && AbyssStyle.motionOvershoot > 0 ? Math.round(AbyssStyle.motionSettle*(1+Math.min(0.5,Math.sqrt(root.mass)*0.1))) : 0
                easing.type: Easing.OutCubic
            }
        }
    }
    Item {
        id: contentFrame
        x: root.record.content.x; y: root.record.content.y
        width: root.placementVisible ? root.record.content.width : root.targetRecord.content.width
        height: root.placementVisible ? root.record.content.height : root.targetRecord.content.height
        clip: true
        visible: root.placementVisible
        opacity: Math.min(1,root.progress*1.5)
        enabled: root.presented
    }
    Loader {
        id: content
        parent: contentFrame
        x: 0; y: 0
        // Reveal clips/slides a Dock's fixed-size contents. Icons and menus
        // retain their dimensions throughout opening, closing and reversals.
        width: root.stableContentSize ? root.targetRecord.content.width : contentFrame.width
        height: root.stableContentSize ? root.targetRecord.content.height : contentFrame.height
        // A space-constrained body retains drafts/focus state while hidden. It
        // unloads only after a semantic close and completion of the reveal.
        active: !root.embeddedItem && (root.open || root.progress > 0.001) && GlobalStates.deferredPanelsReady
        source: root.source
        clip: true
        opacity: 1
        enabled: root.presented
        onLoaded: {
            if (item.participant !== undefined) item.participant = root
            if (item.outputName !== undefined) item.outputName = Qt.binding(() => root.outputName)
            if (item.kind !== undefined) item.kind = Qt.binding(() => root.contentKind)
            if (item.edge !== undefined) item.edge = Qt.binding(() => root.edge)
            if (item.closeRequested !== undefined) item.closeRequested.connect(root.closeRequested)
        }
    }
}
