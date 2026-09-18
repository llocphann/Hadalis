pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common

// Material-only shell shadow. Public knobs stay stable because many callers
// override radius/blur/spread/color/offset directly.
Item {
    id: root
    required property var target
    property bool hovered: false
    property real radius: (target && target.radius !== undefined) ? Number(target.radius) : 0
    property real blur: (Appearance.sizes && Appearance.sizes.elevationMargin !== undefined)
        ? (0.9 * Number(Appearance.sizes.elevationMargin)) : 0
    property real spread: 1
    property color color: Appearance.colors.colShadow
    property vector2d offset: Qt.vector2d(0.0, 1.0)

    visible: !Appearance.gameModeMinimal && Appearance.effectsEnabled
    anchors.fill: target

    // RectangularShadow shrinks its effective corner radius by ~blur*0.75 (see
    // Qt's clampedRadius()), so compensate to keep the rendered shadow aligned
    // with the target's rounded outline.
    RectangularShadow {
        anchors.fill: parent
        radius: root.radius + root.blur * 0.75
        blur: root.blur
        offset: root.offset
        spread: root.spread
        color: root.color
        cached: true
    }
}
