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
    property string coordinateSpace: "output-local"
    property int refreshToken: 0

    // Optional coordinate bridge. When referenceItem is supplied, source geometry
    // is mapped into that item's local space and then translated by referenceRect.
    // Agent B can set referenceItem to the module/slot root and referenceRect to
    // perimeterContext.slotRect to obtain true output-local anchors even when the
    // source lives in a panel window whose local origin is not output (0, 0).
    property Item referenceItem: null
    property rect referenceRect: Qt.rect(0, 0, 0, 0)

    property string _publishedOutputName: ""
    property string _publishedInstanceId: ""
    property string _publishedSurfaceName: ""

    width: 0
    height: 0
    visible: false

    function _surfaceKeyName() {
        return String(root.surfaceName || "default")
    }

    function _unregisterPublished() {
        if (root._publishedOutputName && root._publishedInstanceId) {
            AnchorRegistry.unregister(root._publishedOutputName,
                root._publishedInstanceId, root._publishedSurfaceName)
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
        const target = root.referenceItem
        const p0 = root.sourceItem.mapToItem(target, 0, 0)
        const p1 = root.sourceItem.mapToItem(target, root.sourceItem.width, 0)
        const p2 = root.sourceItem.mapToItem(target, 0, root.sourceItem.height)
        const p3 = root.sourceItem.mapToItem(target,
            root.sourceItem.width, root.sourceItem.height)
        const offsetX = target ? root.referenceRect.x : 0
        const offsetY = target ? root.referenceRect.y : 0
        const minX = Math.min(p0.x, p1.x, p2.x, p3.x) + offsetX
        const minY = Math.min(p0.y, p1.y, p2.y, p3.y) + offsetY
        const maxX = Math.max(p0.x, p1.x, p2.x, p3.x) + offsetX
        const maxY = Math.max(p0.y, p1.y, p2.y, p3.y) + offsetY
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

        const published = AnchorRegistry.publish({
            outputName: output,
            slotId: root.slotId,
            instanceId: instance,
            moduleId: module,
            rect: rect,
            surfaceName: surface,
            preferredExtent: root.preferredExtent,
            coordinateSpace: root.coordinateSpace
        })

        if (published) {
            root._publishedOutputName = output
            root._publishedInstanceId = instance
            root._publishedSurfaceName = surface
        }
        return published
    }

    onRefreshTokenChanged: publish()
    onSourceItemChanged: publish()
    onOutputNameChanged: publish()
    onSlotIdChanged: publish()
    onInstanceIdChanged: publish()
    onModuleIdChanged: publish()
    onSurfaceNameChanged: publish()
    onPreferredExtentChanged: publish()
    onCoordinateSpaceChanged: publish()
    onReferenceItemChanged: publish()
    onReferenceRectChanged: publish()

    Component.onCompleted: Qt.callLater(root.publish)
    Component.onDestruction: root._unregisterPublished()

    Connections {
        target: root.sourceItem
        function onXChanged() { root.publish() }
        function onYChanged() { root.publish() }
        function onWidthChanged() { root.publish() }
        function onHeightChanged() { root.publish() }
        function onVisibleChanged() { root.publish() }
    }
}
