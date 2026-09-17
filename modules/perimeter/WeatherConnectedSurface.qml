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

    readonly property string outputName: root.perimeterContext?.outputName ?? ""
    readonly property string instanceId: root.perimeterContext?.instanceId ?? ""
    readonly property var route: SurfaceRouteController.current(root.outputName)
    readonly property bool routeOwned: root.route !== null
        && root.route.family === "perimeter"
        && root.route.surface === "weather"
        && root.route.sourceInstance === root.instanceId
    readonly property color surfaceColor: Appearance.inirEverywhere
        ? Appearance.inir.colLayer1 : Appearance.colors.colLayer0

    screen: root.sourceScreen ?? Quickshell.screens[0]
    color: "transparent"
    exclusiveZone: 0
    visible: root.routeOwned && root.sourceScreen !== null

    WlrLayershell.namespace: "hadalis:perimeter-weather"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ConnectedSurfaceGeometry {
        id: geometry
        edge: root.route?.edge ?? "top"
        alignment: PerimeterTopology.alignmentForSlot(
            root.route?.slot ?? "top.center")
        outputRect: Qt.rect(0, 0, root.width, root.height)
        anchorRect: root.route?.anchorRect ?? Qt.rect(0, 0, 0, 0)
        bodySize: Qt.size(
            Math.max(320, weatherContent.implicitWidth + 24),
            Math.max(220, weatherContent.implicitHeight + 24))
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
