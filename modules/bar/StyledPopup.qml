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

    readonly property bool _barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool _trailingEdge: Config.options?.bar?.bottom ?? false
    readonly property string _attachmentEdge: root._barVertical
        ? (root._trailingEdge ? "right" : "left")
        : (root._trailingEdge ? "bottom" : "top")
    readonly property int _barCornerStyle: Config.options?.bar?.cornerStyle ?? 0
    readonly property bool _barFloatingSurface: root._barCornerStyle === 1 || root._barCornerStyle === 3
    readonly property real _contentPadding: 14

    // Caelestia's popouts read as deformations of the owning shell surface, not
    // as a separate card material. Match the Classic Bar's surface family here
    // so the flared connector and body visually continue the bar.
    readonly property color _surfaceColor: Appearance.zzzEverywhere
        ? (root._barCornerStyle === 3 ? Appearance.zzz.chromeAlt : Appearance.zzz.chrome)
        : Appearance.regaliaEverywhere
            ? (root._barFloatingSurface
                ? Appearance.regalia.barSurfaceFloating
                : Appearance.regalia.barSurface)
        : Appearance.angelEverywhere
            ? (Appearance.wallpaperBlendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere
            ? (Appearance.wallpaperBlendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        : root._barCornerStyle === 3 ? Appearance.colors.colLayer1
        : Appearance.colors.colLayer0
    readonly property color _borderColor: Appearance.zzzEverywhere
        ? Appearance.zzz.hairline
        : Appearance.regaliaEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
        : Appearance.colors.colLayer0Border
    readonly property real _borderWidth: Appearance.zzzEverywhere ? 1
        : Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth
        : 0
    readonly property real _surfaceRadius: Appearance.zzzEverywhere
        ? Appearance.zzz.panelRadius
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundLarge
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.large

    signal requestClose()

    active: root.alternativeVisibleCondition
        || (root.hoverActivates && hoverTarget
            && (hoverTarget.containsMouse ?? hoverTarget.buttonHovered ?? false))
    onActiveChanged: {
        if (!root.active)
            root.popupHovered = false
    }

    function _anchorRect(outputWidth, outputHeight) {
        const target = root.hoverTarget
        const host = root.QsWindow
        const hostWindow = host?.window ?? null
        if (!target || !host || !hostWindow
                || target.width <= 0 || target.height <= 0
                || outputWidth <= 0 || outputHeight <= 0)
            return Qt.rect(0, 0, 0, 0)

        // Explicitly touch the target geometry so this binding is refreshed when
        // bar modules are rearranged or resized. mapFromItem() then supplies the
        // precise tangent coordinate inside the owning bar window.
        target.x
        target.y
        target.width
        target.height
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
    // (same pattern as ContextMenu / SysTrayMenu). The connected popup itself
    // remains click-through outside its body+connector mask.
    PanelWindow {
        id: clickOutsideBackdrop
        visible: root.active && root.closeOnOutsideClick
        screen: root.QsWindow.window?.screen ?? null
        color: Qt.rgba(0, 0, 0, 1/255)
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:popup-catcher"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.requestClose()
        }
    }

    component: PanelWindow {
        id: popupWindow

        property real revealProgress: 0

        screen: root.QsWindow.window?.screen ?? null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        visible: root.active
        focusable: root.keyboardFocus

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keyboardFocus
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Component.onCompleted: revealProgress = 1

        Behavior on revealProgress {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        // Hyprland still needs an explicit grab for keyboard-driven popouts;
        // Niri uses the layer-shell focus mode above. Keep the behavior inside
        // the shared popup so focused surfaces (notably Media) do not fall back
        // to a detached-window implementation just to own keyboard focus.
        CompositorFocusGrab {
            active: root.keyboardFocus && root.active
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
            progress: popupWindow.revealProgress
            devicePixelRatio: popupWindow.screen?.devicePixelRatio ?? 1
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

        Item {
            id: popupContentHost
            x: geometry.animatedBodyRect.x + root._contentPadding
            y: geometry.animatedBodyRect.y + root._contentPadding
            width: Math.max(0, geometry.animatedBodyRect.width - root._contentPadding * 2)
            height: Math.max(0, geometry.animatedBodyRect.height - root._contentPadding * 2)
            visible: geometry.valid && geometry.progress > 0
            // Let the surface deform first, then bring content in as the body has
            // enough area. This keeps the enter motion from reading as card fade.
            opacity: Math.max(0, Math.min(1,
                (geometry.revealProgress - 0.18) / 0.82))
            clip: true
            children: [root.contentItem]

            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: root.popupHovered = hovered
            }
        }

        ConnectedSurfaceMask {
            id: connectedMask
            geometry: geometry
            bodyItem: frame.bodyItem
            connectorItem: frame.connectorItem
        }

        mask: connectedMask
    }
}
