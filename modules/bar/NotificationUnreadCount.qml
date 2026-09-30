import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    property color indicatorColor: Appearance.colors.colOnLayer0
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    text: Notifications.silent ? "notifications_paused" : "notifications"
    iconSize: Math.round(Appearance.font.pixelSize.larger * Appearance.sizes.barModuleScale)
    color: root.indicatorColor

    Rectangle {
        id: notifPing
        readonly property real badgeHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitHeight + 2 * Appearance.sizes.barModuleScale, 8 * Appearance.sizes.barModuleScale) : 8 * Appearance.sizes.barModuleScale

        opacity: !Notifications.silent && Notifications.unread > 0 ? 1 : 0
        visible: opacity > 0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : Appearance.sizes.barModuleScale
            topMargin: root.showUnreadCount ? 0 : 3 * Appearance.sizes.barModuleScale
        }
        radius: Math.min(width, height) / 2
        color: Appearance.colors.colOnLayer0
        z: 1

        implicitHeight: badgeHeight
        implicitWidth: root.showUnreadCount ? Math.max(badgeHeight, notificationCounterText.implicitWidth + 6 * Appearance.sizes.barModuleScale) : badgeHeight

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on anchors.rightMargin {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on anchors.topMargin {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        StyledText {
            id: notificationCounterText
            opacity: root.showUnreadCount ? 1 : 0
            visible: opacity > 0
            anchors.centerIn: parent
            font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * Appearance.sizes.barModuleScale)
            color: Appearance.colors.colLayer0
            text: root.showUnreadCount ? Notifications.unread : ""

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
