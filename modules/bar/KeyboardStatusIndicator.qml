import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Niri-backed keyboard state for Bar/VerticalBar status surfaces.
// The old HyprlandXkbIndicator type was retired with Hyprland support; this
// renderer consumes the compositor-neutral KeyboardIndicators service.
Loader {
    id: root
    property bool vertical: false
    property color color: Appearance.colors.colOnSurfaceVariant

    active: KeyboardIndicators.hasPanelIndicators
    visible: active
    Layout.preferredWidth: active && item ? item.implicitWidth : 0
    Layout.preferredHeight: active && item ? item.implicitHeight : 0

    sourceComponent: Item {
        implicitWidth: root.vertical
            ? indicatorColumn.implicitWidth : indicatorRow.implicitWidth
        implicitHeight: root.vertical
            ? indicatorColumn.implicitHeight : indicatorRow.implicitHeight

        Row {
            id: indicatorRow
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: Appearance.sizes.spacingSmall
                * Appearance.sizes.barModuleScale

            MaterialSymbol {
                visible: KeyboardIndicators.capsLockVisible
                text: KeyboardIndicators.capsMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            MaterialSymbol {
                visible: KeyboardIndicators.touchpadVisible
                text: KeyboardIndicators.touchpadMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            MaterialSymbol {
                visible: KeyboardIndicators.numLockVisible
                text: KeyboardIndicators.numMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            StyledText {
                visible: KeyboardIndicators.layoutVisible
                horizontalAlignment: Text.AlignHCenter
                text: KeyboardIndicators.currentLayoutCodeInline
                font.pixelSize: Math.round(Appearance.font.pixelSize.small
                    * Appearance.sizes.barModuleScale)
                color: root.color
            }
        }

        Column {
            id: indicatorColumn
            visible: root.vertical
            anchors.centerIn: parent
            spacing: Appearance.sizes.spacingSmall
                * Appearance.sizes.barModuleScale / 2

            MaterialSymbol {
                visible: KeyboardIndicators.capsLockVisible
                anchors.horizontalCenter: parent.horizontalCenter
                text: KeyboardIndicators.capsMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            MaterialSymbol {
                visible: KeyboardIndicators.touchpadVisible
                anchors.horizontalCenter: parent.horizontalCenter
                text: KeyboardIndicators.touchpadMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            MaterialSymbol {
                visible: KeyboardIndicators.numLockVisible
                anchors.horizontalCenter: parent.horizontalCenter
                text: KeyboardIndicators.numMaterialIcon
                iconSize: Math.round(Appearance.font.pixelSize.large
                    * Appearance.sizes.barModuleScale)
                fill: 1
                color: root.color
            }
            StyledText {
                visible: KeyboardIndicators.layoutVisible
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: KeyboardIndicators.currentLayoutCodeMultiline
                font.pixelSize: text.includes("\n")
                    ? Appearance.font.pixelSize.smallie
                    : Appearance.font.pixelSize.small
                color: root.color
            }
        }
    }
}
