import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.abyss.looks

Rectangle {
    id: root

    required property var canvasController
    readonly property bool editing: root.canvasController?.editMode ?? false
    readonly property var hiddenIds: root.canvasController?.hiddenIds ?? []
    readonly property bool abyssMode:
        (Config.options?.panelFamily ?? "abyss") === "abyss"

    readonly property real horizontalPadding: root.abyssMode
        ? Math.max(10, AbyssStyle.contentPadding * 0.55) : 7
    readonly property real sectionGap: 8
    readonly property real availableModulesNaturalWidth:
        root.hiddenIds.length > 0 ? availableModulesRow.implicitWidth : 0
    readonly property real toolbarRowNaturalWidth:
        editActions.implicitWidth
        + (root.hiddenIds.length > 0
            ? root.sectionGap + root.availableModulesNaturalWidth : 0)
    implicitWidth: Math.ceil(Math.max(
        toolbarTitle.implicitWidth,
        root.toolbarRowNaturalWidth)
        + root.horizontalPadding * 2)
    implicitHeight: toolbarColumn.implicitHeight + root.horizontalPadding * 2
    visible: root.editing
    radius: Appearance.rounding.large
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: root.abyssMode ? radius : 0
    bottomRightRadius: root.abyssMode ? radius : 0
    color: root.abyssMode
        ? Qt.alpha(AbyssStyle.surfaceDeep,
            Math.max(0.72, AbyssStyle.contentOpacity))
        : Appearance.colors.colLayer0
    border.width: root.abyssMode ? 1 : 0
    border.color: root.abyssMode
        ? Qt.alpha(AbyssStyle.accent, 0.22) : "transparent"
    clip: true

    ColumnLayout {
        id: toolbarColumn
        anchors.fill: parent
        anchors.margins: root.horizontalPadding
        spacing: 5

        StyledText {
            id: toolbarTitle
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.canvasController?.layoutMessage
                || ((root.canvasController?.workspace?.overflow?.length ?? 0) > 0
                    ? Translation.tr("%1 modules need more space").arg(root.canvasController.workspace.overflow.length)
                    : root.canvasController?.selectedId?.length > 0
                        ? Translation.tr("Editing %1").arg(root.canvasController._label(root.canvasController.selectedId))
                        : Translation.tr("Edit widgets"))
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: root.abyssMode
                ? AbyssStyle.textColor : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }

        RowLayout {
            id: toolbarRow
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: root.sectionGap

            RowLayout {
                id: editActions
                Layout.fillWidth: false
                spacing: 6

                EditToolButton {
                    iconName: root.canvasController?.snapEnabled
                        ? "grid_on" : "grid_off"
                    tooltipText: root.canvasController?.snapEnabled
                        ? Translation.tr("Snap to grid: on")
                        : Translation.tr("Snap to grid: off")
                    toggled: root.canvasController?.snapEnabled ?? false
                    onClicked: {
                        if (root.canvasController)
                            root.canvasController.toggleSnap()
                    }
                }

                EditToolButton {
                    visible: !(root.canvasController?.responsiveWorkspace ?? false)
                    iconName: "fit_screen"
                    tooltipText: root.canvasController?.autoAdjustSizeEnabled
                        ? Translation.tr("Auto-adjust affected module sizes: on")
                        : Translation.tr("Auto-adjust affected module sizes: off")
                    toggled:
                        root.canvasController?.autoAdjustSizeEnabled ?? true
                    onClicked: {
                        if (root.canvasController)
                            root.canvasController.toggleAutoAdjustSize()
                    }
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

                EditToolButton {
                    visible: root.hiddenIds.length > 0
                    iconName: "auto_awesome_motion"
                    tooltipText: Translation.tr(
                        "Add all modules and fit them automatically")
                    onClicked: {
                        if (root.canvasController)
                            root.canvasController.fitAllWidgets()
                    }
                }
            }

            Flickable {
                id: availableModulesViewport
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: root.availableModulesNaturalWidth
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
                            colBackground: root.abyssMode
                                ? Qt.alpha(AbyssStyle.accent, 0.10)
                                : Appearance.colors.colLayer1
                            colBackgroundHover: root.abyssMode
                                ? Qt.alpha(AbyssStyle.accent, 0.18)
                                : Appearance.colors.colLayer2
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
                                    color: root.abyssMode
                                        ? AbyssStyle.textColor
                                        : Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    text: root.canvasController?._label(
                                        String(modelData)) ?? String(modelData)
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: root.abyssMode
                                        ? AbyssStyle.textColor
                                        : Appearance.colors.colOnLayer1
                                }
                                MaterialSymbol {
                                    text: "add"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: root.abyssMode
                                        ? AbyssStyle.accent
                                        : Appearance.colors.colPrimary
                                }
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
        colBackground: root.abyssMode
            ? Qt.alpha(AbyssStyle.accent, 0.10)
            : Appearance.colors.colLayer1
        colBackgroundHover: root.abyssMode
            ? Qt.alpha(AbyssStyle.accent, 0.18)
            : Appearance.colors.colLayer2
        colBackgroundToggled: root.abyssMode
            ? Qt.alpha(AbyssStyle.accent, 0.28)
            : Appearance.colors.colPrimaryContainer
        colBackgroundToggledHover: root.abyssMode
            ? Qt.alpha(AbyssStyle.accent, 0.34)
            : Appearance.colors.colPrimaryContainer
        colRippleToggled: root.abyssMode
            ? AbyssStyle.accent : Appearance.colors.colPrimary

        contentItem: Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Appearance.rounding.full
                color: "transparent"
                border.width: tool.visualFocus ? 2 : (tool.toggled ? 1 : 0)
                border.color: tool.visualFocus
                    ? (root.abyssMode
                        ? AbyssStyle.accent : Appearance.colors.colPrimary)
                    : ColorUtils.applyAlpha(
                        root.abyssMode
                            ? AbyssStyle.accent
                            : Appearance.colors.colPrimary, 0.72)
            }

            MaterialSymbol {
                id: toolIcon
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.normal
                color: root.abyssMode
                    ? (tool.toggled
                        ? AbyssStyle.accent : AbyssStyle.textColor)
                    : (tool.toggled
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnLayer1)
            }
        }

        StyledToolTip { text: tool.tooltipText }
    }
}
