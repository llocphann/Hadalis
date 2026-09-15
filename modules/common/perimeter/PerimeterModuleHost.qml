import QtQuick

Item {
    id: root

    required property string outputName
    required property string instanceId
    required property string slotId
    property rect slotRect: Qt.rect(0, 0, width, height)
    property bool hostEnabled: true

    readonly property var instanceDescriptor: PerimeterConfig.instanceDescriptor(outputName, instanceId)
    readonly property string moduleId: String(instanceDescriptor?.moduleId ?? "")
    readonly property var registration: ModuleRegistry.resolve(moduleId)
    readonly property string edge: PerimeterTopology.edgeForSlot(slotId)
    readonly property string alignment: PerimeterTopology.alignmentForSlot(slotId)
    readonly property string orientation: PerimeterTopology.orientationForEdge(edge)
    readonly property string inwardDirection: PerimeterTopology.inwardDirectionForEdge(edge)
    readonly property bool resolvable: instanceDescriptor !== null
        && registration !== null
        && String(registration?.source ?? "").length > 0
    readonly property Item loadedItem: moduleLoader.item
    property var perimeterContext: context

    implicitWidth: moduleLoader.item?.implicitWidth ?? 0
    implicitHeight: moduleLoader.item?.implicitHeight ?? 0
    visible: hostEnabled && resolvable
    enabled: visible

    PerimeterContext {
        id: context
        outputName: root.outputName
        instanceId: root.instanceId
        moduleId: root.moduleId
        slotId: root.slotId
        edge: root.edge
        alignment: root.alignment
        orientation: root.orientation
        inwardDirection: root.inwardDirection
        slotRect: root.slotRect
    }

    Loader {
        id: moduleLoader
        anchors.fill: parent
        active: root.hostEnabled && root.resolvable
        source: active ? String(root.registration?.source ?? "") : ""

        onLoaded: {
            // Feature modules consume this generic contract. Properties remain
            // optional during migration so legacy components can be adapted
            // incrementally by Agent B instead of requiring a big-bang rewrite.
            if (item && item.perimeterContext !== undefined)
                item.perimeterContext = context
            if (item && item.instanceConfig !== undefined)
                item.instanceConfig = root.instanceDescriptor?.config ?? ({})
        }
    }
}
