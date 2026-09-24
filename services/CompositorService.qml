pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")
    // Niri is the only supported compositor. Keep the retired capability flag
    // fail-closed until legacy consumers finish migrating, so they never turn
    // a removed property into runtime binding errors.
    readonly property bool isHyprland: false
    readonly property bool isNiri: niriSocket.length > 0

    property var sortedToplevels: []
    property var _sortingConsumers: ({})
    property int _sortingConsumersCount: 0
    property int _sortingLeaseCount: 0
    readonly property bool sortingActive:
        root._sortingConsumersCount + root._sortingLeaseCount > 0
    property bool _sortScheduled: false

    Timer {
        id: sortTimer
        interval: 100
        repeat: false
        onTriggered: {
            root._sortScheduled = false
            root.sortedToplevels = root.computeSortedToplevels()
        }
    }

    function scheduleSort(): void {
        if (!root.sortingActive || root._sortScheduled)
            return
        root._sortScheduled = true
        sortTimer.restart()
    }

    function setSortingConsumer(name: string, active: bool): void {
        if (!name || name.length === 0)
            return
        const prev = !!root._sortingConsumers[name]
        if (prev === active)
            return
        const wasActive = root.sortingActive
        root._sortingConsumers[name] = active
        let count = 0
        for (const key in root._sortingConsumers) {
            if (root._sortingConsumers[key])
                count++
        }
        root._sortingConsumersCount = count
        root._handleSortingDemandChanged(wasActive)
    }

    function acquireSortingConsumer(): void {
        const wasActive = root.sortingActive
        root._sortingLeaseCount++
        root._handleSortingDemandChanged(wasActive)
    }

    function releaseSortingConsumer(): void {
        if (root._sortingLeaseCount <= 0)
            return
        const wasActive = root.sortingActive
        root._sortingLeaseCount--
        root._handleSortingDemandChanged(wasActive)
    }

    function _handleSortingDemandChanged(wasActive: bool): void {
        if (!wasActive && root.sortingActive) {
            root.scheduleSort()
        } else if (wasActive && !root.sortingActive) {
            sortTimer.stop()
            root._sortScheduled = false
            root.sortedToplevels = []
        }
    }

    function computeSortedToplevels(): var {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values)
            return []
        return NiriService.sortToplevels(ToplevelManager.toplevels.values)
    }

    function filterCurrentWorkspace(toplevels, screen): var {
        return NiriService.filterCurrentWorkspace(toplevels, screen)
    }

    function powerOffMonitors(): void { NiriService.powerOffMonitors() }
    function powerOnMonitors(): void { NiriService.powerOnMonitors() }

    Connections {
        target: ToplevelManager.toplevels
        enabled: root.sortingActive
        function onValuesChanged(): void { root.scheduleSort() }
    }

    Connections {
        target: NiriService
        enabled: root.sortingActive
        function onWindowOrderChanged(): void { root.scheduleSort() }
        function onActiveWindowChanged(): void { root.scheduleSort() }
    }

    Component.onCompleted: {
        if (root.isNiri)
            console.info("CompositorService: Niri runtime connected")
        else
            console.warn("CompositorService: NIRI_SOCKET is not available")
    }
}
