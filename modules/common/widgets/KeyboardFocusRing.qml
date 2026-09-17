import qs
import QtQuick

Rectangle {
    id: root

    property bool focusVisible: false

    color: "transparent"
    radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small
    border.width: root.focusVisible ? 1 : 0
    border.color: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    visible: root.focusVisible
    z: 2
}
