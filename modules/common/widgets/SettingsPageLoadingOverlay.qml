pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// No independent timer or minimum duration. The host reports whether the
// requested page is not yet Ready, even while the previous page remains onscreen.
Item {
    id: root
    property bool loading: false
    visible: root.loading

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
            loading: root.loading
        }
    }
}
