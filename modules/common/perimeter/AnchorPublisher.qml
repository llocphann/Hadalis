import QtQuick

Item {
    id: root

    required property Item sourceItem
    required property string outputName
    required property string slotId
    required property string instanceId
    required property string moduleId

    property string surfaceName: "default"
    property size preferredExtent: Qt.size(0, 0)
    readonly property string coordinateSpace: "output-local"
    property int refreshToken: 0

    // Output-local provenance is explicit. Callers may supply a reference bridge
    // directly, or hosted perimeter modules may inherit the same trusted bridge
    // from sourceItem.perimeterContext. We never fall back to mapToItem(null):
    // null maps into scene/window coordinates, not output-local coordinates.
    property Item referenceItem: null
    property rect referenceRect: Qt.rect(0, 0, 0, 0)
    readonly property var sourceContext: root.sourceItem?.perimeterContext ?? null
    readonly property Item effectiveReferenceItem: root.referenceItem
        ?? root.sourceContext?.slotItem ?? null
    readonly property rect effectiveReferenceRect: root.referenceItem !== null
        ? root.referenceRect
        : (root.sourceContext?.slotRect ?? Qt.rect(0, 0, 0, 0))
    readonly property int contextLayoutRevision:
        Number(root.sourceContext?.layoutRevision ?? 0)
    readonly property bool referenceReady: effectiveReferenceItem !== null
        && effectiveReferenceRect.width > 0 && effectiveReferenceRect.height > 0

    property string _publishedOutputName: ""
    property string _publishedInstanceId: ""
    property string _publishedSurfaceName: ""
    property double _publisherGeneration: 0

    width: 0
    height: 0
    visible: false

    function _surfaceKeyName() {
        return String(root.surfaceName || "default")
    }

    function _ensurePublisherGeneration() {
        if (root._publisherGeneration <= 0)
            root._publisherGeneration = AnchorRegistry.allocatePublisherGeneration()
        return root._publisherGeneration
    }

    function _unregisterPublished() {
        if (root._publishedOutputName && root._publishedInstanceId) {
            AnchorRegistry.unregister(root._publishedOutputName,
                root._publishedInstanceId, root._publishedSurfaceName,
                root._publisherGeneration)
        }
        root._publishedOutputName = ""
        root._publishedInstanceId = ""
        root._publishedSurfaceName = ""
    }

    function _identityMatches(outputName, instanceId, surfaceName) {
        return root._publishedOutputName === outputName
            && root._publishedInstanceId === instanceId
            && root._publishedSurfaceName === surfaceName
    }

    function _mappedSourceRect() {
        const target = root.effectiveReferenceItem
        const reference = root.effectiveReferenceRect
        const p0 = root.sourceItem.mapToItem(target, 0, 0)
        const p1 = root.sourceItem.mapToItem(target,
            root.sourceItem.width, 0)
        const p2 = root.sourceItem.mapToItem(target,
            0, root.sourceItem.height)
        const p3 = root.sourceItem.mapToItem(target,
            root.sourceItem.width, root.sourceItem.height)
        const minX = Math.min(p0.x, p1.x, p2.x, p3.x) + reference.x
        const minY = Math.min(p0.y, p1.y, p2.y, p3.y) + reference.y
        const maxX = Math.max(p0.x, p1.x, p2.x, p3.x) + reference.x
        const maxY = Math.max(p0.y, p1.y, p2.y, p3.y) + reference.y
        return Qt.rect(minX, minY,
            Math.max(0, maxX - minX), Math.max(0, maxY - minY))
    }

    function publish() {
        const output = String(root.outputName ?? "")
        const instance = String(root.instanceId ?? "")
        const module = String(root.moduleId ?? "")
        const surface = root._surfaceKeyName()

        if (!root._identityMatches(output, instance, surface))
            root._unregisterPublished()

        if (!root.sourceItem || !root.sourceItem.visible
                || root.sourceItem.width <= 0 || root.sourceItem.height <= 0
                || !root.referenceReady
                || !output || !instance || !module
                || !PerimeterTopology.isValidSlot(root.slotId)) {
            root._unregisterPublished()
            return false
        }

        const rect = root._mappedSourceRect()
        if (rect.width <= 0 || rect.height <= 0) {
            root._unregisterPublished()
            return false
        }

        const publisherGeneration = root._ensurePublisherGeneration()
        const published = AnchorRegistry.publish({
            outputName: output,
            slotId: root.slotId,
            instanceId: instance,
            moduleId: module,
            rect: rect,
            surfaceName: surface,
            preferredExtent: root.preferredExtent,
            coordinateSpace: root.coordinateSpace,
            publisherGeneration: publisherGeneration
        })

        if (!published) {
            root._unregisterPublished()
            return false
        }

        root._publishedOutputName = output
        root._publishedInstanceId = instance
        root._publishedSurfaceName = surface
        return true
    }

    onRefreshTokenChanged: publish()
    onContextLayoutRevisionChanged: publish()
    onSourceItemChanged: publish()
    onOutputNameChanged: publish()
    onSlotIdChanged: publish()
    onInstanceIdChanged: publish()
    onModuleIdChanged: publish()
    onSurfaceNameChanged: publish()
    onPreferredExtentChanged: publish()
    onReferenceItemChanged: publish()
    onReferenceRectChanged: publish()
    onEffectiveReferenceItemChanged: publish()
    onEffectiveReferenceRectChanged: publish()

    Component.onCompleted: Qt.callLater(root.publish)
    Component.onDestruction: root._unregisterPublished()

    Connections {
        target: root.sourceItem
        function onXChanged() { root.publish() }
        function onYChanged() { root.publish() }
        function onWidthChanged() { root.publish() }
        function onHeightChanged() { root.publish() }
        function onVisibleChanged() { root.publish() }
        // mapToItem() changes under direct transforms and reparenting even when
        // the source item's local position and size stay unchanged.
        function onRotationChanged() { root.publish() }
        function onScaleChanged() { root.publish() }
        function onTransformOriginChanged() { root.publish() }
        function onParentChanged() { root.publish() }
    }
}
