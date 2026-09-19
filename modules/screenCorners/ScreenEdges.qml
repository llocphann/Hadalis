pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.perimeter
import qs.services
import qs.modules.waffle.looks as WaffleLooks
import QtQuick
import Quickshell
import Quickshell.Wayland

// Persistent Caelestia-style screen-edge surface. This is presentation-only:
// it never reserves work area or captures input, and therefore remains separate
// from sidebar edge-open hit regions and from connected-popup geometry.
Scope {
    id: root

    readonly property int thickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    // Caelestia BorderConfig defaults to rounding=25 independently from
    // component/card rounding. Keep the physical frame on that exact geometry.
    readonly property int innerRadius: Math.max(0, Math.min(96,
        Math.round(Config.options?.appearance?.screenEdge?.radius
            ?? PerimeterTokens.frameRadius)))
    readonly property bool shadowEnabled:
        Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true
    readonly property int shadowSize: Math.max(0, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
    readonly property real shadowOpacity: Math.max(0, Math.min(1.0,
        Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70)))
    readonly property int shadowExtent: shadowEnabled ? shadowSize : 0
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

    // Compatibility aliases retained for callers/tests that only need the
    // currently active family. barOwnsEdge() below remains authoritative when
    // more than one panel id is accidentally enabled.
    readonly property bool barPanelEnabled:
        root.iiBarPanelEnabled || root.waffleBarPanelEnabled
    readonly property string barPanelId:
        root.waffleBarPanelEnabled ? "wBar" : root.iiBarPanelId
    readonly property string barEdge:
        root.waffleBarPanelEnabled ? root.waffleBarEdge : root.iiBarEdge

    // Screen Edge must read as the continuation of the active bar family.
    readonly property color edgeColor: root.waffleBarPanelEnabled
        ? WaffleLooks.Looks.colors.bg0
        : Appearance.colors.colLayer0
    readonly property color shadowColor:
        ColorUtils.applyAlpha(Appearance.colors.colShadow, shadowOpacity)

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
        // Keep ownership identical to both Bar implementations: stale output
        // names fall back to all screens rather than hiding the bar everywhere.
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
        const iiOwned = root.iiBarPanelEnabled
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
        readonly property string leadingAdjacentEdge: horizontal ? "left" : "top"
        readonly property string trailingAdjacentEdge: horizontal ? "right" : "bottom"
        readonly property real leadingShadowInset:
            root.barOwnsEdge(outputName, leadingAdjacentEdge)
                ? 0 : root.thickness + root.innerRadius
        readonly property real trailingShadowInset:
            root.barOwnsEdge(outputName, trailingAdjacentEdge)
                ? 0 : root.thickness + root.innerRadius
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
        // Reserve only the solid Screen Edge band. The inward shadow stays
        // visual-only, so compositor Window Gap is measured from the inner
        // Screen Edge boundary rather than from the physical display rim.
        exclusiveZone: mapped ? root.thickness : 0
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: horizontal ? 1 : root.thickness + root.shadowExtent
        // Horizontal edges need room for both the 25px inverse corner and the
        // inward 15px Caelestia-style shadow; using max() clipped the shadow at
        // the curved endpoints and made the lower edge look flat/unshadowed.
        implicitHeight: horizontal
            ? root.thickness + root.innerRadius + root.shadowExtent
            : 1

        WlrLayershell.namespace: "hadalis:screen-edge-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: edge === "top" || edge === "left" || edge === "right"
            bottom: edge === "bottom" || edge === "left" || edge === "right"
            left: edge === "left" || edge === "top" || edge === "bottom"
            right: edge === "right" || edge === "top" || edge === "bottom"
        }

        // Keep the edge completely click-through. SidebarHost owns edge-open
        // interaction so changing visual width can never steal clicks.
        Item {
            id: emptyInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyInput }

        Item {
            id: edgeSurface
            anchors.fill: parent

            Rectangle {
                id: edgeBand
                x: horizontal ? 0
                    : (edge === "left" ? 0 : parent.width - root.thickness)
                y: horizontal
                    ? (edge === "top" ? 0 : parent.height - root.thickness)
                    : 0
                width: horizontal ? parent.width : root.thickness
                height: horizontal ? root.thickness : parent.height
                color: root.edgeColor
                z: 2
            }

            // Straight portions use an explicit in-window gradient. This is
            // deliberately not a layer effect: layer-shell textures clip effect
            // padding differently across compositors, which made the shadow
            // disappear entirely on the user's Niri/Qt path.
            Rectangle {
                id: edgeShadow
                z: 0
                visible: root.shadowEnabled
                    && root.shadowExtent > 0
                    && root.shadowOpacity > 0
                x: horizontal ? leadingShadowInset
                    : (edge === "left"
                        ? root.thickness
                        : edgeBand.x - root.shadowExtent)
                y: horizontal
                    ? (edge === "top"
                        ? root.thickness
                        : edgeBand.y - root.shadowExtent)
                    : leadingShadowInset
                width: horizontal
                    ? Math.max(0, parent.width
                        - leadingShadowInset - trailingShadowInset)
                    : root.shadowExtent
                height: horizontal
                    ? root.shadowExtent
                    : Math.max(0, parent.height
                        - leadingShadowInset - trailingShadowInset)
                color: "transparent"
                gradient: Gradient {
                    orientation: horizontal ? Gradient.Vertical : Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: (edge === "top" || edge === "left")
                            ? root.shadowColor : "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: (edge === "top" || edge === "left")
                            ? "transparent" : root.shadowColor
                    }
                }
            }

            // PERIMETER-CORNER-LOCK (maintainer approved 2026-09-19):
            // The bottom-left/bottom-right free Screen Edge arcs are the approved
            // lower pair of the four-corner frame contract. Keep their geometry
            // symmetric with the Bar-owned top pair. The horizontal edge owns
            // these endpoints with a single screen-edge-thickness inset; do not
            // move them inward/outward independently. Radius may change only via
            // appearance.screenEdge.radius, shared with Bar.qml.
            //
            // Horizontal EdgeWindow owns the free endpoint curves. The curved
            // shadow is drawn by RoundCorner itself so it follows the actual
            // circular boundary instead of stopping at the straight segment.
            RoundCorner {
                id: leadingCorner
                z: 2
                visible: horizontal && !root.barOwnsEdge(outputName, "left")
                implicitSize: root.innerRadius
                color: root.edgeColor
                shadowEnabled: root.shadowEnabled
                shadowExtent: root.shadowExtent
                shadowColor: root.shadowColor
                anchors {
                    left: parent.left
                    leftMargin: root.thickness
                    top: edge === "top" ? edgeBand.bottom : undefined
                    bottom: edge === "bottom" ? edgeBand.top : undefined
                }
                corner: edge === "top"
                    ? RoundCorner.CornerEnum.TopLeft
                    : RoundCorner.CornerEnum.BottomLeft
            }

            RoundCorner {
                id: trailingCorner
                z: 2
                visible: horizontal && !root.barOwnsEdge(outputName, "right")
                implicitSize: root.innerRadius
                color: root.edgeColor
                shadowEnabled: root.shadowEnabled
                shadowExtent: root.shadowExtent
                shadowColor: root.shadowColor
                anchors {
                    right: parent.right
                    rightMargin: root.thickness
                    top: edge === "top" ? edgeBand.bottom : undefined
                    bottom: edge === "bottom" ? edgeBand.top : undefined
                }
                corner: edge === "top"
                    ? RoundCorner.CornerEnum.TopRight
                    : RoundCorner.CornerEnum.BottomRight
            }
        }
    }

    // Horizontal EdgeWindow owns the endpoint curves; left/right EdgeWindow
    // only provide the straight physical bands and their inward shadows.
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

}
