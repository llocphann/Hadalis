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
    width: 0
    height: 0
    visible: false

    function publish() {
        if (!sourceItem || !sourceItem.visible || !PerimeterTopology.isValidSlot(slotId)) {
            AnchorRegistry.unregister(outputName, instanceId, surfaceName)
            return
        }
        const a = sourceItem.mapToItem(null, 0, 0)
        const b = sourceItem.mapToItem(null, sourceItem.width, sourceItem.height)
        AnchorRegistry.publish({ outputName: outputName, slotId: slotId, instanceId: instanceId, moduleId: moduleId,
            rect: Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(b.x - a.x), Math.abs(b.y - a.y)),
            surfaceName: surfaceName, preferredExtent: preferredExtent, coordinateSpace: coordinateSpace })
    }
    onRefreshTokenChanged: publish()
    onSlotIdChanged: publish()
    onPreferredExtentChanged: publish()
    Component.onCompleted: Qt.callLater(root.publish)
    Component.onDestruction: AnchorRegistry.unregister(outputName, instanceId, surfaceName)
    Connections {
        target: root.sourceItem
        function onXChanged() { root.publish() }
        function onYChanged() { root.publish() }
        function onWidthChanged() { root.publish() }
        function onHeightChanged() { root.publish() }
        function onVisibleChanged() { root.publish() }
    }
}
