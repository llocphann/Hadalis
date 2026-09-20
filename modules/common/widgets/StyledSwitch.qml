pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Material 3 switch. See https://m3.material.io/components/switch/overview
 */
Switch {
    id: root

    property real scale: 0.6
    implicitHeight: 32 * root.scale
    implicitWidth: 52 * root.scale
    property color activeColor: Appearance.colors.colPrimary
    property color inactiveColor: Appearance.colors.colSurfaceContainerHighest

    PointingHandInteraction {}

    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Appearance.rounding.full
        color: root.checked ? root.activeColor : root.inactiveColor
        border.width: 2 * root.scale
        border.color: root.checked ? root.activeColor : Appearance.colors.colOutline

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    indicator: Rectangle {
        width: (root.pressed || root.down)
            ? 28 * root.scale : root.checked ? 24 * root.scale : 16 * root.scale
        height: (root.pressed || root.down)
            ? 28 * root.scale : root.checked ? 24 * root.scale : 16 * root.scale
        radius: Math.min(width, height) / 2
        color: root.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colOutline
        border.width: 0
        border.color: "transparent"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked
            ? ((root.pressed || root.down) ? 22 * root.scale : 24 * root.scale)
            : ((root.pressed || root.down) ? 2 * root.scale : 8 * root.scale)

        Behavior on anchors.leftMargin {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }
}
