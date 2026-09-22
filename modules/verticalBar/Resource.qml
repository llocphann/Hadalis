import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    required property string iconName
    required property double percentage
    property bool shown: true
    property int warningThreshold: 100
    implicitHeight: shown ? resourceProgress.implicitHeight : 0
    implicitWidth: Appearance.sizes.verticalBarWidth
    visible: shown

    property bool warning: percentage * 100 >= warningThreshold

    ClippedFilledCircularProgress {
        id: resourceProgress
        anchors.centerIn: parent
        implicitSize: Math.round(18 * Appearance.fontSizeScale * Appearance.sizes.barModuleScale)
        lineWidth: Math.max(1, Math.round(2 * Appearance.sizes.barModuleScale))
        value: percentage
        enableAnimation: false
        colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer0
        accountForLightBleeding: !root.warning

        MaterialSymbol {
            font.weight: Font.Medium
            fill: 1
            text: root.iconName
            iconSize: Math.round(13 * Appearance.fontSizeScale * Appearance.sizes.barModuleScale)
            color: Appearance.colors.colOnLayer0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root.visible
    }
}
