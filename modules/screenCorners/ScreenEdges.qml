pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.services
import qs.modules.waffle.looks as WaffleLooks
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Persistent Caelestia-style screen frame. ScreenEdges.qml is the sole owner of
// the physical perimeter: four straight bands plus four identical rounded inner
// corners. No shadow or Bar-local fallback participates in this geometry.
Scope {
    id: root

    readonly property int thickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))

    // Caelestia BorderConfig defaults: thickness=10, rounding=25. Keep the
    // reconstruction radius fixed until the geometry is live-validated.
    readonly property int cornerRadius: 25
    readonly property int cornerExtent: thickness + cornerRadius

    readonly property bool waffleFamily:
        (Config.options?.panelFamily ?? "ii") === "waffle"
    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property string iiBarEdge: barVertical
        ? ((Config.options?.bar?.bottom ?? false) ? "right" : "left")
        : ((Config.options?.bar?.bottom ?? false) ? "bottom" : "top")
    readonly property string iiBarPanelId:
        barVertical ? "iiVerticalBar" : "iiBar"
    readonly property bool iiBarPanelEnabled:
        (Config.options?.enabledPanels ?? []).includes(iiBarPanelId)
    readonly property string waffleBarEdge:
        (Config.options?.waffles?.bar?.bottom ?? false) ? "bottom" : "top"
    readonly property bool waffleBarPanelEnabled: root.waffleFamily
        && (Config.options?.enabledPanels ?? []).includes("wBar")

    readonly property bool barPanelEnabled:
        root.iiBarPanelEnabled || root.waffleBarPanelEnabled
    readonly property string barPanelId:
        root.waffleBarPanelEnabled ? "wBar" : root.iiBarPanelId
    readonly property string barEdge:
        root.waffleBarPanelEnabled ? root.waffleBarEdge : root.iiBarEdge

    readonly property color edgeColor: root.waffleBarPanelEnabled
        ? WaffleLooks.Looks.colors.bg0
        : Appearance.colors.colLayer0

    function targetsOutput(outputName, configuredList) {
        if (outputName.length === 0)
            return false
        const list = configuredList ?? []
        if (!list || list.length === 0)
            return true
        const matched = Quickshell.screens.filter(screen => {
            const screenName = String(screen?.name ?? "")
            return screenName.length > 0 && list.includes(screenName)
        })
        if (matched.length === 0)
            return true
        return list.includes(outputName)
    }

    function iiBarTargetsOutput(outputName) {
        return root.targetsOutput(outputName,
            Config.options?.bar?.screenList ?? [])
    }

    function waffleBarTargetsOutput(outputName) {
        return root.targetsOutput(outputName,
            Config.options?.waffles?.bar?.screenList ?? [])
    }

    function barTargetsOutput(outputName) {
        return root.waffleBarPanelEnabled
            ? root.waffleBarTargetsOutput(outputName)
            : root.iiBarTargetsOutput(outputName)
    }

    function barOwnsEdge(outputName, edge) {
        if (!GlobalStates.barOpen || GlobalStates.widgetEditMode)
            return false

        // Auto-hide is the geometry-work baseline: the persistent Screen Edge
        // owns all four physical edges while the ii Bar translates away/reveals
        // above it. Do not substitute a Bar-local fallback surface.
        const iiOwned = !root.waffleFamily
            && root.iiBarPanelEnabled
            && !(Config.options?.bar?.autoHide?.enable ?? false)
            && edge === root.iiBarEdge
            && root.iiBarTargetsOutput(outputName)
        const waffleOwned = root.waffleBarPanelEnabled
            && edge === root.waffleBarEdge
            && root.waffleBarTargetsOutput(outputName)
        return iiOwned || waffleOwned
    }

    component EdgeWindow: PanelWindow {
        required property ShellScreen modelData
        required property string edge

        readonly property string outputName: String(modelData?.name ?? "")
        readonly property bool horizontal: edge === "top" || edge === "bottom"
        readonly property bool fullscreenCovered: outputName.length > 0
            && GameMode.hasFullscreenOnOutput(outputName)
        readonly property bool mapped: Config.ready
            && !GlobalStates.screenLocked
            && !fullscreenCovered
            && !root.barOwnsEdge(outputName, edge)

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        exclusiveZone: mapped ? root.thickness : 0
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: horizontal ? 1 : root.thickness
        implicitHeight: horizontal ? root.thickness : 1

        WlrLayershell.namespace: "hadalis:screen-edge-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: edge === "top" || edge === "left" || edge === "right"
            bottom: edge === "bottom" || edge === "left" || edge === "right"
            left: edge === "left" || edge === "top" || edge === "bottom"
            right: edge === "right" || edge === "top" || edge === "bottom"
        }

        Item {
            id: emptyInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyInput }

        Rectangle {
            anchors.fill: parent
            color: root.edgeColor
        }
    }

    // One canonical top-left corner path is mirrored for the other three
    // corners. This guarantees identical geometry regardless of Bar position.
    // The filled region is the outer L-shaped frame; the quarter-circle is the
    // rounded inner boundary of the workspace, matching Caelestia's 25px
    // BorderConfig rounding.
    component CornerWindow: PanelWindow {
        required property ShellScreen modelData
        required property string corner

        readonly property string outputName: String(modelData?.name ?? "")
        readonly property bool atRight: corner.endsWith("right")
        readonly property bool atBottom: corner.startsWith("bottom")
        readonly property string horizontalEdge: atBottom ? "bottom" : "top"
        readonly property string verticalEdge: atRight ? "right" : "left"
        readonly property bool fullscreenCovered: outputName.length > 0
            && GameMode.hasFullscreenOnOutput(outputName)
        readonly property bool mapped: Config.ready
            && !GlobalStates.screenLocked
            && !fullscreenCovered
            && !root.barOwnsEdge(outputName, horizontalEdge)
            && !root.barOwnsEdge(outputName, verticalEdge)

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: root.cornerExtent
        implicitHeight: root.cornerExtent

        WlrLayershell.namespace: "hadalis:screen-edge-corner-" + corner
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: !atBottom
            bottom: atBottom
            left: !atRight
            right: atRight
        }

        Item {
            id: emptyCornerInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyCornerInput }

        Shape {
            id: cornerShape
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            transform: Scale {
                origin.x: cornerShape.width / 2
                origin.y: cornerShape.height / 2
                xScale: cornerWindow.atRight ? -1 : 1
                yScale: cornerWindow.atBottom ? -1 : 1
            }

            ShapePath {
                fillColor: root.edgeColor
                strokeColor: "transparent"
                strokeWidth: 0

                // Canonical top-left frame corner:
                // outer square -> top band -> exact quarter-circle inner arc
                // -> left band -> outer square.
                startX: 0
                startY: 0
                PathLine { x: root.cornerExtent; y: 0 }
                PathLine { x: root.cornerExtent; y: root.thickness }
                PathArc {
                    x: root.thickness
                    y: root.cornerExtent
                    radiusX: root.cornerRadius
                    radiusY: root.cornerRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: root.cornerExtent }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        EdgeWindow { edge: "top" }
    }
    Variants {
        model: Quickshell.screens
        EdgeWindow { edge: "bottom" }
    }
    Variants {
        model: Quickshell.screens
        EdgeWindow { edge: "left" }
    }
    Variants {
        model: Quickshell.screens
        EdgeWindow { edge: "right" }
    }

    Variants {
        model: Quickshell.screens
        CornerWindow { corner: "top-left" }
    }
    Variants {
        model: Quickshell.screens
        CornerWindow { corner: "top-right" }
    }
    Variants {
        model: Quickshell.screens
        CornerWindow { corner: "bottom-left" }
    }
    Variants {
        model: Quickshell.screens
        CornerWindow { corner: "bottom-right" }
    }
}
