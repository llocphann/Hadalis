import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.perimeter
import qs.services

Scope {
    id: root
    
    // Toast queue
    property var toasts: []
    property int maxToasts: 5
    property int toastSpacing: 8
    readonly property bool suppressOnScreenToasts: (GameMode?.active ?? false) || (GameMode?.hasAnyFullscreenWindow ?? false)
    readonly property real screenEdgeThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
    readonly property bool topBarOwnsEdge:
        (Config.options?.panelFamily ?? "ii") === "ii"
        && !(Config.options?.bar?.vertical ?? false)
        && !(Config.options?.bar?.bottom ?? false)
        && GlobalStates.barOpen
        && !(Config.options?.bar?.autoHide?.enable ?? false)
        && (Config.options?.enabledPanels ?? []).includes("iiBar")
    readonly property real topOwnerThickness: topBarOwnsEdge
        ? Appearance.sizes.barHeight : screenEdgeThickness
    readonly property bool edgeShadowEnabled:
        Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
    readonly property real edgeShadowSize: Math.max(0, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.physicalShadow?.size ?? 15)))
    readonly property real edgeShadowOpacity: Math.max(0, Math.min(1.0,
        Number(Config.options?.appearance?.screenEdge?.physicalShadow?.opacity ?? 0.70)))
    readonly property color edgeShadowColor:
        Qt.alpha(Appearance.m3colors.m3shadow, root.edgeShadowOpacity)
    readonly property real edgeDecorationMargin: Math.max(
        8,
        PerimeterTokens.irisFuseDepth,
        root.edgeShadowEnabled ? root.edgeShadowSize + 2 : 0)
    readonly property real toastBodyPadding: 8
    
    // Unified reload tracking - only show ONE toast per reload event
    property real _lastReloadToastTime: 0
    property string _pendingReloadSource: ""  // "quickshell", "niri", or ""
    readonly property int _reloadDebounceMs: 800   // Wait this long to coalesce events
    readonly property int _reloadCooldownMs: 2500  // Minimum time between reload toasts
    
    // Track if we're in the middle of a QS reload (suppresses Niri toast)
    property bool _qsReloadInProgress: false
    
    // Check if reload toasts should be shown
    function shouldShowReloadToast(): bool {
        if (Config.isSettingsProcess) return false
        if (!(Config.options?.reloadToasts?.enable ?? true)) return false
        
        if (GameMode.disableReloadToasts && (GameMode.active || GameMode.hasAnyFullscreenWindow || GameMode.suppressNiriToast)) {
            return false
        }
        
        return true
    }
    
    function addToast(title, message, icon, isError, duration, source, accentColor) {
        // Prevent duplicates: if same source and title already visible, ignore
        if (toasts.some(t => t.source === source && t.title === title)) {
            return
        }
        
        const toast = {
            id: Date.now(),
            title: title,
            message: message || "",
            icon: icon || (isError ? "error" : "check_circle"),
            isError: isError || false,
            duration: duration || (isError ? 6000 : 2000),
            source: source || "system",
            accentColor: accentColor || Appearance.colors.colPrimary
        }
        
        toasts = [...toasts, toast]
        
        if (toasts.length > maxToasts) {
            toasts = toasts.slice(-maxToasts)
        }
        
        popupLoader.loading = true
    }
    
    function removeToast(id) {
        toasts = toasts.filter(t => t.id !== id)
        if (toasts.length === 0) {
            popupLoader.active = false
        }
    }
    
    // Show the pending reload toast
    function _showReloadToast() {
        if (!root._pendingReloadSource) return
        if (!root.shouldShowReloadToast()) {
            root._pendingReloadSource = ""
            return
        }
        
        const now = Date.now()
        // Check cooldown
        if (now - root._lastReloadToastTime < root._reloadCooldownMs) {
            root._pendingReloadSource = ""
            return
        }
        
        root._lastReloadToastTime = now
        const source = root._pendingReloadSource
        root._pendingReloadSource = ""
        
        if (source === "quickshell") {
            root.addToast(
                "Quickshell reloaded",
                "",
                "refresh",
                false,
                2000,
                "reload",
                Appearance.colors.colPrimary
            )
        } else if (source === "niri") {
            root.addToast(
                "Niri Reloaded",
                "",
                "settings",
                false,
                2000,
                "reload",
                Appearance.colors.colTertiary
            )
        }
    }
    
    // Single debounce timer for all reload events
    Timer {
        id: reloadDebounce
        interval: root._reloadDebounceMs
        onTriggered: {
            root._qsReloadInProgress = false
            root._showReloadToast()
        }
    }
    
    // Timer to clear QS reload flag after a longer period
    Timer {
        id: qsReloadClearTimer
        interval: 2000  // 2 seconds after QS reload, allow Niri toasts again
        onTriggered: {
            root._qsReloadInProgress = false
        }
    }

    // Quickshell reload signals
    Connections {
        target: Quickshell
        
        function onReloadCompleted() {
            // Mark that QS is reloading - this suppresses Niri toasts
            root._qsReloadInProgress = true
            qsReloadClearTimer.restart()
            
            // Quickshell reload takes priority
            root._pendingReloadSource = "quickshell"
            reloadDebounce.restart()
        }
        
        function onReloadFailed(error) {
            root._qsReloadInProgress = false
            root.addToast(
                "Quickshell reload failed",
                error,
                "error",
                true,
                8000,
                "error",
                Appearance.colors.colError
            )
        }
    }
    
    // Niri config reload signals
    Connections {
        target: NiriService
        
        function onConfigLoadFinished(ok, error) {
            if (ok) {
                // If QS just reloaded, ignore Niri's ConfigLoaded (it's from reconnection)
                if (root._qsReloadInProgress) {
                    return
                }
                
                // Only set pending if not already set to quickshell
                if (root._pendingReloadSource !== "quickshell") {
                    root._pendingReloadSource = "niri"
                    reloadDebounce.restart()
                }
            } else {
                // Errors always show immediately
                root.addToast(
                    "Niri config reload failed",
                    error || "Run 'niri validate' for details",
                    "error",
                    true,
                    8000,
                    "error",
                    Appearance.colors.colError
                )
            }
        }
    }
    
    LazyLoader {
        id: popupLoader
        
        PanelWindow {
            id: popup
            visible: root.toasts.length > 0 && !root.suppressOnScreenToasts
            // Visual-only Overlay: never set exclusiveZone here. Quickshell's
            // exclusiveZone setter switches exclusionMode back to Normal,
            // which made Niri configure this window to the remaining work area
            // instead of the physical output.
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:toast-manager"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            // Mirror BatteryPopup/StyledPopup production geometry. A one-pixel
            // logical anchor at the Bar's top-right edge is enough to make the
            // shared geometry clamp the body to the right Screen Edge while the
            // top owner remains the full Bar (or Screen Edge fallback).
            ConnectedSurfaceGeometry {
                id: toastGeometry
                edge: "top"
                alignment: "end"
                outputRect: Qt.rect(0, 0, popup.width, popup.height)
                anchorRect: Qt.rect(
                    Math.max(0, popup.width - root.screenEdgeThickness - 1),
                    0,
                    1,
                    root.topOwnerThickness)
                bodySize: Qt.size(
                    Math.max(1, toastColumn.implicitWidth
                        + root.toastBodyPadding * 2),
                    Math.max(1, toastColumn.implicitHeight
                        + root.toastBodyPadding * 2))
                outerRadius: PerimeterTokens.popupRadius
                screenMargin: root.screenEdgeThickness
                connectorLength: 0
                seamOverlap: PerimeterTokens.irisWeldDepth
                progress: 1
                devicePixelRatio: popup.devicePixelRatio
            }

            ConnectedSurfaceRevealClip {
                id: toastRevealClip
                geometry: toastGeometry

                ConnectedSurfaceIrisFrame {
                    id: toastFrame
                    anchors.fill: parent
                    geometry: toastGeometry
                    fillColor: Appearance.colors.colLayer0
                    borderColor: Appearance.colors.colLayer0Border
                    borderWidth: 0
                    fuseDepth: PerimeterTokens.irisFuseDepth
                    externalFrameThickness: root.screenEdgeThickness
                    shadowEnabled: root.edgeShadowEnabled
                        && root.edgeShadowSize > 0
                        && root.edgeShadowOpacity > 0
                    shadowExtent: root.edgeShadowSize
                    shadowColor: root.edgeShadowColor
                    joinTop: true
                    joinRight: true
                }

                ConnectedSurfaceContentHost {
                    id: toastContentHost
                    geometry: toastGeometry
                    padding: root.toastBodyPadding

                    ColumnLayout {
                        id: toastColumn
                        anchors.fill: parent
                        spacing: root.toastSpacing

                        Repeater {
                            model: root.toasts

                            delegate: ToastNotification {
                                required property var modelData
                                required property int index

                                connectedSurface: true
                                title: modelData.title
                                message: modelData.message
                                icon: modelData.icon
                                isError: modelData.isError
                                duration: modelData.duration
                                source: modelData.source
                                accentColor: modelData.accentColor

                                opacity: 1
                                scale: 1

                                Component.onCompleted: {
                                    if (Appearance.animationsEnabled)
                                        entryAnim.start()
                                }

                                ParallelAnimation {
                                    id: entryAnim
                                    NumberAnimation {
                                        target: parent
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                    NumberAnimation {
                                        target: parent
                                        property: "scale"
                                        from: 0.9
                                        to: 1
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }

                                onDismissed: {
                                    if (Appearance.animationsEnabled)
                                        exitAnim.start()
                                    else
                                        root.removeToast(modelData.id)
                                }

                                ParallelAnimation {
                                    id: exitAnim
                                    NumberAnimation {
                                        target: parent
                                        property: "opacity"
                                        to: 0
                                        duration: Appearance.animation.elementMoveExit.duration
                                        easing.type: Appearance.animation.elementMoveExit.type
                                        easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                                    }
                                    NumberAnimation {
                                        target: parent
                                        property: "scale"
                                        to: 0.9
                                        duration: Appearance.animation.elementMoveExit.duration
                                        easing.type: Appearance.animation.elementMoveExit.type
                                        easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                                    }
                                    onFinished: root.removeToast(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            ConnectedSurfaceBodyMask {
                id: toastMask
                geometry: toastGeometry
                bodyItem: toastFrame.bodyItem
                visibleBodyRect: toastFrame.visibleBodyRect
                inputEnabled: popup.visible
            }

            mask: toastMask
        }
    }
}
