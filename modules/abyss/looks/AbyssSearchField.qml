import QtQuick
import QtQuick.Controls

TextField {
    id: root
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    color: AbyssStyle.textColor
    placeholderTextColor: AbyssStyle.textColorMuted
    selectByMouse: true
    selectionColor: AbyssStyle.accent
    selectedTextColor: AbyssStyle.surfaceDeep
    implicitHeight: 40
    leftPadding: 0; rightPadding: 0
    background: Item {
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.activeFocus ? AbyssStyle.accent : AbyssStyle.textColorMuted; opacity: 0.5 }
    }
}
