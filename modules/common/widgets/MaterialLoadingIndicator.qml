pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import qs.modules.common
import qs.modules.common.widgets

// Gear-only loading state. Preserve size, tint and pull-to-refresh semantics.
Item {
    id: root

    property bool loading: true
    property real pullProgress: 0
    property real implicitSize: 48
    property color color: Appearance.colors.colPrimary

    implicitWidth: implicitSize
    implicitHeight: implicitSize
    rotation: root.loading ? 0 : -Math.max(0, Math.min(1, root.pullProgress)) * 360

    MaterialSymbol {
        id: gear
        anchors.centerIn: parent
        text: "settings"
        fill: 1
        iconSize: Math.max(12, Math.min(root.width, root.height) * 0.8)
        color: root.color

        RotationAnimation on rotation {
            running: root.loading && root.visible
                && (root.Window.window?.visible ?? true)
                && Appearance.animationsEnabled
            from: 0
            to: 360
            duration: 1800
            loops: Animation.Infinite
            easing.type: Easing.Linear
            onRunningChanged: {
                if (!running)
                    gear.rotation = 0
            }
        }
    }
}
