import qs
import qs.modules.common
import qs.modules.common.perimeter
import qs.modules.common.widgets
import qs.modules.mediaControls
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
    readonly property var route: SurfaceRouteController.current(root.outputName)
    readonly property bool routeOwned: root.route !== null
        && root.route.family === "perimeter"
        && root.route.surface === "media"
        && root.route.sourceInstance === root.instanceId
    readonly property color surfaceColor: Appearance.inirEverywhere
        ? Appearance.inir.colLayer1 : Appearance.colors.colLayer0

    screen: root.sourceScreen ?? Quickshell.screens[0]
    color: "transparent"
    exclusiveZone: 0
    visible: root.routeOwned && root.sourceScreen !== null

    WlrLayershell.namespace: "hadalis:perimeter-media"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onRouteOwnedChanged: {
        if (!root.routeOwned) {
            root._niriFocusSeen = false
            return
        }
        Qt.callLater(() => {
            if (root.routeOwned) {
                mediaPopup.forceActiveFocus()
                mediaPopup.focusInitialControl()
                if (CompositorService.isNiri && root.active)
                    root._niriFocusSeen = true
            }
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

    onActiveFocusItemChanged: {
        if (root.routeOwned)
            mediaViewport.ensureFocusVisible(root.activeFocusItem)
    }

    ConnectedSurfaceGeometry {
        id: geometry
        edge: root.route?.edge ?? "top"
        alignment: PerimeterTopology.alignmentForSlot(root.route?.slot ?? "top.center")
        outputRect: Qt.rect(0, 0, root.width, root.height)
        devicePixelRatio: root.sourceScreen?.devicePixelRatio ?? 1
        anchorRect: root.route?.anchorRect ?? Qt.rect(0, 0, 0, 0)
        bodySize: Qt.size(
            Math.max(360, mediaPopup.implicitWidth + 24),
            Math.max(220, Math.min(Math.max(220, root.height - 32),
                mediaPopup.implicitHeight + 24)))
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
            id: mediaViewport
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, mediaPopup.implicitWidth)
            contentHeight: Math.max(height, mediaPopup.implicitHeight)
            interactive: contentWidth > width + 0.5 || contentHeight > height + 0.5
            boundsBehavior: Flickable.StopAtBounds

            function ensureFocusVisible(item): void {
                if (!item || width <= 0 || height <= 0)
                    return

                const position = item.mapToItem(contentItem, 0, 0)
                const margin = 8
                const maxX = Math.max(0, contentWidth - width)
                const maxY = Math.max(0, contentHeight - height)
                let nextX = contentX
                let nextY = contentY

                if (position.x - margin < nextX)
                    nextX = Math.max(0, position.x - margin)
                else if (position.x + item.width + margin > nextX + width)
                    nextX = Math.min(maxX,
                        position.x + item.width + margin - width)

                if (position.y - margin < nextY)
                    nextY = Math.max(0, position.y - margin)
                else if (position.y + item.height + margin > nextY + height)
                    nextY = Math.min(maxY,
                        position.y + item.height + margin - height)

                if (nextX !== contentX)
                    contentX = nextX
                if (nextY !== contentY)
                    contentY = nextY
            }

            BarMediaPopup {
                id: mediaPopup
                width: implicitWidth
                height: implicitHeight
                x: Math.max(0, (mediaViewport.width - width) / 2)
                y: Math.max(0, (mediaViewport.height - height) / 2)
                popupRounding: Math.max(0, geometry.outerRadius - 8)
                screenX: popupBody.x + mediaViewport.x + mediaPopup.x
                    - mediaViewport.contentX
                screenY: popupBody.y + mediaViewport.y + mediaPopup.y
                    - mediaViewport.contentY
                onCloseRequested: {
                    if (root.routeOwned)
                        SurfaceRouteController.dismiss(root.outputName, "escape")
                }
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
