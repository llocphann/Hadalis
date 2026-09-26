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
    property bool histories: true
    readonly property bool monitoring: root.active
        && (!root.target
            || (root.target.visible
                && (!root.target.QsWindow.window
                    || root.target.QsWindow.window.visible)))
    property bool _holding: false
    property bool _holdingHistories: true

    function sync(): void {
        if (!root.monitoring) {
            if (root._holding) {
                root._holding = false
                ResourceUsage.releaseKeepAlive(root._holdingHistories)
            }
            return
        }

        if (!root._holding) {
            root._holding = true
            root._holdingHistories = root.histories
            ResourceUsage.keepAlive(root._holdingHistories)
            return
        }

        if (root._holdingHistories !== root.histories) {
            ResourceUsage.keepAlive(root.histories)
            ResourceUsage.releaseKeepAlive(root._holdingHistories)
            root._holdingHistories = root.histories
        }
    }

    onMonitoringChanged: root.sync()
    onHistoriesChanged: root.sync()
    Component.onCompleted: root.sync()
    Component.onDestruction: {
        if (root._holding) {
            root._holding = false
            ResourceUsage.releaseKeepAlive(root._holdingHistories)
        }
    }
}
