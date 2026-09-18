pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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
    readonly property int innerRadius: Math.max(thickness,
        Math.round(Appearance.rounding.screenRounding))
    readonly property bool shadowEnabled:
        Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true
    readonly property int shadowSize: Math.max(0, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 12)))
    readonly property real shadowOpacity: Math.max(0, Math.min(0.60,
        Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.24)))
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
        implicitHeight: horizontal ? root.thickness + root.shadowExtent : 1

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

        Rectangle {
            id: edgeBand
            x: horizontal ? 0 : (edge === "left" ? 0 : parent.width - root.thickness)
            y: horizontal ? (edge === "top" ? 0 : parent.height - root.thickness) : 0
            width: horizontal ? parent.width : root.thickness
            height: horizontal ? root.thickness : parent.height
            color: root.edgeColor
        }

        Rectangle {
            id: edgeShadow
            visible: root.shadowExtent > 0 && root.shadowOpacity > 0
            x: horizontal ? 0 : (edge === "left" ? root.thickness : 0)
            y: horizontal ? (edge === "top" ? root.thickness : 0) : 0
            width: horizontal ? parent.width : root.shadowExtent
            height: horizontal ? root.shadowExtent : parent.height
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
    }

    // The four edge bands intentionally stay rectangular so their physical-screen
    // geometry remains exact. These transparent corner overlays only paint the
    // concave quarter-corners on the wallpaper-facing side of that frame.
    component InnerCornerWindow: PanelWindow {
        id: cornerWindow

        required property ShellScreen modelData
        required property int corner

        readonly property string outputName: String(modelData?.name ?? "")
        readonly property bool isTop: corner === RoundCorner.CornerEnum.TopLeft
            || corner === RoundCorner.CornerEnum.TopRight
        readonly property bool isLeft: corner === RoundCorner.CornerEnum.TopLeft
            || corner === RoundCorner.CornerEnum.BottomLeft
        readonly property string cornerName: isTop
            ? (isLeft ? "top-left" : "top-right")
            : (isLeft ? "bottom-left" : "bottom-right")
        readonly property bool fullscreenCovered: outputName.length > 0
            && GameMode.hasFullscreenOnOutput(outputName)
        readonly property bool adjacentBarOwned:
            root.barOwnsEdge(outputName, isTop ? "top" : "bottom")
            || root.barOwnsEdge(outputName, isLeft ? "left" : "right")
        readonly property bool mapped: Config.ready
            && !GlobalStates.screenLocked
            && !fullscreenCovered
            && !adjacentBarOwned

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: root.thickness + root.innerRadius
        implicitHeight: root.thickness + root.innerRadius

        WlrLayershell.namespace: "hadalis:screen-edge-corner-" + cornerName
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: isTop
            bottom: !isTop
            left: isLeft
            right: !isLeft
        }

        Item {
            id: emptyCornerInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyCornerInput }

        // Paint one canonical top-left inverse corner and mirror it for the
        // other three positions. This guarantees pixel-identical geometry at
        // the bottom corners instead of relying on four independent arc paths.
        Canvas {
            id: innerCornerCanvas
            width: root.innerRadius
            height: root.innerRadius
            property color fillColor: root.edgeColor
            anchors {
                top: cornerWindow.isTop ? parent.top : undefined
                bottom: cornerWindow.isTop ? undefined : parent.bottom
                left: cornerWindow.isLeft ? parent.left : undefined
                right: cornerWindow.isLeft ? undefined : parent.right
                topMargin: cornerWindow.isTop ? root.thickness : 0
                bottomMargin: cornerWindow.isTop ? 0 : root.thickness
                leftMargin: cornerWindow.isLeft ? root.thickness : 0
                rightMargin: cornerWindow.isLeft ? 0 : root.thickness
            }

            readonly property bool topSide: cornerWindow.isTop
            readonly property bool leftSide: cornerWindow.isLeft

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onFillColorChanged: requestPaint()
            onTopSideChanged: requestPaint()
            onLeftSideChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const s = Math.min(width, height)
                if (!(s > 0))
                    return

                // Draw each orientation explicitly rather than relying on a
                // mirrored Canvas transform. The bottom pair used to depend on
                // transform state at first paint and could land as a square
                // Screen Edge join while the top pair rendered correctly.
                const k = 0.5522847498
                ctx.beginPath()

                if (topSide && leftSide) {
                    ctx.moveTo(0, 0)
                    ctx.lineTo(s, 0)
                    ctx.bezierCurveTo(s * (1 - k), 0,
                        0, s * (1 - k), 0, s)
                } else if (topSide && !leftSide) {
                    ctx.moveTo(s, 0)
                    ctx.lineTo(0, 0)
                    ctx.bezierCurveTo(s * k, 0,
                        s, s * (1 - k), s, s)
                } else if (!topSide && leftSide) {
                    ctx.moveTo(0, s)
                    ctx.lineTo(s, s)
                    ctx.bezierCurveTo(s * (1 - k), s,
                        0, s * k, 0, 0)
                } else {
                    ctx.moveTo(s, s)
                    ctx.lineTo(0, s)
                    ctx.bezierCurveTo(s * k, s,
                        s, s * k, s, 0)
                }

                ctx.lineTo(topSide
                    ? (leftSide ? 0 : s)
                    : (leftSide ? 0 : s),
                    topSide ? 0 : s)
                ctx.closePath()
                ctx.fillStyle = fillColor
                ctx.fill()
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
        InnerCornerWindow { corner: RoundCorner.CornerEnum.TopLeft }
    }
    Variants {
        model: Quickshell.screens
        InnerCornerWindow { corner: RoundCorner.CornerEnum.TopRight }
    }
    Variants {
        model: Quickshell.screens
        InnerCornerWindow { corner: RoundCorner.CornerEnum.BottomLeft }
    }
    Variants {
        model: Quickshell.screens
        InnerCornerWindow { corner: RoundCorner.CornerEnum.BottomRight }
    }
}
