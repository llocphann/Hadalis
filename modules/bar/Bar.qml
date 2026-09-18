pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar
    property bool showBarBackground: Config.options?.bar?.showBackground ?? true
    property bool _legacyCornerStyleMigrationDone: false
    // Note: Vignette effect moved to Backdrop.qml (backdrop wallpaper layer)

    // Global style changes can swap surface implementations that are evaluated
    // when the bar window is created, so rebuild only for that live dependency.
    readonly property string rebuildKey: Config.options?.appearance?.globalStyle ?? "material"
    property bool rebuilding: false
    onRebuildKeyChanged: {
        bar.rebuilding = true;
        barRebuildTimer.restart();
    }

    function normalizeLegacyCornerStyle(): void {
        if (bar._legacyCornerStyleMigrationDone || !Config.ready)
            return

        bar._legacyCornerStyleMigrationDone = true
        if ((Config.options?.bar?.cornerStyle ?? 0) !== 0)
            Config.setNestedValue("bar.cornerStyle", 0)
    }

    Component.onCompleted: bar.normalizeLegacyCornerStyle()

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                bar.normalizeLegacyCornerStyle()
        }
    }

    Timer {
        id: barRebuildTimer
        interval: 50
        onTriggered: bar.rebuilding = false
    }

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.bar?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            const matchedScreens = screens.filter(screen => {
                const screenName = screen?.name ?? "";
                return screenName.length > 0 && list.includes(screenName);
            });
            // Fallback safety: stale monitor names (e.g. output re-enumeration after VRR changes)
            // should never hide the bar on every screen.
            return matchedScreens.length > 0 ? matchedScreens : screens;
        }
        LazyLoader {
            id: barLoader
            active: !bar.rebuilding && GlobalStates.barOpen && !GlobalStates.screenLocked
                && !GlobalStates.widgetEditMode
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData
                visible: true
                readonly property real panelSurfaceHeight: Appearance.sizes.barHeight
                readonly property bool hugCorners: bar.showBarBackground
                readonly property real roundDecoratorAllowance: hugCorners
                    ? Appearance.rounding.screenRounding : 0
                readonly property bool edgeShadowEnabled: bar.showBarBackground
                    && (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
                readonly property int edgeShadowExtent: edgeShadowEnabled
                    ? Math.max(0, Math.min(32,
                        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 12)))
                    : 0
                readonly property real edgeShadowOpacity: Math.max(0, Math.min(0.60,
                    Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.24)))
                readonly property color edgeShadowColor:
                    ColorUtils.applyAlpha(Appearance.colors.colShadow, edgeShadowOpacity)
                readonly property real inwardDecoratorAllowance:
                    Math.max(roundDecoratorAllowance, edgeShadowExtent)
                readonly property bool rightDeadPixelWorkaround: (Config.options?.interactions?.deadPixelWorkaround?.enable ?? false)
                    && barRoot.anchors.right
                readonly property bool bottomDeadPixelWorkaround: (Config.options?.interactions?.deadPixelWorkaround?.enable ?? false)
                    && barRoot.anchors.bottom

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen.width) ? 1 : 0
                readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

                Timer {
                    id: showBarTimer
                    interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || ShellEditSession.active
                readonly property bool surfacePresented:
                    !GlobalStates.coverflowSelectorOpen
                    && GlobalStates.shellEntryReady
                    && (!(Config.options?.bar?.autoHide?.enable ?? false) || mustShow)
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone:
                    (GlobalStates.coverflowSelectorOpen || (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows))) ? 0 :
                    barRoot.panelSurfaceHeight
                WlrLayershell.namespace: "quickshell:bar"
                implicitHeight: barRoot.panelSurfaceHeight + barRoot.inwardDecoratorAllowance
                // Explicit zero-size item prevents ambiguous null input region during
                // surface map/unmap transitions. Region { item: null } can be interpreted
                // as "full surface accepts input" by the compositor, causing an invisible
                // input-blocking area at the top of the screen.
                Item { id: emptyMask; width: 0; height: 0 }
                mask: Region {
                    item: hoverMaskRegion
                }
                color: "transparent"

                // Shaped compositor blur; Niri applies the request only inside the
                // actual Classic bar background rather than across the whole layer surface.
                BackgroundEffect.blurRegion: Region {
                    Region {
                        item: barContent.nativeBlurActive ? barContent.backgroundItem : emptyMask
                        radius: barContent.backgroundItem.radius
                    }
                }

                anchors {
                    top: !(Config.options?.bar?.bottom ?? false)
                    bottom: (Config.options?.bar?.bottom ?? false)
                    left: true
                    right: true
                }

                margins {
                    right: barRoot.rightDeadPixelWorkaround ? -1 : 0
                    bottom: barRoot.bottomDeadPixelWorkaround ? -1 : 0
                }

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    property alias barContent: barContent
                    anchors {
                        fill: parent
                        rightMargin: barRoot.rightDeadPixelWorkaround ? 1 : 0
                        bottomMargin: barRoot.bottomDeadPixelWorkaround ? 1 : 0
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                            bottomMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                        }
                    }

                    BarContent {
                        id: barContent
                        nativeBlurAllowed: !barRoot.hugCorners

                        implicitHeight: barRoot.panelSurfaceHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -barRoot.panelSurfaceHeight : 0
                            bottomMargin: barRoot.bottomDeadPixelWorkaround ? -1 : 0
                            rightMargin: barRoot.rightDeadPixelWorkaround ? -1 : 0
                        }
                        Behavior on anchors.topMargin {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                        }
                        Behavior on anchors.bottomMargin {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                        }

                        states: State {
                            name: "bottom"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -barRoot.panelSurfaceHeight : 0
                            }
                        }
                    }

                    // Shared with Screen Edge shadow settings so the shell chrome
                    // reads as one continuous Caelestia-style perimeter.
                    Rectangle {
                        id: barEdgeShadow
                        visible: barRoot.edgeShadowEnabled
                            && barRoot.edgeShadowExtent > 0
                            && barRoot.edgeShadowOpacity > 0
                            && barRoot.surfacePresented
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: !(Config.options?.bar?.bottom ?? false) ? barContent.bottom : undefined
                            bottom: (Config.options?.bar?.bottom ?? false) ? barContent.top : undefined
                        }
                        height: barRoot.edgeShadowExtent
                        color: "transparent"
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop {
                                position: 0
                                color: (Config.options?.bar?.bottom ?? false)
                                    ? "transparent" : barRoot.edgeShadowColor
                            }
                            GradientStop {
                                position: 1
                                color: (Config.options?.bar?.bottom ?? false)
                                    ? barRoot.edgeShadowColor : "transparent"
                            }
                        }
                    }

                    ShellEditSurfaceFrame {
                        anchors.fill: barContent
                        surfaceId: "iiBar"
                        label: Translation.tr("Bar")
                        active: ShellEditSession.blocksNormalActions(surfaceId)
                        selected: ShellEditSession.selectedSurfaceId === surfaceId
                        lifted: ShellEditSession.liftedSurfaceId === surfaceId
                        slotHint: (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
                        screenWidth: barRoot.screen?.width ?? 0
                        screenHeight: barRoot.screen?.height ?? 0
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

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: Appearance.rounding.screenRounding
                        active: barRoot.hugCorners

                        states: State {
                            name: "bottom"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            id: hugDecorators
                            implicitHeight: Appearance.rounding.screenRounding
                            
                            readonly property bool isBottom: Config.options?.bar?.bottom ?? false
                            readonly property color solidColor: showBarBackground
                                ? Appearance.colors.colLayer0
                                : "transparent"
                            
                            // Left corner - solid for Material/Inir, blur for Aurora
                            RoundCorner {
                                id: leftCorner
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: hugDecorators.isBottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            
                            // Right corner - solid for Material/Inir
                            RoundCorner {
                                id: rightCorner
                                anchors {
                                    right: parent.right
                                    top: !hugDecorators.isBottom ? parent.top : undefined
                                    bottom: hugDecorators.isBottom ? parent.bottom : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: hugDecorators.isBottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }
                            
                        }
                    }
                }
            }
        }
    }

    // IPC target "bar" is registered once in shell.qml (always loaded, family-
    // agnostic). Both Bar and VerticalBar are instantiated under the ii family,
    // so a handler here would collide with VerticalBar's and Quickshell would
    // drop one with a "registered but will not be used" warning.

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "barToggle"
                description: "Toggles bar on press"

                onPressed: {
                    GlobalStates.barOpen = !GlobalStates.barOpen;
                }
            }

            GlobalShortcut {
                name: "barOpen"
                description: "Opens bar on press"

                onPressed: {
                    GlobalStates.barOpen = true;
                }
            }

            GlobalShortcut {
                name: "barClose"
                description: "Closes bar on press"

                onPressed: {
                    GlobalStates.barOpen = false;
                }
            }
        }
    }
}