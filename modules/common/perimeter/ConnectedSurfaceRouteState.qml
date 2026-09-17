import qs.modules.common
import QtQuick

QtObject {
    id: root

    required property string outputName
    required property string instanceId
    required property string surfaceName

    property var _routeSnapshot: null
    property bool _routeOwned: false
    property bool _lingerVisible: false
    property real revealProgress: 0

    readonly property var route: root._routeSnapshot
    readonly property bool routeOwned: root._routeOwned
    readonly property bool visualVisible: root._routeOwned || root._lingerVisible

    function _owns(route) {
        return route !== null
            && route.family === "perimeter"
            && route.surface === root.surfaceName
            && route.sourceInstance === root.instanceId
            && route.output === root.outputName
    }

    function _open(route, animate) {
        if (!root._owns(route))
            return

        const alreadyResident = root._lingerVisible
        retractTimer.stop()
        root._routeSnapshot = route
        root._routeOwned = true
        root._lingerVisible = true

        if (!Appearance.animationsEnabled) {
            root.revealProgress = 1
            return
        }

        if (alreadyResident || !animate) {
            root.revealProgress = 1
            return
        }

        root.revealProgress = 0
        Qt.callLater(() => {
            if (root._routeOwned)
                root.revealProgress = 1
        })
    }

    function _update(route) {
        if (!root._owns(route))
            return
        root._routeSnapshot = route
        root._routeOwned = true
        root._lingerVisible = true
    }

    function _close(route) {
        if (root._owns(route))
            root._routeSnapshot = route
        if (!root._routeOwned && !root._lingerVisible)
            return

        root._routeOwned = false
        root.revealProgress = 0
        if (Appearance.animationsEnabled) {
            retractTimer.restart()
            return
        }

        root._lingerVisible = false
        root._routeSnapshot = null
    }

    function _syncCurrent(animate) {
        const current = SurfaceRouteController.current(root.outputName)
        if (root._owns(current)) {
            root._open(current, animate)
            return
        }

        retractTimer.stop()
        root._routeOwned = false
        root._lingerVisible = false
        root.revealProgress = 0
        root._routeSnapshot = null
    }

    onOutputNameChanged: root._syncCurrent(false)
    onInstanceIdChanged: root._syncCurrent(false)
    onSurfaceNameChanged: root._syncCurrent(false)
    Component.onCompleted: root._syncCurrent(false)

    Behavior on revealProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    Timer {
        id: retractTimer
        interval: Math.max(1, Appearance.animation.elementMoveEnter.duration + 16)
        repeat: false
        onTriggered: {
            if (!root._routeOwned && root.revealProgress <= 0.001) {
                root._lingerVisible = false
                root._routeSnapshot = null
            }
        }
    }

    Connections {
        target: SurfaceRouteController

        function onOpened(outputName, route) {
            if (root._owns(route))
                root._open(route, true)
        }

        function onUpdated(outputName, route) {
            if (root._owns(route))
                root._update(route)
        }

        function onClosed(outputName, route, reason) {
            if (root._owns(route))
                root._close(route)
        }
    }
}
