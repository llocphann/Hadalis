pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText: ""
    property var urgency: NotificationUrgency.Normal
    readonly property bool critical: {
        const value = button.urgency
        if (value === undefined || value === null)
            return false
        return value === NotificationUrgency.Critical
            || String(value).toLowerCase() === "critical"
    }

    implicitHeight: 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.rounding.small
    colBackground: button.critical
        ? Appearance.colors.colSecondaryContainer
        : Appearance.colors.colLayer4
    colBackgroundHover: button.critical
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.colors.colLayer4Hover
    colRipple: button.critical
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.colors.colLayer4Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: button.critical
            ? Appearance.colors.colOnSecondaryContainer
            : Appearance.colors.colOnLayer3

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
