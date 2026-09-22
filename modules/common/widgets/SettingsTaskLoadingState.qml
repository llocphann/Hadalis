pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Text-only activity for lazily incubated Settings sections. Delay very short
// operations, but never keep a stale Loading label after the section is Ready.
Item {
    id: root

    property bool loading: false
    property int showDelay: 90
    property bool _shown: false

    Layout.fillWidth: true
    Layout.preferredHeight: root.loading && root._shown ? 48 : 0
    opacity: root.loading && root._shown ? 1 : 0
    visible: root.loading && root._shown
    clip: true

    onLoadingChanged: {
        if (root.loading) {
            if (!root._shown)
                showDelayTimer.restart()
        } else {
            showDelayTimer.stop()
            root._shown = false
        }
    }

    Component.onCompleted: {
        if (root.loading && !root._shown)
            showDelayTimer.restart()
    }

    Timer {
        id: showDelayTimer
        interval: root.showDelay
        repeat: false
        onTriggered: {
            if (root.loading)
                root._shown = true
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

    Behavior on Layout.preferredHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
        }
    }

    LoadingText {
        anchors.centerIn: parent
    }
}
