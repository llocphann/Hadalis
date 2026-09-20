import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var canvasController
    readonly property bool editing: root.canvasController?.editMode ?? false
    readonly property var hiddenIds: root.canvasController?.hiddenIds ?? []

    implicitWidth: 440
    implicitHeight: toolbarColumn.implicitHeight + 14
    visible: root.editing
    radius: Appearance.rounding.large
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: 0
    bottomRightRadius: 0
    color: Appearance.colors.colLayer0
    border.width: 0
    border.color: "transparent"
    clip: true

    ColumnLayout {
        id: toolbarColumn
        anchors.fill: parent
        anchors.margins: 7
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            StyledText {
                Layout.fillWidth: true
                text: root.canvasController?.selectedId?.length > 0
                    ? Translation.tr("Editing %1").arg(
                        root.canvasController._label(
                            root.canvasController.selectedId))
                    : Translation.tr("Edit widgets")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }

            EditToolButton {
                iconName: root.canvasController?.snapEnabled
                    ? "grid_on" : "grid_off"
                tooltipText: root.canvasController?.snapEnabled
                    ? Translation.tr("Snap to grid: on")
                    : Translation.tr("Snap to grid: off")
                toggled: root.canvasController?.snapEnabled ?? false
                onClicked: Config.setNestedValue(
                    "dashboard.canvas.snap",
                    !(root.canvasController?.snapEnabled ?? true))
            }
            EditToolButton {
                iconName: root.canvasController?.gridStyle === "lines"
                    ? "grid_4x4"
                    : (root.canvasController?.gridStyle === "cross"
                        ? "add" : "drag_indicator")
                tooltipText: Translation.tr("Grid style: %1 — click to cycle")
                    .arg(root.canvasController?.gridStyle ?? "dots")
                onClicked: {
                    if (root.canvasController)
                        root.canvasController._cycleGridStyle()
                }
            }
            EditToolButton {
                iconName: "grid_view"
                tooltipText: Translation.tr("Grid size: %1px — click to cycle")
                    .arg(root.canvasController?.gridSize ?? 24)
                onClicked: {
                    if (root.canvasController)
                        root.canvasController._cycleGridSize()
                }
            }
            EditToolButton {
                iconName: "restart_alt"
                tooltipText: Translation.tr("Reset dashboard layout")
                onClicked: {
                    if (root.canvasController)
                        root.canvasController.resetLayout()
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: root.hiddenIds.length > 0
            spacing: 5

            Repeater {
                model: root.hiddenIds
                delegate: RippleButton {
                    required property var modelData
                    implicitHeight: 28
                    implicitWidth: addRow.implicitWidth + 14
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer1
                    onClicked: {
                        if (root.canvasController)
                            root.canvasController.setWidgetVisible(
                                String(modelData), true)
                    }

                    RowLayout {
                        id: addRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: root.canvasController?._icon(
                                String(modelData)) ?? "widgets"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: root.canvasController?._label(
                                String(modelData)) ?? String(modelData)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer1
                        }
                        MaterialSymbol {
                            text: "add"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    component EditToolButton: RippleButton {
        id: tool
        property alias iconName: toolIcon.text
        property string tooltipText: ""
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        colBackground: toggled
            ? Appearance.colors.colPrimaryContainer
            : Appearance.colors.colLayer1
        contentItem: MaterialSymbol {
            id: toolIcon
            anchors.centerIn: parent
            iconSize: Appearance.font.pixelSize.normal
            color: tool.toggled
                ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnLayer1
        }
        StyledToolTip { text: tool.tooltipText }
    }
}
