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
    readonly property int configRevision: Config.revision
    readonly property string configuredSlotId:
        PerimeterConfig.placementForInstance(outputName, instanceId)
    readonly property bool placementValid: configRevision >= 0
        && PerimeterConfig.validate(outputName)
        && configuredSlotId === slotId
    readonly property bool resolvable: placementValid
        && instanceDescriptor !== null
        && ModuleRegistry.isResolvable(moduleId)
    readonly property Item loadedItem: moduleLoader.item
    readonly property bool contentVisible:
        moduleLoader.item !== null && moduleLoader.item.visible
    property int anchorLayoutRevision: 0
    property var perimeterContext: context

    implicitWidth: moduleLoader.item?.implicitWidth ?? 0
    implicitHeight: moduleLoader.item?.implicitHeight ?? 0
    // Keep loading independent from wrapper visibility: feature content must be
    // able to initialize before it can report whether it is currently presented.
    // Once loaded, mirror its visibility so zero/collapsed modules do not remain
    // visible Row/Column children and leave phantom spacing or mask geometry.
    visible: hostEnabled && resolvable && contentVisible
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

    function _bumpAnchorLayoutRevision() {
        root.anchorLayoutRevision = (root.anchorLayoutRevision + 1) % 2147483647
    }

    onInstanceDescriptorChanged: root._syncLoadedItem()
    onConfigRevisionChanged: root._syncLoadedItem()
    onXChanged: root._bumpAnchorLayoutRevision()
    onYChanged: root._bumpAnchorLayoutRevision()
    onWidthChanged: root._bumpAnchorLayoutRevision()
    onHeightChanged: root._bumpAnchorLayoutRevision()

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
        layoutRevision: root.anchorLayoutRevision
    }

    Loader {
        id: moduleLoader
        anchors.fill: parent
        active: root.hostEnabled && root.resolvable
        source: active ? String(root.registration?.source ?? "") : ""

        onLoaded: root._syncLoadedItem()
    }
}
