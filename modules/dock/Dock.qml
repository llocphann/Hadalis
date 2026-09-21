pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.perimeter
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Scope {
    id: root
    property bool pinned: (Config.options?.dock?.pinnedOnStartup ?? false)
        && !(Config.options?.dock?.hoverToReveal ?? false)
    readonly property string position: Config.options?.dock?.position ?? "bottom"
    readonly property bool isVertical: root.position === "left" || root.position === "right"
    readonly property bool isTop: root.position === "top"
    readonly property bool isLeft: root.position === "left"
    // Reload only when the Bar orientation actually changes. The old
    // bottom !== undefined probe was permanently true because bottom is a
    // schema boolean, so switching horizontal/vertical Bar never changed key.
    readonly property bool barIsVertical: Config.options?.bar?.vertical ?? false
    property string _positionKey: `${root.position}_${barIsVertical}`
    readonly property var targetScreens: {
        const screens = Quickshell.screens
        const list = Config.options?.dock?.screenList ?? []
        if (!list || list.length === 0)
            return screens
        const matchedScreens = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matchedScreens.length > 0 ? matchedScreens : screens
    }

    Variants {
        model: root.targetScreens

        Loader {
            id: panelLoader
            required property var modelData
            active: true

            property string posKey: root._positionKey
            onPosKeyChanged: {
                active = false
                reloadTimer.start()
            }

            Timer {
                id: reloadTimer
                interval: 50
                onTriggered: panelLoader.active = true
            }

            sourceComponent: PanelWindow {
                id: dockRoot
                screen: panelLoader.modelData
                visible: !GlobalStates.screenLocked
                    && !GlobalStates.widgetEditMode

                property bool reveal: !GlobalStates.coverflowSelectorOpen
                    && !(GlobalStates.wallpaperLauncherOpen && root.position === "bottom")
                    && GlobalStates.shellEntryReady
                    && (ShellEditSession.active || root.pinned
                        || (Config.options?.dock?.hoverToReveal && dockMouseArea.containsMouse)
                        || (dockApps?.requestDockShow || dockAppsVertical?.requestDockShow)
                        || (Config.options?.dock?.showOnDesktop !== false
                            && !ToplevelManager.activeToplevel?.activated))

                property real editThicknessPreview: -1
                property real _editResizeBaseline: -1
                readonly property real dockHeight: editThicknessPreview >= 0
                    ? editThicknessPreview
                    : (Config.options?.dock?.height ?? 60)
                readonly property real screenEdgeThickness: Math.max(1, Math.min(32,
                    Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
                readonly property bool screenEdgeShadowEnabled:
                    Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
                readonly property real screenEdgeShadowSize: Math.max(0, Math.min(32,
                    Math.round(Config.options?.appearance?.screenEdge?.physicalShadow?.size ?? 15)))
                readonly property real screenEdgeShadowOpacity: Math.max(0, Math.min(1.0,
                    Number(Config.options?.appearance?.screenEdge?.physicalShadow?.opacity ?? 0.70)))
                readonly property color screenEdgeShadowColor:
                    Qt.alpha(Appearance.m3colors.m3shadow, dockRoot.screenEdgeShadowOpacity)
                readonly property real edgeDecorationMargin: Math.max(
                    Appearance.sizes.elevationMargin,
                    PerimeterTokens.irisFuseDepth,
                    dockRoot.screenEdgeShadowEnabled ? dockRoot.screenEdgeShadowSize + 2 : 0)

                function beginDockResize(): void {
                    const baseline = Config.options?.dock?.height ?? 60
                    if (!ShellEditSession.beginGesture("iiDock", "resize-thickness",
                            { thickness: baseline }))
                        return
                    dockRoot._editResizeBaseline = baseline
                    dockRoot.editThicknessPreview = baseline
                }

                function updateDockResize(deltaX: real, deltaY: real): void {
                    if (dockRoot._editResizeBaseline < 0)
                        return
                    const towardScreen = root.position === "bottom" ? -deltaY
                        : root.isTop ? deltaY
                        : root.isLeft ? deltaX : -deltaX
                    // Keep shell-edit resize inside the same public range as
                    // Settings. Persisting >100 made the Settings spinbox clamp
                    // visually while runtime kept a much thicker Dock.
                    dockRoot.editThicknessPreview = Math.max(40, Math.min(100,
                        dockRoot._editResizeBaseline + towardScreen))
                }

                function finishDockResize(): void {
                    if (dockRoot.editThicknessPreview >= 0)
                        ShellLayoutController.setProperty("iiDock", "thickness",
                            dockRoot.editThicknessPreview, dockRoot.screen?.name ?? "")
                    dockRoot.editThicknessPreview = -1
                    dockRoot._editResizeBaseline = -1
                    ShellEditSession.finishGesture()
                }

                function cancelDockResize(): void {
                    dockRoot.editThicknessPreview = -1
                    dockRoot._editResizeBaseline = -1
                    ShellEditSession.cancelPending()
                }

                Connections {
                    target: ShellEditSession
                    function onGestureKindChanged(): void {
                        if (ShellEditSession.gestureKind.length > 0)
                            return
                        dockRoot.editThicknessPreview = -1
                        dockRoot._editResizeBaseline = -1
                    }
                }

                anchors {
                    top: root.isTop || root.isVertical
                    bottom: !root.isTop || root.isVertical
                    left: root.isLeft || !root.isVertical
                    right: !root.isLeft || !root.isVertical
                }

                // The painted Dock must stay in physical-output coordinates so
                // its body ends exactly at the Screen Edge seam. A normal
                // exclusive layer surface is displaced by the Screen Edge
                // reservation; pinned workspace reservation is therefore owned
                // by the transparent companion window below.
                exclusionMode: ExclusionMode.Ignore
                // Dock is an edge-attached iRiS surface. The native window
                // retains transparent room for the SDF shoulder/shadow, while
                // the visible body stops at the real Screen Edge inner boundary.
                // Keep transparent room for the complete free-edge shadow.
                // Increasing this room must not move the visible body: the
                // matching free-side body margin below grows by the same amount.
                implicitWidth: root.isVertical
                    ? (dockHeight + dockRoot.edgeDecorationMargin
                        + dockRoot.screenEdgeThickness)
                    : (dockBackground.implicitWidth
                        + dockRoot.edgeDecorationMargin * 2)
                implicitHeight: root.isVertical
                    ? (dockBackground.implicitHeight
                        + dockRoot.edgeDecorationMargin * 2)
                    : (dockHeight + dockRoot.edgeDecorationMargin
                        + dockRoot.screenEdgeThickness)

                WlrLayershell.namespace: "quickshell:dock"
                color: "transparent"

                readonly property string nativeBlurTopology:
                    Appearance.blurTopology.roundedRectangle
                readonly property bool nativeBlurActive: Appearance.useCompositorBlur(
                        "dock", dockRoot.nativeBlurTopology)
                    && (Config.options?.dock?.showBackground ?? true)
                    && !Appearance.gameModeMinimal
                readonly property Item nativeBlurItem: dockVisualBackground

                BackgroundEffect.blurRegion: Region {
                    item: dockRoot.nativeBlurActive ? dockRoot.nativeBlurItem : null
                    radius: dockRoot.nativeBlurItem?.radius ?? 0
                }

                mask: Region {
                    item: dockMouseArea
                }

                ConnectedSurfaceIrisEdgeSurface {
                    id: dockIrisSurface
                    z: 0
                    anchors.fill: parent
                    visible: dockVisualBackground.visible
                    edge: root.position
                    ownerThickness: dockRoot.screenEdgeThickness
                    outputRect: Qt.rect(0, 0, dockRoot.width, dockRoot.height)
                    bodyRect: Qt.rect(
                        dockMouseArea.x + dockBackground.x + dockVisualBackground.x,
                        dockMouseArea.y + dockBackground.y + dockVisualBackground.y,
                        dockVisualBackground.width,
                        dockVisualBackground.height)
                    bodyRadius: dockVisualBackground.radius
                    fillColor: dockVisualBackground.surfaceColor
                    // Match the other connected popup plates: the iRiS field
                    // owns shape/AA, but the Dock has no decorative outline.
                    progress: 1
                    shadowEnabled: dockRoot.screenEdgeShadowEnabled
                        && dockRoot.screenEdgeShadowSize > 0
                        && dockRoot.screenEdgeShadowOpacity > 0
                    shadowExtent: dockRoot.screenEdgeShadowSize
                    shadowColor: dockRoot.screenEdgeShadowColor
                }

                MouseArea {
                    id: dockMouseArea
                    z: 1
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton

                    width: root.isVertical
                        ? parent.width
                        : (dockBackground.implicitWidth + Appearance.sizes.elevationMargin * 2)
                    height: root.isVertical
                        ? (dockBackground.implicitHeight + Appearance.sizes.elevationMargin * 2)
                        : parent.height

                    anchors {
                        top: root.position === "bottom" ? parent.top : undefined
                        bottom: root.isTop ? parent.bottom : undefined
                        left: root.position === "right" ? parent.left : undefined
                        right: root.isLeft ? parent.right : undefined
                        horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
                        verticalCenter: root.isVertical ? parent.verticalCenter : undefined
                    }

                    property real hideOffset: dockRoot.reveal
                        ? 0
                        : Config.options?.dock?.hoverToReveal
                            ? (dockRoot.implicitHeight - (Config.options?.dock?.hoverRegionHeight ?? 2))
                            : (dockRoot.implicitHeight + 1)
                    property real hideOffsetV: dockRoot.reveal
                        ? 0
                        : Config.options?.dock?.hoverToReveal
                            ? (dockRoot.implicitWidth - (Config.options?.dock?.hoverRegionHeight ?? 2))
                            : (dockRoot.implicitWidth + 1)

                    anchors.topMargin: root.position === "bottom" ? hideOffset : 0
                    anchors.bottomMargin: root.isTop ? hideOffset : 0
                    anchors.leftMargin: root.position === "right" ? hideOffsetV : 0
                    anchors.rightMargin: root.isLeft ? hideOffsetV : 0

                    Behavior on anchors.topMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation {
                            duration: SurfaceMotion.duration
                            easing.type: SurfaceMotion.easingType
                        }
                    }
                    Behavior on anchors.bottomMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation {
                            duration: SurfaceMotion.duration
                            easing.type: SurfaceMotion.easingType
                        }
                    }
                    Behavior on anchors.leftMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation {
                            duration: SurfaceMotion.duration
                            easing.type: SurfaceMotion.easingType
                        }
                    }
                    Behavior on anchors.rightMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation {
                            duration: SurfaceMotion.duration
                            easing.type: SurfaceMotion.easingType
                        }
                    }

                    Item {
                        id: dockHoverRegion
                        anchors.fill: parent

                        Item {
                            id: dockBackground
                            z: 2

                            layer.enabled: Appearance.shouldDesaturate("dock") && dockBackground.visible
                            layer.effect: ShellDesaturationEffect {}

                            anchors {
                                top: !root.isVertical ? parent.top : undefined
                                bottom: !root.isVertical ? parent.bottom : undefined
                                left: root.isVertical ? parent.left : undefined
                                right: root.isVertical ? parent.right : undefined
                                horizontalCenter: !root.isVertical ? parent.horizontalCenter : undefined
                                verticalCenter: root.isVertical ? parent.verticalCenter : undefined
                            }

                            implicitWidth: root.isVertical
                                ? (dockRoot.width - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)
                                : (dockRow.implicitWidth + 10)
                            implicitHeight: root.isVertical
                                ? (dockColumn.implicitHeight + 10)
                                : (dockRoot.height - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)
                            width: implicitWidth
                            height: implicitHeight

                            Rectangle {
                                id: dockVisualBackground
                                readonly property bool gameModeMinimal:
                                    Appearance.gameModeMinimal
                                // iRiS is the sole body painter. Keeping a second
                                // Rectangle fill here double-composited alpha and
                                // made transparent Material settings too opaque.
                                property color surfaceColor:
                                    Appearance.colors.colLayer0

                                anchors.fill: parent
                                anchors.topMargin: root.isTop
                                    ? dockRoot.screenEdgeThickness
                                    : (root.isVertical ? 0 : dockRoot.edgeDecorationMargin)
                                anchors.bottomMargin: root.position === "bottom"
                                    ? dockRoot.screenEdgeThickness
                                    : (root.isVertical ? 0 : dockRoot.edgeDecorationMargin)
                                anchors.leftMargin: root.isLeft
                                    ? dockRoot.screenEdgeThickness
                                    : (root.isVertical ? dockRoot.edgeDecorationMargin : 0)
                                anchors.rightMargin: root.position === "right"
                                    ? dockRoot.screenEdgeThickness
                                    : (root.isVertical ? dockRoot.edgeDecorationMargin : 0)

                                visible: (Config.options?.dock?.showBackground ?? true)
                                    && !gameModeMinimal
                                color: "transparent"
                                border.width: 0
                                border.color: "transparent"
                                radius: Appearance.rounding.large
                                // The edge-facing corners belong to the
                                // shared Screen Edge seam and must stay square.
                                topLeftRadius: (root.isTop || root.isLeft) ? 0 : radius
                                topRightRadius: (root.isTop || root.position === "right") ? 0 : radius
                                bottomLeftRadius: (root.position === "bottom" || root.isLeft) ? 0 : radius
                                bottomRightRadius: (root.position === "bottom" || root.position === "right") ? 0 : radius

                                Behavior on surfaceColor {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }

                            RowLayout {
                                id: dockRow
                                visible: !root.isVertical
                                anchors.centerIn: dockVisualBackground
                                spacing: 2
                                property real padding: 5

                                DockApps {
                                    id: dockApps
                                    enabled: !root.isVertical
                                    dockThickness: dockRoot.dockHeight
                                    vertical: false
                                    dockPosition: root.position
                                    parentWindow: dockRoot
                                }
                                DockButton {
                                    vertical: false
                                    dockThicknessOverride: dockRoot.dockHeight
                                    onClicked: GlobalStates.toggleOverview(
                                        dockRoot.screen?.name ?? "")
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: Appearance.colors.colOnLayer0
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: dockColumn
                                visible: root.isVertical
                                anchors.centerIn: dockVisualBackground
                                spacing: 2
                                property real padding: 5

                                DockApps {
                                    id: dockAppsVertical
                                    enabled: root.isVertical
                                    dockThickness: dockRoot.dockHeight
                                    vertical: true
                                    dockPosition: root.position
                                    parentWindow: dockRoot
                                }
                                DockButton {
                                    vertical: true
                                    dockThicknessOverride: dockRoot.dockHeight
                                    onClicked: GlobalStates.toggleOverview(
                                        dockRoot.screen?.name ?? "")
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        font.pixelSize: parent.width * 0.5
                                        text: "apps"
                                        color: Appearance.colors.colOnLayer0
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ShellEditSurfaceFrame {
                        id: dockEditFrame
                        readonly property Item visualTarget:
                            dockRoot.nativeBlurItem ?? dockBackground
                        x: Math.round(dockBackground.x + visualTarget.x)
                        y: Math.round(dockBackground.y + visualTarget.y)
                        width: Math.round(visualTarget.width)
                        height: Math.round(visualTarget.height)
                        surfaceId: "iiDock"
                        label: Translation.tr("Dock")
                        active: ShellEditSession.blocksNormalActions(surfaceId)
                        selected: ShellEditSession.selectedSurfaceId === surfaceId
                        lifted: ShellEditSession.liftedSurfaceId === surfaceId
                        slotHint: Config.options?.dock?.position ?? "bottom"
                        screenWidth: dockRoot.screen?.width ?? 0
                        screenHeight: dockRoot.screen?.height ?? 0
                        onDragStarted: surface => ShellEditSession.beginDrag(surface)
                        onDragMoved: (surface, screenX, screenY) =>
                            ShellEditSession.updateDrag(screenX, screenY)
                        onDragEnded: () => ShellEditSession.endDrag()
                        onDragCanceled: () => ShellEditSession.cancelDrag()
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        textColor: Appearance.colors.colOnLayer2
                        frameRadius: Appearance.rounding.small
                        fontFamily: Appearance.font.family.main
                        fontPixelSize: Appearance.font.pixelSize.smaller
                        animationDuration: Appearance.animationsEnabled
                            ? Appearance.animation.elementMoveFast.duration : 0
                        onActivated: surface => ShellEditSession.selectSurface(surface)
                    }

                    ShellEditResizeHandle {
                        z: 11000
                        width: root.isVertical ? 20 : 96
                        height: root.isVertical ? 96 : 20
                        anchors {
                            horizontalCenter: root.isVertical
                                ? (root.isLeft ? dockEditFrame.right : dockEditFrame.left)
                                : dockEditFrame.horizontalCenter
                            verticalCenter: root.isVertical
                                ? dockEditFrame.verticalCenter
                                : (root.isTop ? dockEditFrame.bottom : dockEditFrame.top)
                        }
                        axis: root.isVertical ? "horizontal" : "vertical"
                        active: ShellEditSession.active
                            && ShellEditSession.selectedSurfaceId === "iiDock"
                            && ShellEditSession.liftedSurfaceId.length === 0
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        animationsEnabled: Appearance.animationsEnabled
                        radius: Appearance.rounding.full
                        onDragStarted: dockRoot.beginDockResize()
                        onDragged: (axis, deltaX, deltaY) =>
                            dockRoot.updateDockResize(deltaX, deltaY)
                        onDragFinished: dockRoot.finishDockResize()
                        onDragCanceled: dockRoot.cancelDockResize()
                    }

                    ShellEditSizeBadge {
                        z: 12000
                        anchors.centerIn: dockEditFrame
                        active: dockRoot.editThicknessPreview >= 0
                        valueText: Math.round(dockRoot.dockHeight) + " px"
                        accentColor: Appearance.colors.colPrimary
                        surfaceColor: Appearance.colors.colLayer2
                        textColor: Appearance.colors.colOnLayer2
                        fontFamily: Appearance.font.family.main
                        fontPixelSize: Appearance.font.pixelSize.smaller
                    }
                }
            }
        }
    }

    // Reservation-only companion for pinned mode. It paints and accepts
    // nothing; separating it from the visual Dock lets the iRiS surface ignore
    // other exclusive zones without losing the historical workspace strut.
    Variants {
        model: root.targetScreens

        PanelWindow {
            id: dockReservation
            required property var modelData

            screen: modelData
            visible: root.pinned
                && GlobalStates.shellEntryReady
                && !GlobalStates.screenLocked
                && !GlobalStates.widgetEditMode
            color: "transparent"
            // Reserve through the visible body's inward edge. This tracks the
            // configurable Screen Edge width; elevationMargin is only transparent
            // free-side render room and must not define workspace geometry.
            exclusiveZone: visible
                ? Math.max(0, Math.round((Config.options?.dock?.height ?? 60)
                    + Math.max(1, Math.min(32,
                        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))))
                : 0

            implicitWidth: root.isVertical ? 1 : 0
            implicitHeight: root.isVertical ? 0 : 1

            WlrLayershell.namespace: "quickshell:dock-reservation"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: root.isTop || root.isVertical
                bottom: !root.isTop || root.isVertical
                left: root.isLeft || !root.isVertical
                right: !root.isLeft || !root.isVertical
            }

            Item {
                id: emptyReservationInput
                width: 0
                height: 0
                visible: false
            }
            mask: Region { item: emptyReservationInput }
        }
    }
}
