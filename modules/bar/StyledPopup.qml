import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.perimeter
import QtQuick
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    property bool hoverActivates: true
    property bool alternativeVisibleCondition: false
    property bool closeOnOutsideClick: false
    property bool keyboardFocus: false
    property bool popupHovered: false
    default property Item contentItem
    property real popupBackgroundMargin: 0

    // Presentation-only handle for the lazily-created connected surface. This is
    // useful to presentation peers such as the tray focus grab; feature/backend
    // state never depends on this window object.
    property var presentationWindow: null

    readonly property bool _barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool _trailingEdge: Config.options?.bar?.bottom ?? false
    readonly property string _attachmentEdge: root._barVertical
        ? (root._trailingEdge ? "right" : "left")
        : (root._trailingEdge ? "bottom" : "top")
    readonly property real _contentPadding: 14

    // The visual anchor is the authority for output/window ownership. StyledPopup
    // itself is a LazyLoader and is not a visual child of the bar, so resolving
    // QsWindow from the loader can point at no window at all. Keeping placement,
    // screen selection and geometry attached to the actual source Item mirrors the
    // layer-surface model used by edge shells: a full-output presentation window
    // with a shape-aware input region, driven by a control already on that output.
    readonly property var _anchorWindow: root.hoverTarget
        ? root.hoverTarget.QsWindow.window : null
    readonly property var _anchorScreen: root._anchorWindow
        ? root._anchorWindow.screen : null
    readonly property bool _anchorReady: root.hoverTarget !== null
        && root._anchorWindow !== null
        && root._anchorScreen !== null
        && root.hoverTarget.width > 0
        && root.hoverTarget.height > 0

    // Keep the loader resident for the reverse morph. `requestedVisible` is the
    // semantic popup state; `active` includes only the short retract tail. While
    // hover-activated, the body itself also counts as the request so the pointer
    // can travel from the bar through the connected shoulder without collapse.
    readonly property bool requestedVisible: root.alternativeVisibleCondition
        || (root.hoverActivates && (
            (root.hoverTarget
                && (root.hoverTarget.containsMouse ?? root.hoverTarget.buttonHovered ?? false))
            || root.popupHovered))
    property bool _lingerVisible: false
    property real revealProgress: 0

    // Material is the sole supported Global Theme for v1.0. Keep the connected
    // popup surface on the canonical Material palette and radius instead of
    // retaining unreachable alternate-theme branches in the shared popup path.
    readonly property color _surfaceColor: Appearance.colors.colLayer0
    readonly property color _borderColor: Appearance.colors.colLayer0Border
    readonly property real _borderWidth: 0
    readonly property real _surfaceRadius: Appearance.rounding.large

    signal requestClose()

    active: root._anchorReady && (root.requestedVisible || root._lingerVisible)

    function _syncRequestedVisibility(): void {
        if (root.requestedVisible) {
            const alreadyResident = root._lingerVisible
            retractTimer.stop()
            root._lingerVisible = true
            if (!Appearance.animationsEnabled) {
                root.revealProgress = 1
                return
            }
            if (alreadyResident) {
                // Reverse an in-flight close from its current geometry rather than
                // snapping to zero and replaying the opening animation.
                root.revealProgress = 1
                return
            }
            root.revealProgress = 0
            Qt.callLater(() => {
                if (root.requestedVisible)
                    root.revealProgress = 1
            })
            return
        }

        root.popupHovered = false
        if (!root._lingerVisible)
            return
        root.revealProgress = 0
        if (Appearance.animationsEnabled)
            retractTimer.restart()
        else
            root._lingerVisible = false
    }

    onRequestedVisibleChanged: root._syncRequestedVisibility()
    Component.onCompleted: root._syncRequestedVisibility()

    Behavior on revealProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    // `contentItem` is the default property and accepts only QQuickItem. Keep
    // internal QObject/QWindow helpers on explicit object properties so they are
    // never routed through the popup content contract during type construction.
    property QtObject _retractTimerObject: Timer {
        id: retractTimer
        interval: Math.max(1, Appearance.animation.elementMoveEnter.duration + 16)
        repeat: false
        onTriggered: {
            if (!root.requestedVisible && root.revealProgress <= 0.001)
                root._lingerVisible = false
        }
    }

    function _anchorRect(outputWidth, outputHeight) {
        const target = root.hoverTarget
        const host = target ? target.QsWindow : null
        const hostWindow = root._anchorWindow
        if (!target || !host || !hostWindow || !root._anchorScreen
                || target.width <= 0 || target.height <= 0
                || outputWidth <= 0 || outputHeight <= 0)
            return Qt.rect(0, 0, 0, 0)

        // mapFromItem() is intentionally non-reactive in Quickshell. Touch both
        // the item geometry and QsWindow.windowTransform so monitor transforms,
        // bar moves, scale changes and hotplug force this binding to recompute.
        target.x
        target.y
        target.width
        target.height
        hostWindow.windowTransform
        const mapped = host.mapFromItem(target, 0, 0)
        let x = mapped.x
        let y = mapped.y

        // Horizontal bars already span the output width, while vertical bars
        // span its height. Translate the cross-axis coordinate for bottom/right
        // placement so ConnectedSurfaceGeometry always receives output-local
        // coordinates, independent of the layer-shell window's anchored edge.
        if (root._barVertical) {
            if (root._trailingEdge)
                x += Math.max(0, outputWidth - Number(hostWindow.width ?? 0))
        } else if (root._trailingEdge) {
            y += Math.max(0, outputHeight - Number(hostWindow.height ?? 0))
        }

        return Qt.rect(x, y, target.width, target.height)
    }

    // Fullscreen transparent backdrop for Niri to detect clicks outside
    // (same pattern as ContextMenu / SysTrayMenu). It disappears as soon as the
    // semantic popup closes while the visual surface is allowed to retract.
    property QtObject _clickOutsideBackdropObject: PanelWindow {
        id: clickOutsideBackdrop
        visible: root._anchorReady && root.requestedVisible && root.closeOnOutsideClick
        screen: root._anchorScreen
        color: Qt.rgba(0, 0, 0, 1/255)
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:popup-catcher"
        anchors { top: true; bottom: true; left: true; right: true }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.requestClose()
        }
    }

    component: PanelWindow {
        id: popupWindow

        screen: root._anchorScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        visible: root.active
        focusable: root.keyboardFocus && root.requestedVisible

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keyboardFocus && root.requestedVisible
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Component.onCompleted: root.presentationWindow = popupWindow
        Component.onDestruction: {
            if (root.presentationWindow === popupWindow)
                root.presentationWindow = null
        }

        // Hyprland still needs an explicit grab for keyboard-driven popouts;
        // Niri uses the layer-shell focus mode above. Keep the behavior inside
        // the shared popup so focused surfaces (notably Media) do not fall back
        // to a detached-window implementation just to own keyboard focus.
        CompositorFocusGrab {
            active: root.keyboardFocus && root.requestedVisible
            windows: [popupWindow]
            onCleared: root.requestClose()
        }

        ConnectedSurfaceGeometry {
            id: geometry
            edge: root._attachmentEdge
            alignment: "center"
            outputRect: Qt.rect(0, 0, popupWindow.width, popupWindow.height)
            anchorRect: root._anchorRect(popupWindow.width, popupWindow.height)
            bodySize: Qt.size(
                Math.max(1, (root.contentItem?.implicitWidth ?? 0)
                    + root._contentPadding * 2 + Math.max(0, root.popupBackgroundMargin)),
                Math.max(1, (root.contentItem?.implicitHeight ?? 0)
                    + root._contentPadding * 2 + Math.max(0, root.popupBackgroundMargin)))
            outerRadius: root._surfaceRadius
            progress: root.revealProgress
            devicePixelRatio: popupWindow.devicePixelRatio
        }

        ConnectedSurfaceFrame {
            id: frame
            anchors.fill: parent
            geometry: geometry
            fillColor: root._surfaceColor
            borderColor: root._borderColor
            borderWidth: root._borderWidth
            // The connector owns the join. Leaving its outline off lets the
            // shoulder merge into both bar and body instead of drawing a stem.
            connectorBorderWidth: 0
        }

        ConnectedSurfaceContentHost {
            id: popupContentHost
            geometry: geometry
            padding: root._contentPadding
            // Let the surface deform first, then bring content in as the body has
            // enough area. This keeps the enter motion from reading as card fade.
            opacity: Math.max(0, Math.min(1,
                (geometry.revealProgress - 0.18) / 0.82))
            children: [root.contentItem]

            HoverHandler {
                id: popupHoverHandler
                enabled: root.active
                onHoveredChanged: root.popupHovered = hovered
            }
        }

        ConnectedSurfaceMask {
            id: connectedMask
            geometry: geometry
            bodyItem: frame.bodyItem
            connectorItem: frame.connectorItem
            inputEnabled: root.requestedVisible
                || (root.hoverActivates && root._lingerVisible)
        }

        mask: connectedMask
    }
}
