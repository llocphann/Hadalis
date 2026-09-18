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
    // Attached surfaces suppress shadow on joined edges. Clipping a normal
    // radius-aware RectangularShadow at the body boundary keeps the free-corner
    // falloff correct without painting across Bar/Screen Edge seams.
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    visible: !Appearance.gameModeMinimal && Appearance.effectsEnabled
    anchors.fill: target

    readonly property real _extent: Math.max(0,
        root.blur + Math.max(0, root.spread)
            + Math.max(Math.abs(root.offset.x), Math.abs(root.offset.y)) + 2)

    Item {
        id: shadowClip
        x: root.joinLeft ? 0 : -root._extent
        y: root.joinTop ? 0 : -root._extent
        width: root.width
            + (root.joinLeft ? 0 : root._extent)
            + (root.joinRight ? 0 : root._extent)
        height: root.height
            + (root.joinTop ? 0 : root._extent)
            + (root.joinBottom ? 0 : root._extent)
        clip: root.joinTop || root.joinBottom || root.joinLeft || root.joinRight

        // RectangularShadow shrinks its effective corner radius by ~blur*0.75
        // (Qt's clampedRadius()), so compensate to keep the free corners aligned
        // with the target while the clip hard-stops every attached edge.
        RectangularShadow {
            x: -shadowClip.x
            y: -shadowClip.y
            width: root.width
            height: root.height
            radius: root.radius + root.blur * 0.75
            blur: root.blur
            offset: root.offset
            spread: root.spread
            color: root.color
            cached: true
        }
    }
}
