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
    property bool network: true
    readonly property int _demandFlags: (root.histories ? 1 : 0) | (root.network ? 2 : 0)
    readonly property bool monitoring: root.active
        && (!root.target
            || (root.target.visible
                && (!root.target.QsWindow.window
                    || root.target.QsWindow.window.visible)))

    property QtObject _serviceLease: ServiceLease {
        active: root.monitoring
        value: root._demandFlags
        acquire: demandFlags => {
            ResourceUsage.keepAlive((demandFlags & 1) !== 0, (demandFlags & 2) !== 0)
            return demandFlags
        }
        update: (heldFlags, demandFlags) => {
            // Acquire the replacement first so polling never briefly drops to
            // zero consumers while an active monitor changes demand.
            ResourceUsage.keepAlive((demandFlags & 1) !== 0, (demandFlags & 2) !== 0)
            ResourceUsage.releaseKeepAlive((heldFlags & 1) !== 0, (heldFlags & 2) !== 0)
            return demandFlags
        }
        release: heldFlags =>
            ResourceUsage.releaseKeepAlive((heldFlags & 1) !== 0, (heldFlags & 2) !== 0)
    }
}
