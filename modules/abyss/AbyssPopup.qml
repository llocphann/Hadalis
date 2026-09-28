pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.modules.abyss.looks

// Dedicated lifecycle for output-owned Abyss popups.
//
// Every popup kind owns a stable body. Semantic visibility, visual residency
// and reveal motion are separated exactly as they are for mature StyledPopup
// surfaces, so a newly-hovered popup never inherits another kind's placement.
Item {
    id: root

    required property var controller
    required property string outputName
    required property real outputWidth
    required property real outputHeight

    property string requestedKind: ""
    property bool requestedOpen: false
    property string requestedFallbackEdge: "top"
    property real requestedAlongCenter: 0
    property string hoverKind: ""
    property var obstacles: []

    // Presentation policy remains owned by AbyssPerimeter. These callbacks keep
    // this component independent from bar/editor layout internals.
    property var positionEdgeResolver: null
    property var positionAlongResolver: null
    property var bodyInsetsResolver: null
    property var joinedEdgeResolver: null

    readonly property var supportedKinds: [
        "clock", "battery", "resources", "weather", "utilities",
        "launcher", "dockAppMenu", "wifi", "bluetooth", "audio", "media"
    ]

    function kindIndex(kind): int {
        return root.supportedKinds.indexOf(String(kind ?? ""))
    }
    readonly property var requestedSlot: {
        const index = root.kindIndex(root.requestedKind)
        return index >= 0 ? slots.itemAt(index) : null
    }
    readonly property bool open:
        root.requestedOpen && root.requestedSlot !== null
    readonly property bool presented:
        root.requestedSlot?.hostedBody?.presented ?? false
    readonly property bool ready:
        root.requestedSlot?.hostedBody?.ready ?? false
    readonly property Item contentItem:
        root.requestedSlot?.hostedBody?.contentItem ?? null
    readonly property rect inputBounds:
        root.requestedSlot?.hostedBody?.inputBounds
            ?? Qt.rect(0, 0, 0, 0)
    readonly property real progress:
        root.requestedSlot?.hostedBody?.progress ?? 0
    readonly property var record:
        root.requestedSlot?.hostedBody?.record ?? null

    signal closeRequested(string kind)

    function rectsOverlap(a, b, gap = 0): bool {
        if (!a || !b) return false
        return a.x < b.x + b.width + gap
            && a.x + a.width + gap > b.x
            && a.y < b.y + b.height + gap
            && a.y + a.height + gap > b.y
    }
    function overlapsRect(rect, gap = 0): bool {
        for (let i = 0; i < slots.count; ++i) {
            const slot = slots.itemAt(i)
            if (!slot?.requestedVisible)
                continue
            const surface = slot.hostedBody?.requestedRecord?.surface
            if (root.rectsOverlap(surface, rect, gap))
                return true
        }
        return false
    }

    Repeater {
        id: slots
        model: root.supportedKinds

        delegate: Item {
            id: slot
            required property var modelData
            readonly property string kind: String(modelData)
            anchors.fill: parent

            readonly property bool requestedVisible:
                root.requestedOpen && root.requestedKind === slot.kind

            property bool lingerVisible: false
            property real offsetScale: 1
            readonly property real revealProgress: 1 - offsetScale
            property string latchedEdge: "top"
            property real latchedAnchorCenter: 0

            readonly property var hostedBody: body

            function latchRequestGeometry(): void {
                slot.latchedEdge = root.positionEdgeResolver
                    ? root.positionEdgeResolver(slot.kind,
                        root.requestedFallbackEdge)
                    : root.requestedFallbackEdge
                slot.latchedAnchorCenter = Number(root.requestedAlongCenter ?? 0)
            }

            function syncRequestedVisibility(): void {
                if (slot.requestedVisible) {
                    const alreadyResident = slot.lingerVisible
                    retractTimer.stop()
                    slot.latchRequestGeometry()
                    slot.lingerVisible = true
                    if (!AbyssStyle.motionEnabled) {
                        slot.offsetScale = 0
                        return
                    }
                    if (alreadyResident) {
                        // Reverse an in-flight retract from its current frame.
                        slot.offsetScale = 0
                        return
                    }

                    // Join the allocator at revealProgress == 0, then start the
                    // reveal one event-loop turn later. The first visible frame
                    // is therefore already at this popup kind's own anchor.
                    slot.offsetScale = 1
                    Qt.callLater(() => {
                        if (slot.requestedVisible)
                            slot.offsetScale = 0
                    })
                    return
                }

                if (!slot.lingerVisible)
                    return

                slot.offsetScale = 1
                if (AbyssStyle.motionEnabled)
                    retractTimer.restart()
                else
                    slot.lingerVisible = false
            }

            onRequestedVisibleChanged: syncRequestedVisibility()

            Component.onCompleted: {
                if (slot.requestedVisible) {
                    slot.latchRequestGeometry()
                    syncRequestedVisibility()
                }
            }

            Behavior on offsetScale {
                enabled: AbyssStyle.motionEnabled
                NumberAnimation {
                    duration: AbyssStyle.motionNormal
                    easing.type: Easing.InOutCubic
                }
            }

            Timer {
                id: retractTimer
                interval: Math.max(1, AbyssStyle.motionNormal + 20)
                repeat: false
                onTriggered: {
                    if (!slot.requestedVisible && slot.offsetScale >= 0.999)
                        slot.lingerVisible = false
                }
            }

            AbyssBodyHost {
                id: body
                identity: "popup." + slot.kind
                controller: root.controller
                anchors.fill: parent
                outputName: root.outputName

                edge: slot.latchedEdge
                along: root.positionAlongResolver
                    ? root.positionAlongResolver(slot.kind, edge, span,
                        slot.latchedAnchorCenter - span / 2)
                    : slot.latchedAnchorCenter - span / 2
                joinedEdge: root.joinedEdgeResolver
                    ? root.joinedEdgeResolver(slot.kind, edge, along, span)
                    : ""

                open: slot.lingerVisible
                semanticOpenOverride: slot.requestedVisible
                animatePresentation: false
                externalProgress: slot.revealProgress
                stableContentSize: true
                placementCanResize: false
                pyramidStack: true

                edgeInsets: root.bodyInsetsResolver
                    ? root.bodyInsetsResolver(edge, along, span)
                    : ({left:8, top:8, right:8, bottom:8})
                padding: 14
                span: (edge === "top" || edge === "bottom"
                    ? (contentItem.item?.desiredWidth ?? 390)
                    : (contentItem.item?.desiredHeight ?? 300)) + padding * 2
                depth: (edge === "top" || edge === "bottom"
                    ? (contentItem.item?.desiredHeight ?? 300)
                    : (contentItem.item?.desiredWidth ?? 390)) + padding * 2
                largeSurface: depth
                    > ((edge === "top" || edge === "bottom")
                        ? root.outputHeight : root.outputWidth) * .42
                placementPriority: slot.kind === "dockAppMenu" ? -2 : 0
                obstacles: root.obstacles
                contentKind: slot.kind
                property bool triggerHovered:
                    slot.kind === "dockAppMenu"
                        ? GlobalStates.abyssDockMenuTriggerHovered
                        : ["wifi", "bluetooth", "utilities", "launcher"].includes(slot.kind)
                            && root.hoverKind === slot.kind
                source: "content/AbyssPopupContent.qml"

                onCloseRequested: root.closeRequested(slot.kind)
            }
        }
    }
}
