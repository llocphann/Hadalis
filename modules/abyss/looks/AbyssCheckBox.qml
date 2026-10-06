import QtQuick
import QtQuick.Controls
import qs.modules.common

CheckBox {
    id: root
    readonly property color labelInk: Appearance.m3colors.darkmode
        ? AbyssStyle.textColor : "#000000"
    hoverEnabled: true
    implicitHeight: 36
    spacing: 8
    padding: 4
    opacity: enabled ? 1 : .4
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    indicator: Rectangle {
        x: root.leftPadding; y: (root.height-height)/2
        width: 18; height: 18; radius: 6
        color: root.checked ? AbyssStyle.accent : Qt.alpha(AbyssStyle.accent,root.hovered ? .16 : .06)
        border.width: 1; border.color: Qt.alpha(AbyssStyle.accent,.5)
        Text {
            anchors.centerIn: parent
            text: "✓"; visible: root.checked
            color: AbyssStyle.surfaceDeep
            font.pixelSize: 14; font.bold: true
        }
    }
    contentItem: Text {
        text: root.text; font: root.font; color: root.labelInk
        leftPadding: root.indicator.width+root.spacing
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: height/2
        color: "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: AbyssStyle.accent
    }
}
