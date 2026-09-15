import QtQuick

Item {
    id: root

    required property string outputName
    required property string slotId

    property bool hostEnabled: true
    property real spacing: 8
    // Output-local geometry. PerimeterOutputHost places slot hosts directly in
    // its output-local coordinate space; standalone consumers may override this.
    property rect slotRect: Qt.rect(x, y, width, height)

    readonly property string edge: PerimeterTopology.edgeForSlot(slotId)
    readonly property string alignment: PerimeterTopology.alignmentForSlot(slotId)
    readonly property string orientation: PerimeterTopology.orientationForEdge(edge)
    readonly property var instanceIds: slotModel.instanceIds
    readonly property int count: slotModel.count
    readonly property bool empty: slotModel.empty
    readonly property bool configValid: PerimeterConfig.validate(outputName)

    implicitWidth: positionerLoader.item?.implicitWidth ?? 0
    implicitHeight: positionerLoader.item?.implicitHeight ?? 0
    visible: hostEnabled && configValid && !empty
    enabled: visible

    PerimeterSlotModel {
        id: slotModel
        outputName: root.outputName
        slotId: root.slotId
        slotRect: root.slotRect
    }

    Loader {
        id: positionerLoader
        active: root.hostEnabled && root.configValid && !root.empty
        sourceComponent: root.orientation === "vertical"
            ? verticalPositioner : horizontalPositioner
        width: item?.implicitWidth ?? 0
        height: item?.implicitHeight ?? 0
    }

    Component {
        id: horizontalPositioner

        Row {
            spacing: root.spacing

            Repeater {
                model: root.instanceIds

                delegate: PerimeterModuleHost {
                    outputName: root.outputName
                    instanceId: String(modelData ?? "")
                    slotId: root.slotId
                    slotRect: root.slotRect
                    slotItem: root
                    hostEnabled: root.hostEnabled && root.configValid
                    width: implicitWidth
                    height: implicitHeight
                }
            }
        }
    }

    Component {
        id: verticalPositioner

        Column {
            spacing: root.spacing

            Repeater {
                model: root.instanceIds

                delegate: PerimeterModuleHost {
                    outputName: root.outputName
                    instanceId: String(modelData ?? "")
                    slotId: root.slotId
                    slotRect: root.slotRect
                    slotItem: root
                    hostEnabled: root.hostEnabled && root.configValid
                    width: implicitWidth
                    height: implicitHeight
                }
            }
        }
    }
}
