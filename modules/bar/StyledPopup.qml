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
    // Optional rect in hoverTarget-local coordinates. The target itself remains
    // the real visual/source control for output ownership; this rect only narrows
    // tangent placement (for example a right-click point inside a broad Bar zone).
    property var anchorRect: null
    // Some large connected surfaces (notably workspace Overview) should keep
    // their Bar ownership but use the output midpoint for tangent placement.
    // This changes only placement; the real hoverTarget still owns screen,
    // edge, hover-transfer and cross-axis attachment.
    property bool centerOnOutput: false
    property string attachmentEdgeOverride: ""
    property real attachmentThicknessOverride: -1
    property bool hoverActivates: true
    property bool alternativeVisibleCondition: false
    property bool closeOnOutsideClick: false
    property bool keyboardFocus: false
    property bool _bodyHovered: false
    property bool _contentHovered: false
    readonly property bool popupHovered: root._bodyHovered || root._contentHovered
    default property Item contentItem
    property real popupBackgroundMargin: 0
    // Compatibility knob retained for old callers. Placement is now authoritative:
    // every popup automatically joins any Screen Edge its body actually reaches.
    property bool connectAdjacentScreenEdge: false

    // Presentation-only handle for the lazily-created connected surface. This is
    // useful to presentation peers such as the tray focus grab; feature/backend
    // state never depends on this window object.
    property var presentationWindow: null

    readonly property bool _barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool _trailingEdge: Config.options?.bar?.bottom ?? false
    readonly property string _defaultAttachmentEdge: root._barVertical
        ? (root._trailingEdge ? "right" : "left")
        : (root._trailingEdge ? "bottom" : "top")
    readonly property string _attachmentEdge:
        ["top", "bottom", "left", "right"].includes(root.attachmentEdgeOverride)
            ? root.attachmentEdgeOverride : root._defaultAttachmentEdge
    readonly property bool _attachmentVertical:
        root._attachmentEdge === "left" || root._attachmentEdge === "right"
    readonly property bool _attachmentTrailing:
        root._attachmentEdge === "right" || root._attachmentEdge === "bottom"
    // Source controls own tangent placement; the attached surface owns the
    // cross-axis edge. Existing Bar callers keep canonical Bar thickness while
    // Screen Edge callers may provide the physical frame thickness.
    readonly property real _barSurfaceThickness:
        root.attachmentThicknessOverride > 0
            ? root.attachmentThicknessOverride
            : (root._attachmentVertical
                ? Appearance.sizes.verticalBarWidth
                : Appearance.sizes.barHeight)
    readonly property real _contentPadding: 14
    readonly property real _screenEdgeThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    // Caelestia clamps panel tangent placement to the physical border's inner
    // boundary. The old -seamOverlap inset made corner-attached popups sit 2 px
    // inside the frame and changed the apparent fillet geometry.
    readonly property real _popupScreenMargin: root._screenEdgeThickness
    readonly property bool _edgeShadowEnabled:
        Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true
    readonly property real _edgeShadowExtent: Math.max(0, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
    readonly property real _edgeShadowOpacity: Math.max(0, Math.min(1.0,
        Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70)))
    readonly property color _edgeShadowColor:
        ColorUtils.applyAlpha(Appearance.colors.colShadow, root._edgeShadowOpacity)

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
    // Match Caelestia's panel wrappers: one normalized offsetScale drives the
    // whole slide and reverses naturally from its current value. Geometry keeps
    // consuming revealProgress as the inverse for compatibility.
    property real offsetScale: 1
    readonly property real revealProgress: 1 - root.offsetScale

    // Material is the sole supported Global Theme for v1.0. Keep the connected
    // popup surface on the canonical Material palette and radius instead of
    // retaining unreachable alternate-theme branches in the shared popup path.
    readonly property color _surfaceColor: Appearance.colors.colLayer0
    readonly property color _borderColor: Appearance.colors.colLayer0Border
    readonly property real _borderWidth: 0
    // Caelestia PanelBg uses Tokens.rounding.extraLarge (28px at scale 1).
    readonly property real _surfaceRadius: PerimeterTokens.popupRadius

    signal requestClose()

    active: root._anchorReady && (root.requestedVisible || root._lingerVisible)

    function _beginRetract(): void {
        if (!root._lingerVisible)
            return
        root.offsetScale = 1
        if (Appearance.animationsEnabled)
            retractTimer.restart()
        else
            root._lingerVisible = false
    }

    function _syncRequestedVisibility(): void {
        if (root.requestedVisible) {
            const alreadyResident = root._lingerVisible
            hoverTransferTimer.stop()
            retractTimer.stop()
            root._lingerVisible = true
            if (!Appearance.animationsEnabled) {
                root.offsetScale = 0
                return
            }
            if (alreadyResident) {
                // Reverse an in-flight close from its current geometry rather than
                // snapping to zero and replaying the opening animation.
                root.offsetScale = 0
                return
            }
            root.offsetScale = 1
            Qt.callLater(() => {
                if (root.requestedVisible)
                    root.offsetScale = 0
            })
            return
        }

        if (!root._lingerVisible)
            return

        // Bar and popup are separate layer-shell surfaces. Compositors can emit
        // one leave before the matching enter when the pointer crosses their
        // shared seam. Give that hand-off a short grace period so a transient
        // all-false hover state cannot start a retract/reopen oscillation.
        if (root.hoverActivates) {
            hoverTransferTimer.restart()
            return
        }

        root._beginRetract()
    }

    onRequestedVisibleChanged: root._syncRequestedVisibility()
    Component.onCompleted: root._syncRequestedVisibility()

    // Caelestia's wrappers use one default-spatial animation for both enter and
    // exit instead of separate accelerate/decelerate curves. Hadalis already
    // ships the same expressive-default-spatial token as elementMove.
    Behavior on offsetScale {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    // `contentItem` is the default property and accepts only QQuickItem. Keep
    // internal QObject/QWindow helpers on explicit object properties so they are
    // never routed through the popup content contract during type construction.
    property QtObject _hoverTransferTimerObject: Timer {
        id: hoverTransferTimer
        interval: 90
        repeat: false
        onTriggered: {
            if (!root.requestedVisible)
                root._beginRetract()
        }
    }

    property QtObject _retractTimerObject: Timer {
        id: retractTimer
        interval: Math.max(1, Appearance.animation.elementMove.duration + 16)
        repeat: false
        onTriggered: {
            if (!root.requestedVisible && root.offsetScale >= 0.999)
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

        const localX = Number(root.anchorRect?.x ?? 0)
        const localY = Number(root.anchorRect?.y ?? 0)
        const localWidth = Math.max(1,
            Number(root.anchorRect?.width ?? target.width))
        const localHeight = Math.max(1,
            Number(root.anchorRect?.height ?? target.height))
        const mapped = host.mapFromItem(target, localX, localY)
        const thickness = Math.max(1, Number(root._barSurfaceThickness ?? 1))

        // Preserve the source/sub-rect tangent center/extent, but normalize the
        // cross-axis boundary to the real Bar surface. Large surfaces may opt
        // into the output midpoint without replacing the real Bar ownership
        // anchor — important for workspace Overview, which should be visually
        // centered even when the hovered workspace button sits near an edge.
        if (root._attachmentVertical) {
            const barX = root._attachmentTrailing
                ? Math.max(0, outputWidth - thickness) : 0
            const tangentY = root.centerOnOutput
                ? Math.max(0, (outputHeight - localHeight) / 2)
                : mapped.y
            return Qt.rect(barX, tangentY, thickness, localHeight)
        }

        const barY = root._attachmentTrailing
            ? Math.max(0, outputHeight - thickness) : 0
        const tangentX = root.centerOnOutput
            ? Math.max(0, (outputWidth - localWidth) / 2)
            : mapped.x
        return Qt.rect(tangentX, barY, localWidth, thickness)
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
            screenMargin: root._popupScreenMargin
            // Caelestia composes popouts directly into the edge surface. Keep
            // the shared geometry, but remove the detached neck/gap entirely.
            connectorLength: 0
            // Separate layer-shell surfaces cannot reproduce Caelestia's SDF
            // border sink by overlapping under the Bar: the reveal clip would
            // cut that overlap away and leave a pinched shoulder. Start the
            // popup exactly at the attachment boundary so the flattened flare
            // owns the full visible contact width.
            seamOverlap: 0
            progress: root.revealProgress
            devicePixelRatio: popupWindow.devicePixelRatio
        }

        QtObject {
            id: directEdgeAttachment

            readonly property rect body: geometry.bodyRect
            readonly property real epsilon:
                1 / Math.max(1, popupWindow.devicePixelRatio)
            readonly property real margin: geometry.effectiveScreenMargin
            // Detect all output edges from the resting body geometry. A popup
            // moved away from a corner therefore loses that edge join naturally;
            // a wide/tall popup may join multiple Screen Edges if it reaches them.
            readonly property bool atLeft:
                Math.abs(body.x - margin) <= epsilon
            readonly property bool atRight:
                Math.abs((popupWindow.width - margin)
                    - (body.x + body.width)) <= epsilon
            readonly property bool atTop:
                Math.abs(body.y - margin) <= epsilon
            readonly property bool atBottom:
                Math.abs((popupWindow.height - margin)
                    - (body.y + body.height)) <= epsilon
        }

        // Fixed resting-edge viewport: the full popup translates behind this
        // clip, so closing/opening reads as sliding underneath the Bar/Screen Edge.
        ConnectedSurfaceRevealClip {
            id: popupRevealClip
            geometry: geometry

            ConnectedSurfaceFrame {
                id: frame
                anchors.fill: parent
                geometry: geometry
                fillColor: root._surfaceColor
                borderColor: root._borderColor
                borderWidth: root._borderWidth
                connectorBorderWidth: 0
                connectorVisible: false
                // Own hover on the complete popup body, including its visual
                // padding, but not on the reveal viewport's empty screen area.
                // This closes the Bar→popup dead zone without turning the whole
                // inward half of the output into a hover bridge.
                hoverEnabled: root.active
                onBodyHoveredChanged: root._bodyHovered = bodyHovered
                shadowEnabled: root._edgeShadowEnabled
                    && root._edgeShadowExtent > 0
                    && root._edgeShadowOpacity > 0
                shadowExtent: root._edgeShadowExtent
                shadowColor: root._edgeShadowColor
                joinTop: root._attachmentEdge === "top"
                    || directEdgeAttachment.atTop
                joinBottom: root._attachmentEdge === "bottom"
                    || directEdgeAttachment.atBottom
                joinLeft: root._attachmentEdge === "left"
                    || directEdgeAttachment.atLeft
                joinRight: root._attachmentEdge === "right"
                    || directEdgeAttachment.atRight
                shadowTop: !frame.joinTop
                shadowBottom: !frame.joinBottom
                shadowLeft: !frame.joinLeft
                shadowRight: !frame.joinRight
            }

            ConnectedSurfaceContentHost {
                id: popupContentHost
                geometry: geometry
                padding: root._contentPadding
                // Pure slide-under motion: no scale/shrink and no staged fade.
                opacity: 1
                children: [root.contentItem]

                // Track the actual content plane as well as the decorative body.
                // Interactive children (notably StyledSwitch/MouseArea controls)
                // sit above ConnectedSurfaceFrame and can otherwise make the
                // frame's HoverHandler report a transient leave while the pointer
                // is still visibly inside the popup, causing retract/reopen jitter.
                HoverHandler {
                    enabled: root.active
                    onHoveredChanged: root._contentHovered = hovered
                }
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
