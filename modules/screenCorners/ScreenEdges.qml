pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
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
    readonly property color edgeColor: Appearance.colors.colLayer0
    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property string barEdge: barVertical
        ? ((Config.options?.bar?.bottom ?? false) ? "right" : "left")
        : ((Config.options?.bar?.bottom ?? false) ? "bottom" : "top")
    readonly property string barPanelId: barVertical ? "iiVerticalBar" : "iiBar"
    readonly property bool barPanelEnabled:
        (Config.options?.enabledPanels ?? []).includes(barPanelId)

    function barTargetsOutput(outputName) {
        if (outputName.length === 0)
            return false
        const list = Config.options?.bar?.screenList ?? []
        if (!list || list.length === 0)
            return true
        const matched = Quickshell.screens.filter(screen => {
            const screenName = String(screen?.name ?? "")
            return screenName.length > 0 && list.includes(screenName)
        })
        // Keep ownership identical to Bar.qml / VerticalBar.qml. If saved output
        // names are stale, both bar and edge policy fall back to all screens.
        if (matched.length === 0)
            return true
        return list.includes(outputName)
    }

    function barOwnsEdge(outputName, edge) {
        return root.barPanelEnabled
            && GlobalStates.barOpen
            && edge === root.barEdge
            && root.barTargetsOutput(outputName)
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
        exclusiveZone: 0
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
            anchors.fill: parent
            color: root.edgeColor
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

        RoundCorner {
            implicitSize: root.innerRadius
            corner: cornerWindow.corner
            color: root.edgeColor
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
