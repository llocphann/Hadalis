import QtQuick

QtObject {
    property string outputName: ""
    property string instanceId: ""
    property string moduleId: ""
    property string slotId: ""
    property string edge: ""
    property string alignment: ""
    property string orientation: ""
    property string inwardDirection: ""
    property rect slotRect: Qt.rect(0, 0, 0, 0)

    readonly property bool valid: outputName.length > 0
        && instanceId.length > 0
        && moduleId.length > 0
        && PerimeterTopology.isValidSlot(slotId)
        && edge === PerimeterTopology.edgeForSlot(slotId)
        && alignment === PerimeterTopology.alignmentForSlot(slotId)
        && orientation === PerimeterTopology.orientationForEdge(edge)
        && inwardDirection === PerimeterTopology.inwardDirectionForEdge(edge)
}
