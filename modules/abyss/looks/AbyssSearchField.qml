import QtQuick
import QtQuick.Controls
import qs.modules.common

TextField {
    id: root
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    readonly property color fieldInk: Appearance.m3colors.darkmode
        ? AbyssStyle.textColor : "#000000"
    readonly property color fieldMutedInk: Appearance.m3colors.darkmode
        ? AbyssStyle.textColorMuted : "#1a1a1a"
    color: fieldInk
    placeholderTextColor: fieldMutedInk
    selectByMouse: true
    selectionColor: AbyssStyle.accent
    selectedTextColor: AbyssStyle.surfaceDeep
    implicitHeight: 40
    leftPadding: 0; rightPadding: 0
    background: Item {
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.activeFocus ? AbyssStyle.accent : root.fieldMutedInk; opacity: 0.5 }
    }
}
