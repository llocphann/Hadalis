import qs
import qs.modules.bar.weather
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.perimeter
import qs.services

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var perimeterContext: null
    property var sourceScreen: null
    property bool _niriFocusSeen: false

    readonly property string outputName: root.perimeterContext?.outputName ?? ""
    readonly property string instanceId: root.perimeterContext?.instanceId ?? ""
    readonly property var route: routeState.route
    readonly property bool routeOwned: routeState.routeOwned
    readonly property color surfaceColor: Appearance.inirEverywhere
        ? Appearance.inir.colLayer1 : Appearance.colors.colLayer0

    screen: root.sourceScreen ?? Quickshell.screens[0]
    color: "transparent"
    exclusiveZone: 0
    visible: routeState.visualVisible && root.sourceScreen !== null

    WlrLayershell.namespace: "hadalis:perimeter-weather"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.routeOwned
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ConnectedSurfaceRouteState {
        id: routeState
        outputName: root.outputName
        instanceId: root.instanceId
        surfaceName: "weather"
    }

    onRouteOwnedChanged: {
        if (!root.routeOwned) {
            root._niriFocusSeen = false
            return
        }
        Qt.callLater(() => {
            if (!root.routeOwned)
                return
            weatherViewport.forceActiveFocus()
            if (CompositorService.isNiri && root.active)
                root._niriFocusSeen = true
        })
    }

    onActiveChanged: {
        if (!CompositorService.isNiri || !root.routeOwned)
            return
        if (root.active) {
            root._niriFocusSeen = true
            return
        }
        if (root._niriFocusSeen) {
            root._niriFocusSeen = false
            SurfaceRouteController.dismiss(root.outputName, "focus-loss")
        }
    }

    ConnectedSurfaceGeometry {
        id: geometry
        edge: root.route?.edge ?? "top"
        alignment: PerimeterTopology.alignmentForSlot(
            root.route?.slot ?? "top.center")
        outputRect: Qt.rect(0, 0, root.width, root.height)
        devicePixelRatio: root.sourceScreen?.devicePixelRatio ?? 1
        anchorRect: root.route?.anchorRect ?? Qt.rect(0, 0, 0, 0)
        bodySize: Qt.size(
            Math.max(320, weatherContent.implicitWidth + 24),
            Math.max(220, weatherContent.implicitHeight + 24))
        progress: routeState.revealProgress
    }

    ConnectedSurfaceFrame {
        id: frame
        anchors.fill: parent
        geometry: geometry
        fillColor: root.surfaceColor
        borderColor: Appearance.inirEverywhere
            ? Appearance.inir.colBorder : "transparent"
        borderWidth: Appearance.inirEverywhere ? 1 : 0
    }

    ConnectedSurfaceContentHost {
        id: popupBody
        geometry: geometry
        padding: 12
        opacity: Math.max(0, Math.min(1,
            (routeState.revealProgress - 0.18) / 0.82))

        Flickable {
            id: weatherViewport
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, weatherContent.implicitWidth)
            contentHeight: Math.max(height, weatherContent.implicitHeight)
            interactive: contentWidth > width + 0.5 || contentHeight > height + 0.5
            boundsBehavior: Flickable.StopAtBounds

            WeatherPopupContent {
                id: weatherContent
                compact: geometry.maximumBodyWidth < compactBreakpoint
                x: Math.max(0,
                    (weatherViewport.width - implicitWidth) / 2)
                y: Math.max(0,
                    (weatherViewport.height - implicitHeight) / 2)
            }
        }
    }

    ConnectedSurfaceMask {
        id: connectedMask
        geometry: geometry
        bodyItem: frame.bodyItem
        connectorItem: frame.connectorItem
    }

    Item {
        id: emptyInputArea
        width: 0
        height: 0
    }

    Region {
        id: emptyInputRegion
        item: emptyInputArea
    }

    mask: root.routeOwned ? connectedMask : emptyInputRegion

    CompositorFocusGrab {
        windows: [root]
        active: root.routeOwned && CompositorService.isHyprland
        onCleared: () => {
            if (root.routeOwned)
                SurfaceRouteController.dismiss(root.outputName, "focus-loss")
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.routeOwned
        onActivated: SurfaceRouteController.dismiss(root.outputName, "escape")
    }
}
