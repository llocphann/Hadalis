import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    required property var canvasController
    readonly property bool editing: root.canvasController?.editMode ?? false
    readonly property var hiddenIds: root.canvasController?.hiddenIds ?? []

    readonly property real horizontalPadding: 7
    implicitWidth: Math.ceil(Math.max(
        editActions.implicitWidth,
        availableModulesRow.implicitWidth)
        + root.horizontalPadding * 2)
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
        anchors.margins: root.horizontalPadding
        spacing: 5

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
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

        RowLayout {
            id: editActions
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

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
                iconName: "fit_screen"
                tooltipText: root.canvasController?.autoAdjustSizeEnabled
                    ? Translation.tr("Auto-adjust affected module sizes: on")
                    : Translation.tr("Auto-adjust affected module sizes: off")
                toggled:
                    root.canvasController?.autoAdjustSizeEnabled ?? true
                onClicked: Config.setNestedValue(
                    "dashboard.canvas.autoAdjustSize",
                    !(root.canvasController?.autoAdjustSizeEnabled ?? true))
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

        Flickable {
            id: availableModulesViewport
            Layout.fillWidth: true
            Layout.preferredHeight: availableModulesRow.implicitHeight
            visible: root.hiddenIds.length > 0
            contentWidth: availableModulesRow.implicitWidth
            contentHeight: availableModulesRow.implicitHeight
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentWidth > width

            Row {
                id: availableModulesRow
                spacing: 5

                Repeater {
                    model: root.hiddenIds
                    delegate: RippleButton {
                        required property var modelData
                        implicitHeight: 28
                        implicitWidth: addRow.implicitWidth + 14
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer1
                        focusPolicy: Qt.StrongFocus
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
    }

    component EditToolButton: RippleButton {
        id: tool
        property alias iconName: toolIcon.text
        property string tooltipText: ""

        implicitWidth: 34
        implicitHeight: 34
        focusPolicy: Qt.StrongFocus
        buttonText: tool.tooltipText
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer1
        colBackgroundHover: Appearance.colors.colLayer2
        colBackgroundToggled: Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: Appearance.colors.colPrimaryContainer
        colRippleToggled: Appearance.colors.colPrimary

        contentItem: Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Appearance.rounding.full
                color: "transparent"
                border.width: tool.visualFocus ? 2 : (tool.toggled ? 1 : 0)
                border.color: tool.visualFocus
                    ? Appearance.colors.colPrimary
                    : ColorUtils.applyAlpha(
                        Appearance.colors.colPrimary, 0.72)
            }

            MaterialSymbol {
                id: toolIcon
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.normal
                color: tool.toggled
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer1
            }
        }

        StyledToolTip { text: tool.tooltipText }
    }
}
