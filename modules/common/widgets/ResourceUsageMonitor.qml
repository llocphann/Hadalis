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

    property QtObject _serviceLease: ServiceLease {
        active: root.monitoring
        value: root.histories
        acquire: historyWanted => {
            ResourceUsage.keepAlive(historyWanted)
            return historyWanted
        }
        update: (heldHistory, historyWanted) => {
            // Acquire the replacement first so polling never briefly drops to
            // zero consumers while an active monitor changes history demand.
            ResourceUsage.keepAlive(historyWanted)
            ResourceUsage.releaseKeepAlive(heldHistory)
            return historyWanted
        }
        release: heldHistory => ResourceUsage.releaseKeepAlive(heldHistory)
    }
}
