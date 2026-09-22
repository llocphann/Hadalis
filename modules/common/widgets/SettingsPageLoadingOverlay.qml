pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool loading: false
    property int showDelay: 90
    property int minimumVisibleDuration: 180

    property bool _shown: false
    property bool _hidePending: false

    visible: root._shown || opacity > 0.001
    opacity: root._shown ? 1 : 0

    onLoadingChanged: {
        if (loading) {
            root._hidePending = false
            if (!root._shown)
                showDelayTimer.restart()
            return
        }

        showDelayTimer.stop()
        if (!root._shown)
            return

        if (minimumVisibleTimer.running)
            root._hidePending = true
        else
            root._shown = false
    }

    Timer {
        id: showDelayTimer
        interval: root.showDelay
        repeat: false
        onTriggered: {
            if (!root.loading)
                return
            root._shown = true
            root._hidePending = false
            minimumVisibleTimer.restart()
        }
    }

    Timer {
        id: minimumVisibleTimer
        interval: root.minimumVisibleDuration
        repeat: false
        onTriggered: {
            if (!root.loading || root._hidePending)
                root._shown = false
            root._hidePending = false
        }
    }

    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Rectangle {
        anchors.centerIn: parent
        // Fixed-size square plate: the former label-measured width could
        // collapse to an empty pill before text/font metrics became available.
        width: 92
        height: width
        radius: SettingsMaterialPreset.cardRadius
        color: SettingsMaterialPreset.cardColor
        border.width: 1
        border.color: SettingsMaterialPreset.cardBorderColor
        scale: root._shown ? 1 : 0.96

        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Gear-only Settings page load. Keep the glyph prominent and centered
        // regardless of the current page's asynchronous text lifecycle.
        MaterialLoadingIndicator {
            anchors.centerIn: parent
            implicitSize: 76
            color: Appearance.colors.colOnSurface
            loading: root._shown
        }
    }
}
