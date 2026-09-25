pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services

// Centralized ResourceUsage lease for presentation consumers. Polling sleeps
// when a target or its native window is hidden and resumes immediately when
// the consumer becomes visible again.
QtObject {
    id: root

    property Item target: null
    property bool active: true
    readonly property bool monitoring: root.active
        && (!root.target
            || (root.target.visible
                && (!root.target.QsWindow.window
                    || root.target.QsWindow.window.visible)))
    property bool _holding: false

    function sync(): void {
        if (root.monitoring === root._holding)
            return
        root._holding = root.monitoring
        if (root._holding)
            ResourceUsage.keepAlive()
        else
            ResourceUsage.releaseKeepAlive()
    }

    onMonitoringChanged: root.sync()
    Component.onCompleted: root.sync()
    Component.onDestruction: {
        if (root._holding) {
            root._holding = false
            ResourceUsage.releaseKeepAlive()
        }
    }
}
