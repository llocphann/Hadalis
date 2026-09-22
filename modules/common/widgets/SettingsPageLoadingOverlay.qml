pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A quiet, floating gear is visible only while the selected Settings page
// has no presented content. No card/pill backing, no icon/text pair.
Item {
    id: root

    property bool loading: false
    property int showDelay: 90
    property bool _shown: false

    // When the page becomes ready, remove the loader immediately. A minimum
    // visible timer or exit animation must not linger over interactive content.
    visible: root.loading && root._shown

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

    Item {
        anchors.centerIn: parent
        width: 64
        height: width

        // Static ring gives the gear a legible silhouette without creating
        // a separate surface or competing with the Settings card elevation.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: SettingsMaterialPreset.accentColor
            opacity: 0.24
        }

        // Shared indicator uses a 0.8 glyph/box ratio: 50 -> 40 px gear.
        // Only the glyph rotates; the ring never animates or scales.
        MaterialLoadingIndicator {
            anchors.centerIn: parent
            implicitSize: 50
            color: SettingsMaterialPreset.accentColor
            loading: root.loading && root._shown
        }
    }
}
