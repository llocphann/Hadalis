pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    readonly property var graph:
        CodeWorkflowIr.graphFor(CodeWorkflowSession.subflowTargetId)
    readonly property var nodes: root.graph?.nodes ?? []
    readonly property var edges: root.graph?.edges ?? []

    readonly property real nodeWidth: 190
    readonly property real nodeHeight: 88
    readonly property real worldWidth: 1050
    readonly property real worldHeight: 570

    function nodeById(nodeId: string): var {
        return root.nodes.find(node => node.id === nodeId) ?? null
    }

    function accentForKind(kind: string): color {
        if (kind === "service")
            return Appearance.colors.colSecondary
        if (kind === "event" || kind === "action")
            return Appearance.colors.colTertiary
        if (kind === "lifecycle")
            return Appearance.colors.colPrimary
        if (kind === "binding")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOnLayer1
    }

    function edgeColor(kind: string): color {
        if (kind === "event")
            return Appearance.colors.colTertiary
        if (kind === "action")
            return Appearance.colors.colSecondary
        if (kind === "data")
            return Appearance.colors.colPrimary
        return Appearance.colors.colOutlineVariant
    }

    DragHandler {
        id: pan
        target: null
        acceptedButtons: Qt.MiddleButton
        property real baseX: 0
        property real baseY: 0

        onActiveChanged: {
            if (active) {
                baseX = CodeWorkflowSession.panX
                baseY = CodeWorkflowSession.panY
            }
        }
        onActiveTranslationChanged: {
            if (active)
                CodeWorkflowSession.setViewport(
                    baseX + activeTranslation.x,
                    baseY + activeTranslation.y,
                    CodeWorkflowSession.zoom)
        }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const oldZoom = CodeWorkflowSession.zoom
            const delta = event.pixelDelta.y !== 0
                ? event.pixelDelta.y * 3
                : event.angleDelta.y
            const nextZoom = Math.max(0.35, Math.min(2.5,
                oldZoom * Math.pow(1.0015, delta)))
            const graphX = (event.x - CodeWorkflowSession.panX) / oldZoom
            const graphY = (event.y - CodeWorkflowSession.panY) / oldZoom
            CodeWorkflowSession.setViewport(
                event.x - graphX * nextZoom,
                event.y - graphY * nextZoom,
                nextZoom)
            event.accepted = true
        }
    }

    PinchHandler {
        id: pinch
        target: null
        property real baseZoom: 1
        property point pivot: Qt.point(0, 0)

        onActiveChanged: {
            if (active) {
                baseZoom = CodeWorkflowSession.zoom
                pivot = Qt.point(
                    (centroid.position.x - CodeWorkflowSession.panX)
                        / CodeWorkflowSession.zoom,
                    (centroid.position.y - CodeWorkflowSession.panY)
                        / CodeWorkflowSession.zoom)
            }
        }

        function updateViewport(): void {
            if (!active)
                return
            const nextZoom = Math.max(0.35,
                Math.min(2.5, baseZoom * activeScale))
            CodeWorkflowSession.setViewport(
                centroid.position.x - pivot.x * nextZoom,
                centroid.position.y - pivot.y * nextZoom,
                nextZoom)
        }

        onActiveScaleChanged: updateViewport()
        onActiveTranslationChanged: updateViewport()
    }

    Item {
        id: world
        width: root.worldWidth
        height: root.worldHeight
        x: CodeWorkflowSession.panX
        y: CodeWorkflowSession.panY
        scale: CodeWorkflowSession.zoom
        transformOrigin: Item.TopLeft

        Repeater {
            model: root.edges

            delegate: Shape {
                id: edgeShape
                required property var modelData

                readonly property var fromNode: root.nodeById(modelData.from)
                readonly property var toNode: root.nodeById(modelData.to)
                readonly property bool highlighted:
                    CodeWorkflowSession.selectedNodeId === modelData.from
                    || CodeWorkflowSession.selectedNodeId === modelData.to

                anchors.fill: parent
                preferredRendererType: Shape.GeometryRenderer
                asynchronous: false
                z: 0

                ShapePath {
                    readonly property real startNodeX:
                        edgeShape.fromNode?.x ?? 0
                    readonly property real startNodeY:
                        edgeShape.fromNode?.y ?? 0
                    readonly property real endNodeX:
                        edgeShape.toNode?.x ?? 0
                    readonly property real endNodeY:
                        edgeShape.toNode?.y ?? 0
                    readonly property real bend:
                        Math.max(48,
                            Math.abs(endNodeX - startNodeX) / 2)

                    strokeColor: edgeShape.highlighted
                        ? root.edgeColor(edgeShape.modelData.kind)
                        : ColorUtils.transparentize(
                            root.edgeColor(edgeShape.modelData.kind), 0.28)
                    strokeWidth: edgeShape.highlighted ? 2.6 : 1.6
                    fillColor: "transparent"
                    startX: startNodeX + root.nodeWidth
                    startY: startNodeY + root.nodeHeight / 2

                    PathCubic {
                        x: parent.endNodeX
                        y: parent.endNodeY + root.nodeHeight / 2
                        control1X: parent.startNodeX
                            + root.nodeWidth + parent.bend
                        control1Y: parent.startNodeY
                            + root.nodeHeight / 2
                        control2X: parent.endNodeX - parent.bend
                        control2Y: parent.endNodeY
                            + root.nodeHeight / 2
                    }
                }
            }
        }

        Repeater {
            model: root.nodes

            delegate: Rectangle {
                id: node
                required property var modelData

                readonly property bool selected:
                    CodeWorkflowSession.selectedNodeId === modelData.id
                readonly property color accent:
                    root.accentForKind(modelData.kind)

                x: Number(modelData.x ?? 0)
                y: Number(modelData.y ?? 0)
                width: root.nodeWidth
                height: root.nodeHeight
                radius: Appearance.rounding.normal
                color: selected
                    ? ColorUtils.transparentize(accent, 0.78)
                    : Appearance.colors.colLayer1
                border.width: selected ? 2 : 1
                border.color: selected
                    ? accent
                    : Appearance.colors.colOutlineVariant
                z: 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                    + " · " + modelData.kind
                Accessible.description:
                    modelData.description ?? "Read-only workflow node"

                TapHandler {
                    onTapped: {
                        CodeWorkflowSession.selectNode(node.modelData.id)
                        node.forceActiveFocus()
                    }
                }

                Keys.onPressed: event => {
                    if (event.key !== Qt.Key_Return
                            && event.key !== Qt.Key_Enter
                            && event.key !== Qt.Key_Space) {
                        event.accepted = false
                        return
                    }

                    if ((node.modelData.subflowTargetId ?? "").length > 0
                            && node.modelData.subflowTargetId
                                !== CodeWorkflowSession.subflowTargetId)
                        CodeWorkflowSession.openSubflow(
                            node.modelData.subflowTargetId)
                    else
                        CodeWorkflowSession.selectNode(node.modelData.id)
                    event.accepted = true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            implicitWidth: kindLabel.implicitWidth + 10
                            implicitHeight: kindLabel.implicitHeight + 4
                            radius: implicitHeight / 2
                            color: ColorUtils.transparentize(node.accent, 0.82)

                            StyledText {
                                id: kindLabel
                                anchors.centerIn: parent
                                text: String(node.modelData.kind ?? "node").toUpperCase()
                                color: node.accent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: node.modelData.title ?? node.modelData.id
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible:
                                (node.modelData.subflowTargetId ?? "").length > 0
                                && node.modelData.subflowTargetId
                                    !== CodeWorkflowSession.subflowTargetId
                            implicitWidth: 25
                            implicitHeight: 25
                            radius: implicitHeight / 2
                            color: Appearance.colors.colLayer2

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_outward"
                                iconSize: Appearance.font.pixelSize.small
                                color: node.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true
                                    CodeWorkflowSession.openSubflow(
                                        node.modelData.subflowTargetId)
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: node.modelData.description ?? ""
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: node.modelData.sourceNeedle ?? ""
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    x: -4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.accent
                }

                Rectangle {
                    x: parent.width - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: node.accent
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        implicitWidth: hint.implicitWidth + 16
        implicitHeight: hint.implicitHeight + 8
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        StyledText {
            id: hint
            anchors.centerIn: parent
            text: (root.graph?.title ?? "Workflow")
                + " · " + root.nodes.length + " nodes · "
                + Math.round(CodeWorkflowSession.zoom * 100) + "%"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
        }
    }
}
