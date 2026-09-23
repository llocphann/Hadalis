import qs.modules.common
import QtQuick

Rectangle {
    id: root

    property bool focusVisible: false

    color: "transparent"
    radius: Appearance.rounding.small
    border.width: root.focusVisible ? 1 : 0
    border.color: Appearance.colors.colPrimary
    visible: root.focusVisible
    z: 2
}
