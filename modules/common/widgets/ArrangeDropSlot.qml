pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * Insertion target for pick-and-place arrangement editors. Invisible
 * until something is lifted; then it renders as a pulsing accent slot
 * that accepts a tap. Two shapes: compact tile (between chips in a
 * Flow) and full-width bar (between group cards).
 */
Rectangle {
    id: root

    property bool active: false      // something is lifted somewhere
    property bool compact: true      // tile between chips; false = wide bar
    property string accessibleName: Translation.tr("Place here")
    signal placed()

    visible: active
    implicitWidth: compact ? 34 : 120
    implicitHeight: compact ? 34 : (slotHover.hovered ? 22 : 12)
    radius: compact ? height / 2 : 6
    color: slotHover.hovered ? Appearance.colors.colPrimaryContainer
         : ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus
        ? Appearance.colors.colPrimary
        : ColorUtils.applyAlpha(Appearance.colors.colPrimary, slotHover.hovered ? 0.9 : pulse.alpha)
    activeFocusOnTab: root.active

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.onPressAction: root.placed()

    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.placed()
            event.accepted = true
        }
    }

    Behavior on implicitHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
    }
    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 120 } }

    // gentle pulse so the eye finds the slots without hunting
    QtObject {
        id: pulse
        property real alpha: 0.35
    }
    SequentialAnimation {
        running: root.active && !slotHover.hovered && Appearance.animationsEnabled
        loops: Animation.Infinite
        NumberAnimation { target: pulse; property: "alpha"; to: 0.75; duration: 700; easing.type: Easing.InOutQuad }
        NumberAnimation { target: pulse; property: "alpha"; to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "add"
        iconSize: root.compact ? 18 : 16
        color: slotHover.hovered ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
    }

    HoverHandler { id: slotHover }
    TapHandler { onTapped: root.placed() }
}
