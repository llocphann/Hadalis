pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root
    property bool active: false
    // Optional responsive floor used by embedded/rehosted dialogs. Natural
    // content remains authoritative; a larger host may distribute spare space
    // across rows without scaling text/icons or changing modal dialog density.
    property real adaptiveMinimumHeight: 0

    horizontalPadding: Appearance.rounding.large
    verticalPadding: 12

    clip: true
    pointingHandCursor: !active    
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: Math.max(contentItem.implicitHeight + verticalPadding * 2,
        adaptiveMinimumHeight)
    Behavior on implicitHeight {
        // Host geometry is already animated by Abyss. In adaptive mode follow
        // that continuously instead of starting a second lagging row animation.
        enabled: adaptiveMinimumHeight <= 0
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    colBackground: active
        ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: active
        ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
    colRipple: active
        ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
    buttonRadius: Appearance.rounding.normal
}
