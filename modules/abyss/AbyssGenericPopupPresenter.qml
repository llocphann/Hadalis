pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.modules.abyss.looks
import "looks/AbyssPresentation.js" as Presentation

// One generic popup owner per output.
//
// Different popup kinds never mutate one live body's tangent geometry. A kind
// switch retracts the current owner completely, then latches the next kind,
// Edge, tangent anchor and optional adjacent-Edge join before reveal begins.
// This intentionally has no pyramid/group placement behavior.
Item {
    id: root

    required property var controller
    required property string outputName
    required property real outputWidth
    required property real outputHeight

    property var positions: []
    property var presentationInsets: ({left:8,top:8,right:8,bottom:8})
    property var obstacles: []
    property var bodyInsetsResolver: null

    property string requestedKind: ""
    property bool requestedOpen: false
    property string requestedFallbackEdge: "top"
    property real requestedAlongCenter: 0
    property string hoverKind: ""

    property string activeKind: ""
    property var activePosition: ({})
    property string activeFallbackEdge: "top"
    property real activeAlongCenter: 0
    property bool resident: false
    property real offsetScale: 1
    readonly property real revealProgress: 1 - offsetScale
    readonly property string desiredKind:
        requestedOpen ? String(requestedKind ?? "") : ""

    readonly property bool open: resident
    readonly property bool presented: body.presented
    readonly property bool ready: body.ready
    readonly property Item contentItem: body.contentItem
    readonly property rect inputBounds: body.inputBounds
    readonly property real progress: body.progress
    readonly property var record: body.record
    readonly property string contentKind: activeKind

    signal closeRequested(string kind)

    function beginReveal(): void {
        if (!root.resident || root.activeKind.length === 0
                || root.desiredKind !== root.activeKind)
            return
        retractTimer.stop()
        if (!AbyssStyle.motionEnabled) {
            root.offsetScale = 0
            return
        }
        Qt.callLater(() => {
            if (root.resident && root.desiredKind === root.activeKind)
                root.offsetScale = 0
        })
    }

    function latch(kind): void {
        if (!kind) return
        root.activeKind = String(kind)
        root.activePosition = Object.assign({},
            Presentation.resolve(root.positions,root.activeKind,root.outputName))
        root.activeFallbackEdge = root.requestedFallbackEdge
        root.activeAlongCenter = Number(root.requestedAlongCenter ?? 0)
        root.offsetScale = 1
        root.resident = true
        root.beginReveal()
    }

    function finishRetract(): void {
        if (!root.resident)
            return
        root.resident = false
        root.activeKind = ""
        root.activePosition = ({})
        Qt.callLater(root.syncRequest)
    }

    function beginRetract(): void {
        if (!root.resident)
            return
        root.offsetScale = 1
        if (AbyssStyle.motionEnabled)
            retractTimer.restart()
        else
            root.finishRetract()
    }

    function syncRequest(): void {
        const desired=root.desiredKind
        if (!desired) {
            if (root.resident)
                root.beginRetract()
            return
        }

        if (!root.resident) {
            root.latch(desired)
            return
        }

        if (desired === root.activeKind) {
            root.beginReveal()
            return
        }

        // A different kind waits behind the current visual tail. It cannot
        // inherit the old body's placement or animate from its previous anchor.
        root.beginRetract()
    }

    onDesiredKindChanged: syncRequest()
    onRequestedFallbackEdgeChanged:
        if (!resident) activeFallbackEdge=requestedFallbackEdge
    onRequestedAlongCenterChanged:
        if (!resident) activeAlongCenter=requestedAlongCenter

    Component.onCompleted: syncRequest()

    Behavior on offsetScale {
        enabled: AbyssStyle.motionEnabled
        NumberAnimation {
            duration: AbyssStyle.motionNormal
            easing.type: Easing.InOutCubic
        }
    }

    Timer {
        id: retractTimer
        interval: Math.max(1,AbyssStyle.motionNormal+20)
        repeat: false
        onTriggered: {
            if (root.offsetScale >= .999)
                root.finishRetract()
        }
    }

    AbyssBodyHost {
        id: body
        anchors.fill: parent
        identity: "popup"
        controller: root.controller
        outputName: root.outputName

        // Tangent placement is latched before resident/open becomes true.
        // Disable the generic allocator's placement Behaviors: the only popup
        // motion here is the edge-normal reveal/retract fraction below.
        animatePlacementChanges: false
        animatePresentation: false
        placementCanResize: false
        stableContentSize: true

        edge: Presentation.edge(root.activePosition,
            root.activeFallbackEdge)
        edgeInsets: root.bodyInsetsResolver
            ? root.bodyInsetsResolver(edge,along,span)
            : root.presentationInsets
        padding: 14
        span: (edge === "top" || edge === "bottom"
            ? (contentItem.item?.desiredWidth ?? 390)
            : (contentItem.item?.desiredHeight ?? 300)) + padding*2
        depth: (edge === "top" || edge === "bottom"
            ? (contentItem.item?.desiredHeight ?? 300)
            : (contentItem.item?.desiredWidth ?? 390)) + padding*2
        largeSurface: depth
            > ((edge === "top" || edge === "bottom")
                ? root.outputHeight : root.outputWidth)*.42
        along: Presentation.along(root.activePosition,edge,span,
            root.outputWidth,root.outputHeight,
            root.activeAlongCenter-span/2,root.presentationInsets)
        joinedEdge: Presentation.joinedEdge(root.activeKind,
            root.activePosition,edge,along,span,
            root.outputWidth,root.outputHeight)

        placementPriority: root.activeKind === "dockAppMenu" ? -2 : 0
        obstacles: root.obstacles
        contentKind: root.activeKind
        property bool triggerHovered:
            root.activeKind === "dockAppMenu"
                ? GlobalStates.abyssDockMenuTriggerHovered
                : ["wifi","bluetooth","utilities"].includes(root.activeKind)
                    && root.hoverKind === root.activeKind
        source: "content/AbyssPopupContent.qml"

        open: root.resident
        externalProgress: root.revealProgress
        onReadyChanged: if (ready) root.beginReveal()
        onCloseRequested: root.closeRequested(root.activeKind)
    }
}
