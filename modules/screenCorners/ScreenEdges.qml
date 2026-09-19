pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.perimeter
import qs.services
import qs.modules.waffle.looks as WaffleLooks
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Physical Screen Edge renderer.
//
// SCREEN-EDGE-GEOMETRY-LOCK (maintainer approved 2026-09-19):
// BAR-SCREEN-EDGE-CORNER-LOCK (maintainer approved 2026-09-19):
// The current Screen Edge + normal ii Bar silhouette is the canonical Hadalis
// physical perimeter. Screen Edge and Bar endpoint corners are one geometry:
// the single inverted rounded workspace hole below. Future refactors must keep
// this exact ownership/placement/path model. The only approved visual degree of
// freedom is PerimeterTokens.frameRadius (user setting). If any later change
// distorts top/bottom/left/right corners, restore this model rather than adding
// Bar-local radii, RoundCorner wedges, edge patches or a second renderer.
// Change either lock only with explicit maintainer approval.
//
// Caelestia does not build its border from four strips plus corner patches.
// Its idle border is one inverted rounded rectangle: the window bounds are the
// outer rect and the workspace is one rounded inner hole. Hadalis mirrors that
// geometry here with one ShapePath / OddEvenFill per output. The four thin
// ReservationWindow surfaces below are transparent and exist only to reserve
// compositor work-area space; they do not paint any Screen Edge pixels.
Scope {
    id: root

    // Caelestia BorderConfig defaults: thickness=10, rounding=25. The
    // maintainer-approved geometry model stays locked, while the radius itself
    // is now the shared user-adjustable perimeter token.
    readonly property int thickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property real rounding: PerimeterTokens.frameRadius

    // Physical Screen Edge shadow has its own config owner. Do not reuse
    // appearance.screenEdge.shadow: that key belongs to connected popup/sidebar
    // body shadows and must never change the physical perimeter effect.
    readonly property bool physicalShadowEnabled:
        Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
    readonly property int physicalShadowSize: Math.max(0, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.physicalShadow?.size ?? 15)))
    readonly property real physicalShadowOpacity: Math.max(0, Math.min(1.0,
        Number(Config.options?.appearance?.screenEdge?.physicalShadow?.opacity ?? 0.70)))

    // Caelestia's BlobInvertedRect extends 50px beyond the ContentWindow so the
    // visible outer screen boundary is clipped by the window rather than by an
    // antialiased shape edge. Keep the same construction.
    readonly property int outerPadding: 50

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

    function iiBarOwnsEdge(outputName, edge) {
        if (!GlobalStates.barOpen || GlobalStates.widgetEditMode)
            return false

        // Auto-hide deliberately hands the physical edge back to ScreenEdges so
        // the persistent frame remains the visible baseline while the Bar moves.
        return !root.waffleFamily
            && root.iiBarPanelEnabled
            && !(Config.options?.bar?.autoHide?.enable ?? false)
            && edge === root.iiBarEdge
            && root.iiBarTargetsOutput(outputName)
    }

    function barOwnsEdge(outputName, edge) {
        if (!GlobalStates.barOpen || GlobalStates.widgetEditMode)
            return false

        const iiOwned = root.iiBarOwnsEdge(outputName, edge)
        const waffleOwned = root.waffleBarPanelEnabled
            && edge === root.waffleBarEdge
            && root.waffleBarTargetsOutput(outputName)
        return iiOwned || waffleOwned
    }

    component FrameWindow: PanelWindow {
        id: frameWindow

        required property ShellScreen modelData

        readonly property string outputName: String(modelData?.name ?? "")
        readonly property bool fullscreenCovered: outputName.length > 0
            && GameMode.hasFullscreenOnOutput(outputName)
        readonly property bool mapped: Config.ready
            && !GlobalStates.screenLocked
            && !fullscreenCovered

        // LOCKED BAR/SCREEN-EDGE INSETS:
        // Caelestia treats the Bar as a thicker side of the same inverted
        // border. When a normal ii Bar owns an edge, only that one inset changes
        // from Screen Edge thickness to the real Bar body thickness. These four
        // formulas are part of BAR-SCREEN-EDGE-CORNER-LOCK and must remain
        // orientation-symmetric. No Bar-local corner paint may replace them.
        readonly property real frameLeftInset:
            root.iiBarOwnsEdge(outputName, "left")
                ? Appearance.sizes.verticalBarWidth : root.thickness
        readonly property real frameRightInset:
            root.iiBarOwnsEdge(outputName, "right")
                ? Appearance.sizes.verticalBarWidth : root.thickness
        readonly property real frameTopInset:
            root.iiBarOwnsEdge(outputName, "top")
                ? Appearance.sizes.barHeight : root.thickness
        readonly property real frameBottomInset:
            root.iiBarOwnsEdge(outputName, "bottom")
                ? Appearance.sizes.barHeight : root.thickness

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        // Visual host must ignore all exclusive zones and remain pinned to the
        // physical output bounds, matching Caelestia ContentWindow.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "hadalis:screen-edge-frame"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: emptyFrameInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyFrameInput }

        // LOCKED CORNER GEOMETRY: exactly one painted geometry. Odd-even fill
        // subtracts the rounded workspace rect from the padded outer rect,
        // matching the isolated Caelestia BlobInvertedRect border silhouette.
        // Do not split this into edge/corner renderers or add painted helpers.
        Shape {
            id: frameShape
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            // One geometry, one effect. This is attached directly to the locked
            // frame Shape, so there is no second painted item, overlay, wedge,
            // corner patch or shadow rectangle. At the defaults this matches
            // Caelestia ContentWindow: blurMax=15 and m3shadow alpha=0.70.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: root.physicalShadowEnabled
                    && root.physicalShadowSize > 0
                    && root.physicalShadowOpacity > 0
                blurMax: Math.max(1, root.physicalShadowSize)
                shadowColor: Qt.alpha(
                    Appearance.m3colors.m3shadow,
                    root.physicalShadowOpacity)
            }

            ShapePath {
                id: framePath

                fillColor: root.edgeColor
                fillRule: ShapePath.OddEvenFill
                strokeColor: "transparent"
                strokeWidth: -1

                readonly property real innerLeft: frameWindow.frameLeftInset
                readonly property real innerTop: frameWindow.frameTopInset
                readonly property real innerRight:
                    frameShape.width - frameWindow.frameRightInset
                readonly property real innerBottom:
                    frameShape.height - frameWindow.frameBottomInset
                readonly property real r: Math.max(0, Math.min(root.rounding,
                    Math.max(0, innerRight - innerLeft) / 2,
                    Math.max(0, innerBottom - innerTop) / 2))

                // Outer rectangle. Deliberately extends past the window just as
                // Caelestia's BlobInvertedRect uses anchors.margins: -50.
                startX: -root.outerPadding
                startY: -root.outerPadding
                PathLine {
                    x: frameShape.width + root.outerPadding
                    y: -root.outerPadding
                }
                PathLine {
                    x: frameShape.width + root.outerPadding
                    y: frameShape.height + root.outerPadding
                }
                PathLine {
                    x: -root.outerPadding
                    y: frameShape.height + root.outerPadding
                }
                PathLine {
                    x: -root.outerPadding
                    y: -root.outerPadding
                }

                // Single rounded inner workspace hole. With no normal Bar,
                // every side inset is the Screen Edge thickness. When the ii Bar
                // owns top/bottom/left/right, only that side inset becomes the
                // Bar body thickness — the same ContentWindow/BlobInvertedRect
                // principle Caelestia uses for its Bar edge.
                PathMove {
                    x: framePath.innerLeft + framePath.r
                    y: framePath.innerTop
                }
                PathLine {
                    x: framePath.innerRight - framePath.r
                    y: framePath.innerTop
                }
                PathArc {
                    x: framePath.innerRight
                    y: framePath.innerTop + framePath.r
                    radiusX: framePath.r
                    radiusY: framePath.r
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: framePath.innerRight
                    y: framePath.innerBottom - framePath.r
                }
                PathArc {
                    x: framePath.innerRight - framePath.r
                    y: framePath.innerBottom
                    radiusX: framePath.r
                    radiusY: framePath.r
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: framePath.innerLeft + framePath.r
                    y: framePath.innerBottom
                }
                PathArc {
                    x: framePath.innerLeft
                    y: framePath.innerBottom - framePath.r
                    radiusX: framePath.r
                    radiusY: framePath.r
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: framePath.innerLeft
                    y: framePath.innerTop + framePath.r
                }
                PathArc {
                    x: framePath.innerLeft + framePath.r
                    y: framePath.innerTop
                    radiusX: framePath.r
                    radiusY: framePath.r
                    direction: PathArc.Clockwise
                }
            }
        }
    }

    // Transparent compositor reservation only. ScreenEdge pixels are never
    // painted here, so these windows cannot alter the frame/corner silhouette.
    component ReservationWindow: PanelWindow {
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
        // Reservation surfaces intentionally participate in normal layer-shell
        // exclusion. Do not set Ignore here: their only job is to reserve the
        // configured Screen Edge thickness for client windows.
        exclusiveZone: mapped ? root.thickness : 0

        implicitWidth: horizontal ? 1 : root.thickness
        implicitHeight: horizontal ? root.thickness : 1

        WlrLayershell.namespace: "hadalis:screen-edge-reservation-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: edge === "top" || edge === "left" || edge === "right"
            bottom: edge === "bottom" || edge === "left" || edge === "right"
            left: edge === "left" || edge === "top" || edge === "bottom"
            right: edge === "right" || edge === "top" || edge === "bottom"
        }

        Item {
            id: emptyReservationInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyReservationInput }
    }

    Variants {
        model: Quickshell.screens
        FrameWindow {}
    }

    Variants {
        model: Quickshell.screens
        ReservationWindow { edge: "top" }
    }
    Variants {
        model: Quickshell.screens
        ReservationWindow { edge: "bottom" }
    }
    Variants {
        model: Quickshell.screens
        ReservationWindow { edge: "left" }
    }
    Variants {
        model: Quickshell.screens
        ReservationWindow { edge: "right" }
    }
}
