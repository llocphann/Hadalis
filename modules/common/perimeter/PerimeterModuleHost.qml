import QtQuick
import qs.modules.common

Item {
    id: root

    required property string outputName
    required property string instanceId
    required property string slotId
    property rect slotRect: Qt.rect(0, 0, width, height)
    property Item slotItem: null
    property bool hostEnabled: true

    readonly property var instanceDescriptor: PerimeterConfig.instanceDescriptor(outputName, instanceId)
    readonly property string moduleId: String(instanceDescriptor?.moduleId ?? "")
    readonly property var registration: ModuleRegistry.resolve(moduleId)
    readonly property string edge: PerimeterTopology.edgeForSlot(slotId)
    readonly property string alignment: PerimeterTopology.alignmentForSlot(slotId)
    readonly property string orientation: PerimeterTopology.orientationForEdge(edge)
    readonly property string inwardDirection: PerimeterTopology.inwardDirectionForEdge(edge)
    readonly property bool resolvable: instanceDescriptor !== null
        && ModuleRegistry.isResolvable(moduleId)
    readonly property Item loadedItem: moduleLoader.item
    readonly property int configRevision: Config.revision
    property var perimeterContext: context

    implicitWidth: moduleLoader.item?.implicitWidth ?? 0
    implicitHeight: moduleLoader.item?.implicitHeight ?? 0
    visible: hostEnabled && resolvable
    enabled: visible

    function _syncLoadedItem() {
        const item = moduleLoader.item
        if (!item)
            return
        // Feature modules consume this generic contract. Properties remain
        // optional during migration so legacy components can be adapted
        // incrementally instead of requiring a big-bang rewrite.
        if (item.perimeterContext !== undefined)
            item.perimeterContext = context
        if (item.instanceConfig !== undefined)
            item.instanceConfig = root.instanceDescriptor?.config ?? ({})
    }

    onInstanceDescriptorChanged: root._syncLoadedItem()
    onConfigRevisionChanged: root._syncLoadedItem()

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
        slotItem: root.slotItem
    }

    Loader {
        id: moduleLoader
        anchors.fill: parent
        active: root.hostEnabled && root.resolvable
        source: active ? String(root.registration?.source ?? "") : ""

        onLoaded: root._syncLoadedItem()
    }
}
