import QtQuick

QtObject {
    id: root

    property string outputName: ""
    property string slotId: "top.center"
    property rect slotRect: Qt.rect(0, 0, 0, 0)

    readonly property string edge: PerimeterTopology.edgeForSlot(slotId)
    readonly property string alignment: PerimeterTopology.alignmentForSlot(slotId)
    readonly property string orientation: PerimeterTopology.orientationForEdge(edge)
    readonly property string inwardDirection: PerimeterTopology.inwardDirectionForEdge(edge)
    readonly property var instanceIds: PerimeterConfig.slotInstanceIds(outputName, slotId)
    readonly property int count: instanceIds.length
    readonly property bool empty: count === 0

    function instanceAt(index) {
        if (index < 0 || index >= root.instanceIds.length)
            return null
        const instanceId = root.instanceIds[index]
        const descriptor = PerimeterConfig.instanceDescriptor(root.outputName, instanceId)
        if (!descriptor)
            return null
        return {
            instanceId: instanceId,
            moduleId: String(descriptor.moduleId ?? ""),
            config: descriptor.config ?? ({}),
            outputName: root.outputName,
            slotId: root.slotId,
            edge: root.edge,
            alignment: root.alignment,
            orientation: root.orientation,
            inwardDirection: root.inwardDirection,
            slotRect: root.slotRect
        }
    }
}
