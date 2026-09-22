pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.perimeter

// Workspace-only dimmer for both Settings overlay layouts.
//
// The physical Screen Edge is an inverted rounded workspace frame. Paint only
// inside that workspace silhouette, then subtract the animated Settings body
// with an inverted alpha mask. This avoids tinting either translucent colLayer0
// surface and preserves the card's top fillets and square connected bottom.
Item {
    id: root

    property string outputName: ""
    property rect cardRect: Qt.rect(0, 0, 0, 0)
    property real cardRadius: 0
    property real dim: 0

    readonly property real _thickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property bool _barVertical: Config.options?.bar?.vertical ?? false
    readonly property string _iiBarEdge: root._barVertical
        ? ((Config.options?.bar?.bottom ?? false) ? "right" : "left")
        : ((Config.options?.bar?.bottom ?? false) ? "bottom" : "top")
    readonly property string _iiBarPanelId: root._barVertical ? "iiVerticalBar" : "iiBar"

    // Match ScreenEdges.FrameWindow's output-aware ii Bar ownership/insets.
    // The locked physical frame remains the sole owner of perimeter pixels.
    function _barTargetsOutput(): bool {
        if (root.outputName.length === 0)
            return false
        const list = Config.options?.bar?.screenList ?? []
        if (!list || list.length === 0)
            return true
        const matched = Quickshell.screens.filter(screen => {
            const name = String(screen?.name ?? "")
            return name.length > 0 && list.includes(name)
        })
        if (matched.length === 0)
            return true
        return list.includes(root.outputName)
    }

    readonly property bool _iiBarOwnsEdge:
        (Config.options?.panelFamily ?? "ii") !== "waffle"
        && (Config.options?.enabledPanels ?? []).includes(root._iiBarPanelId)
        && GlobalStates.barOpen
        && !GlobalStates.widgetEditMode
        && !(Config.options?.bar?.autoHide?.enable ?? false)
        && root._barTargetsOutput()

    readonly property real _leftInset: root._iiBarOwnsEdge
        && root._iiBarEdge === "left"
            ? Appearance.sizes.verticalBarWidth : root._thickness
    readonly property real _rightInset: root._iiBarOwnsEdge
        && root._iiBarEdge === "right"
            ? Appearance.sizes.verticalBarWidth : root._thickness
    readonly property real _topInset: root._iiBarOwnsEdge
        && root._iiBarEdge === "top"
            ? Appearance.sizes.barHeight : root._thickness
    readonly property real _bottomInset: root._iiBarOwnsEdge
        && root._iiBarEdge === "bottom"
            ? Appearance.sizes.barHeight : root._thickness

    readonly property real _innerWidth: Math.max(0,
        root.width - root._leftInset - root._rightInset)
    readonly property real _innerHeight: Math.max(0,
        root.height - root._topInset - root._bottomInset)
    readonly property real _radius: Math.max(0, Math.min(
        PerimeterTokens.frameRadius, root._innerWidth / 2, root._innerHeight / 2))

    visible: root.dim > 0 && root._innerWidth > 0 && root._innerHeight > 0
    opacity: Math.max(0, Math.min(1, root.dim))

    Shape {
        id: workspaceShape
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        // Layer source is the rounded workspace, not a full-screen rectangle.
        // The mask is intersected with that source, so a card overlapping a
        // vertical Bar or a rounded workspace corner cannot dim the perimeter.
        layer.enabled: root.visible
        layer.effect: OpacityMask {
            invert: true
            maskSource: Item {
                width: workspaceShape.width
                height: workspaceShape.height

                Rectangle {
                    x: root.cardRect.x
                    y: root.cardRect.y
                    width: Math.max(0, root.cardRect.width)
                    height: Math.max(0, root.cardRect.height)
                    radius: Math.max(0, Math.min(root.cardRadius, width / 2, height))
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    color: "white"
                }
            }
        }

        ShapePath {
            fillColor: Appearance.colors.colScrim
            strokeColor: "transparent"
            strokeWidth: -1

            startX: root._leftInset + root._radius
            startY: root._topInset
            PathLine {
                x: root.width - root._rightInset - root._radius
                y: root._topInset
            }
            PathArc {
                x: root.width - root._rightInset
                y: root._topInset + root._radius
                radiusX: root._radius
                radiusY: root._radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root.width - root._rightInset
                y: root.height - root._bottomInset - root._radius
            }
            PathArc {
                x: root.width - root._rightInset - root._radius
                y: root.height - root._bottomInset
                radiusX: root._radius
                radiusY: root._radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root._leftInset + root._radius
                y: root.height - root._bottomInset
            }
            PathArc {
                x: root._leftInset
                y: root.height - root._bottomInset - root._radius
                radiusX: root._radius
                radiusY: root._radius
                direction: PathArc.Clockwise
            }
            PathLine {
                x: root._leftInset
                y: root._topInset + root._radius
            }
            PathArc {
                x: root._leftInset + root._radius
                y: root._topInset
                radiusX: root._radius
                radiusY: root._radius
                direction: PathArc.Clockwise
            }
        }
    }
}
