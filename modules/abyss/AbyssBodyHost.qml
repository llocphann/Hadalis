import QtQuick
import qs
import qs.modules.common
import qs.modules.abyss.looks
import "looks/AbyssGeometry.js" as Geometry
import "looks/AbyssPyramidMotion.js" as PyramidMotion
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
    // Some owners need content-owned hold-open state even while visually closed.
    // Keep those contents resident so open never depends on a Loader whose
    // activation itself depends on open.
    property bool residentContent: false
    // Allocator changes (another popup/body entering, leaving, or reflowing)
    // should travel to their new tier instead of snapping the shared field to a
    // larger silhouette in one frame. Editor/Dock geometry stays immediate.
    property bool animatePlacementChanges:
        identity !== "dock" && identity !== "edgeEditor" && identity !== "editorPreview"
    property bool largeSurface: false
    // Keep Dock/icon geometry fixed, but let panel content reflow before any
    // lower-priority body is evicted. These are panel dimensions including
    // padding; hosts may raise them for feature-specific readability.
    property bool placementCanResize: identity !== "dock"
    property real minimumSpan: Math.min(span, placementCanResize
        ? (largeSurface ? 520 : 220) : span)
    property real minimumDepth: Math.min(depth, placementCanResize
        ? (largeSurface ? 360 : 120) : depth)
    readonly property real waveInfluence: Wave.bodyStrength(Config.options?.abyss?.waves)
    readonly property real mass: Math.max(1,span*depth/90000)
    property bool initialized: false
    property bool open: false
    // Pyramid v2 keeps semantic/input ownership separate from visual residency.
    // Non-popup bodies leave this undefined and retain the original open contract.
    property var semanticOpenOverride: undefined
    readonly property bool semanticOpen:
        semanticOpenOverride === undefined
            ? root.open : Boolean(semanticOpenOverride)
    readonly property bool visualResident:
        root.open || root.progress > 0.001
    readonly property bool acceptsInput:
        root.semanticOpen && root.placementVisible
    // Presentation policy only. The allocator remains a deterministic resting
    // layout producer; animation state is owned outside AbyssBodyPlacement.
    property string stackPolicy: ""
    property int activationOrder: 0
    property int placementPriority: identity === "dialog" ? 2 : ["utility","edgeEditor"].includes(identity) ? 1 : identity === "dock" ? -1 : 0
    readonly property var placement: controller?.bodyPlacements?.[identity] ?? null
    readonly property bool placementVisible: placement?.visible !== false
    // A temporarily evicted body retracts using its last valid geometry, keeps
    // its loaded feature/draft, and can reopen in place when space returns.
    property var retainedPlacement: null
    readonly property var layoutPlacement: placementVisible
        ? placement : (retainedPlacement ?? placement)
    readonly property var effectivePlacement: placementVisible
        ? placement : (progress > 0.001 ? retainedPlacement : placement)
    readonly property var pyramidCoordinator:
        root.controller?.pyramidCoordinator ?? null
    readonly property bool pyramidMotionEnabled:
        root.stackPolicy === "pyramid"
        && root.externalProgress >= 0
        && root.pyramidCoordinator !== null
    property bool pyramidClosing: false
    property var pyramidOriginRecord: null
    property var pyramidLatchedFullRecord: null
    // Last semantic-open resting state is the close snapshot authority. A QML
    // binding turn may remove the live allocator entry before the semantic
    // change handler runs, so close animation must never depend on that race.
    property var pyramidLastPlacement: null
    property var pyramidLastFullRecord: null
    readonly property var coordinatedPlacement:
        root.pyramidMotionEnabled
            ? root.pyramidCoordinator.targetFor(
                root.identity,root.effectivePlacement)
            : root.effectivePlacement
    // Keep allocator truth discrete, but interpolate its visible geometry. The
    // first placement snaps into place; later peer-induced tier/size changes
    // slide/reflow from the current frame and naturally reverse mid-flight.
    readonly property bool placementMotionReady: retainedPlacement !== null
    property real visualPlacementAlong: Number.isFinite(Number(coordinatedPlacement?.along))
        ? Number(coordinatedPlacement.along) : along
    property real visualPlacementSpan: Number.isFinite(Number(coordinatedPlacement?.span))
        ? Number(coordinatedPlacement.span) : span
    property real visualPlacementDepth: Number.isFinite(Number(coordinatedPlacement?.depth))
        ? Number(coordinatedPlacement.depth) : depth
    property real visualPlacementInward: Number.isFinite(Number(coordinatedPlacement?.inward))
        ? Number(coordinatedPlacement.inward) : 0
    readonly property var visualPlacement: coordinatedPlacement
        ? Object.assign({},coordinatedPlacement,{
            along:visualPlacementAlong,
            span:visualPlacementSpan,
            depth:visualPlacementDepth,
            inward:visualPlacementInward
        }) : null
    readonly property bool presented: open && placementVisible
    property real along: 0
    property real span: 380
    property real depth: 320
    property real padding: AbyssStyle.contentPadding
    property var edgeInsets: ({left:8,top:8,right:8,bottom:8})
    property var obstacles: []
    property string source: ""
    property string contentKind: ""
    // External presenters such as StyledPopup own their own reveal fraction.
    // Keep that motion independent from allocator availability: otherwise the
    // host's Behavior would re-animate every incoming reveal frame.
    property real externalProgress: -1
    property real availabilityProgress: presented ? 1 : 0
    property real progress: (externalProgress >= 0
        ? Math.max(0,Math.min(1,externalProgress)) : 1) * availabilityProgress
    readonly property var requestedRecord: Geometry.panel(width,height,edgeInsets,edge,along,span,depth,1,padding,[],largeSurface)
    // Resting geometry is still produced by AbyssGeometry from allocator output.
    // Pyramid motion only snapshots/interpolates this already-resolved record.
    readonly property var pyramidRestingRecord: Geometry.placedPanel(
        width,height,edgeInsets,edge,along,span,depth,1,padding,
        obstacles,largeSurface,visualPlacement)
    readonly property bool pyramidPresentationActive:
        root.pyramidMotionEnabled
        && (root.semanticOpen || root.pyramidClosing || root.progress > 0.001)
    readonly property var pyramidFullRecord:
        root.pyramidClosing && root.pyramidLatchedFullRecord
            ? root.pyramidLatchedFullRecord
            : (!root.semanticOpen && root.pyramidLastFullRecord
                ? root.pyramidLastFullRecord : root.pyramidRestingRecord)
    readonly property var rawPresentationRecord:
        root.pyramidPresentationActive && root.pyramidFullRecord
            ? PyramidMotion.interpolateRecord(
                root.pyramidOriginRecord
                    ?? PyramidMotion.collapsedRecord(
                        root.pyramidFullRecord,null),
                root.pyramidFullRecord,root.progress)
            : Geometry.placedPanel(width,height,edgeInsets,edge,along,span,
                depth,progress,padding,obstacles,largeSurface,
                visualPlacement)
    readonly property var record: Geometry.joinCorner(
        rawPresentationRecord,joinedEdge,width,height,edgeInsets)
    readonly property var targetRecord: Geometry.placedPanel(width,height,edgeInsets,edge,along,span,depth,1,padding,obstacles,largeSurface,layoutPlacement)
    readonly property Item contentItem: content
    readonly property bool ready: embeddedItem !== null || content.status === Loader.Ready
    readonly property Item contentParent: contentCanvas
    readonly property rect inputBounds: acceptsInput && ready
        ? Qt.rect(contentFrame.x,contentFrame.y,contentFrame.width,contentFrame.height) : Qt.rect(0,0,0,0)
    signal closeRequested()
    AbyssParticipant {
        id: participant
        identity: root.identity
        controller: root.controller
        geometry: root.record
        restingRecord: root.pyramidRestingRecord
        visualPlacement: root.visualPlacement
        placementRequest: ({id:root.identity,open:root.semanticOpen,order:root.activationOrder,
            priority:root.placementPriority,padding:root.padding,
            minSpan:root.minimumSpan,minDepth:root.minimumDepth,
            stackPolicy:root.stackPolicy,
            record:root.requestedRecord})
        inputBounds: root.inputBounds
        mass: root.mass
    }
    function react(opening): void {
        if (controller) controller.impulse(edge,along+span/2,span,(opening ? 0.85 : -0.65)*waveInfluence,mass,opening ? "open" : "close")
    }
    function markOpened(): void { if (open && controller?.nextPresentationOrder) activationOrder=controller.nextPresentationOrder() }
    function resetPyramidMotion(): void {
        root.pyramidCoordinator?.resetIdentity(root.identity)
        root.pyramidClosing=false
        root.pyramidOriginRecord=null
        root.pyramidLatchedFullRecord=null
        root.pyramidLastPlacement=null
        root.pyramidLastFullRecord=null
    }
    function capturePyramidRestingState(): void {
        if (!root.pyramidMotionEnabled || !root.semanticOpen
                || !root.visualPlacement || !root.pyramidRestingRecord)
            return
        root.pyramidLastPlacement=
            PyramidMotion.clonePlacement(root.visualPlacement)
        root.pyramidLastFullRecord=
            PyramidMotion.cloneRecord(root.pyramidRestingRecord)
    }
    function resetPresentationOwner(): void {
        // Stable hosts may be reused by a different semantic popup owner.
        // Clear the previous allocator snapshot while the old owner is hidden so
        // the next owner snaps to its own tangent anchor before reveal starts.
        root.retainedPlacement=null
        root.resetPyramidMotion()
    }
    function syncPyramidEntryOrigin(): void {
        if (!root.pyramidMotionEnabled || !root.semanticOpen
                || root.pyramidClosing || !root.visualPlacement
                || !root.pyramidRestingRecord)
            return
        const origin=root.pyramidCoordinator?.entryOrigin(
            root.identity,participant.placementRequest,
            root.visualPlacement,root.pyramidRestingRecord)
        if (origin)
            root.pyramidOriginRecord=origin
    }
    function syncPyramidSemanticState(): void {
        if (!root.pyramidMotionEnabled)
            return
        if (root.semanticOpen) {
            if (root.pyramidClosing) {
                // Reopen uses the same origin and the present reveal scalar,
                // so the animation reverses from its current frame.
                root.pyramidCoordinator?.cancelClose(root.identity)
                root.pyramidClosing=false
                root.pyramidLatchedFullRecord=null
                return
            }
            Qt.callLater(root.syncPyramidEntryOrigin)
            return
        }
        const closingPlacement=root.pyramidLastPlacement
            ?? root.visualPlacement
        const closingRecord=root.pyramidLastFullRecord
            ?? root.pyramidRestingRecord
        if (!closingPlacement || !closingRecord)
            return
        root.pyramidLatchedFullRecord=
            PyramidMotion.cloneRecord(closingRecord)
        root.pyramidOriginRecord=root.pyramidCoordinator?.beginClose(
            root.identity,participant.placementRequest,
            closingPlacement,root.pyramidLatchedFullRecord)
            ?? PyramidMotion.collapsedRecord(
                root.pyramidLatchedFullRecord,null)
        root.pyramidClosing=true
    }
    onPlacementChanged: {
        if (placement?.visible !== false)
            retainedPlacement = placement
        if (initialized && semanticOpen && pyramidMotionEnabled
                && !pyramidClosing) {
            root.capturePyramidRestingState()
            Qt.callLater(root.syncPyramidEntryOrigin)
        }
    }
    onPyramidRestingRecordChanged: if (initialized)
        root.capturePyramidRestingState()
    onVisualPlacementChanged: if (initialized)
        root.capturePyramidRestingState()
    onSemanticOpenChanged: if (initialized)
        root.syncPyramidSemanticState()
    onProgressChanged: {
        if (!initialized || !root.pyramidClosing
                || root.semanticOpen || root.progress > 0.001)
            return
        root.pyramidCoordinator?.finishClose(root.identity)
        root.pyramidClosing=false
        root.pyramidLatchedFullRecord=null
        root.pyramidOriginRecord=null
    }
    onOpenChanged: if (initialized) { markOpened();react(open) }
    onEmbeddedItemChanged: if (initialized) markOpened()
    onContentKindChanged: if (initialized) markOpened()
    onControllerChanged: if (initialized) {
        root.resetPyramidMotion()
        markOpened()
    }
    Component.onCompleted: {
        initialized = true
        markOpened()
        if (semanticOpen) {
            root.capturePyramidRestingState()
            Qt.callLater(root.syncPyramidEntryOrigin)
        }
        if (open) Qt.callLater(() => { if (root.open) root.react(true) })
    }
    Keys.onEscapePressed: root.closeRequested()
    Behavior on visualPlacementAlong {
        enabled: root.animatePlacementChanges && root.placementMotionReady
            && AbyssStyle.motionEnabled
        NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
    }
    Behavior on visualPlacementSpan {
        enabled: root.animatePlacementChanges && root.placementMotionReady
            && AbyssStyle.motionEnabled
        NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
    }
    Behavior on visualPlacementDepth {
        enabled: root.animatePlacementChanges && root.placementMotionReady
            && AbyssStyle.motionEnabled
        NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
    }
    Behavior on visualPlacementInward {
        enabled: root.animatePlacementChanges && root.placementMotionReady
            && AbyssStyle.motionEnabled
        NumberAnimation { duration: AbyssStyle.motionNormal; easing.type: Easing.OutCubic }
    }
    Behavior on availabilityProgress {
        id: availabilityMotion
        enabled: root.animatePresentation && AbyssStyle.motionEnabled
        SequentialAnimation {
            NumberAnimation {
                to: availabilityMotion.targetValue > 0
                    ? availabilityMotion.targetValue+AbyssStyle.motionOvershoot : 0
                duration: Math.round(AbyssStyle.motionNormal
                    *(1+Math.min(0.5,Math.sqrt(root.mass)*0.1)))
                easing.type: root.presented ? Easing.OutCubic : Easing.InCubic
            }
            NumberAnimation {
                to: availabilityMotion.targetValue
                duration: root.presented && AbyssStyle.motionOvershoot > 0
                    ? Math.round(AbyssStyle.motionSettle
                        *(1+Math.min(0.5,Math.sqrt(root.mass)*0.1))) : 0
                easing.type: Easing.OutCubic
            }
        }
    }
    Item {
        id: contentFrame
        x: root.record.content.x; y: root.record.content.y
        width: root.pyramidPresentationActive
            ? root.record.content.width
            : (root.placementVisible
                ? root.record.content.width : root.targetRecord.content.width)
        height: root.pyramidPresentationActive
            ? root.record.content.height
            : (root.placementVisible
                ? root.record.content.height : root.targetRecord.content.height)
        clip: true
        visible: root.pyramidPresentationActive
            ? (root.semanticOpen || root.progress > 0.001)
            : (root.placementVisible || root.progress > 0.001)
        // Pyramid uses the same pure slide-under principle as StyledPopup:
        // content remains full-size behind a moving clip; it never fades/shrinks.
        opacity: root.pyramidPresentationActive
            ? 1 : Math.min(1,root.progress*1.5)
        enabled: root.acceptsInput

        Item {
            id: contentCanvas
            readonly property var fullRect:
                root.pyramidFullRecord?.content ?? root.targetRecord.content
            x: root.pyramidPresentationActive
                ? fullRect.x-contentFrame.x : 0
            y: root.pyramidPresentationActive
                ? fullRect.y-contentFrame.y : 0
            width: root.pyramidPresentationActive
                ? fullRect.width : contentFrame.width
            height: root.pyramidPresentationActive
                ? fullRect.height : contentFrame.height
        }
    }
    Loader {
        id: content
        parent: contentCanvas
        x: 0; y: 0
        // Reveal clips/slides a fixed-size content canvas. Icons, labels and
        // controls retain their dimensions throughout opening/closing/reversal.
        width: root.pyramidPresentationActive
            ? contentCanvas.width
            : (root.stableContentSize
                ? root.targetRecord.content.width : contentFrame.width)
        height: root.pyramidPresentationActive
            ? contentCanvas.height
            : (root.stableContentSize
                ? root.targetRecord.content.height : contentFrame.height)
        // A space-constrained body retains drafts/focus state while hidden. It
        // unloads only after a semantic close and completion of the reveal.
        active: !root.embeddedItem
            && (root.residentContent || root.visualResident)
            && GlobalStates.deferredPanelsReady
        source: root.source
        clip: true
        opacity: 1
        enabled: root.acceptsInput
        onLoaded: {
            if (item.participant !== undefined) item.participant = root
            if (item.outputName !== undefined) item.outputName = Qt.binding(() => root.outputName)
            if (item.kind !== undefined) item.kind = Qt.binding(() => root.contentKind)
            if (item.edge !== undefined) item.edge = Qt.binding(() => root.edge)
            if (item.closeRequested !== undefined) item.closeRequested.connect(root.closeRequested)
        }
    }
}
