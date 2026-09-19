pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.perimeter

Scope {
    id: bar
    // Vertical Hug uses the same structural connected surface as horizontal
    // Bar; legacy transparent-bar state must not remove its shoulders/shadow.
    readonly property bool showBarBackground: true

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
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
                && !GlobalStates.widgetEditMode
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData
                visible: true

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                
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
                readonly property real screenEdgeThickness: Math.max(1, Math.min(32,
                    Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))
                readonly property real frameRadius: Math.max(0, Math.min(96,
                    Number(Config.options?.appearance?.screenEdge?.radius
                        ?? PerimeterTokens.frameRadius)))
                readonly property bool edgeShadowEnabled: bar.showBarBackground
                    && (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
                readonly property int edgeShadowExtent: edgeShadowEnabled
                    ? Math.max(0, Math.min(32,
                        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
                    : 0
                readonly property real edgeShadowOpacity: Math.max(0, Math.min(1.0,
                    Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70)))
                readonly property color edgeShadowColor:
                    ColorUtils.applyAlpha(Appearance.colors.colShadow, edgeShadowOpacity)
                readonly property bool autoHideEnabled:
                    Config.options?.bar?.autoHide?.enable ?? false
                // Normal Bar mode owns only the Bar body. Extra inward host
                // room exists solely for the auto-hide Screen Edge fallback.
                readonly property real inwardDecoratorAllowance:
                    Math.max(autoHideEnabled ? frameRadius : 0, edgeShadowExtent)
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone:
                    (GlobalStates.coverflowSelectorOpen || (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows))) ? 0 :
                    Appearance.sizes.baseVerticalBarWidth
                WlrLayershell.namespace: "quickshell:verticalBar"
                // Default Top layer ON PURPOSE: fullscreen surfaces render
                // above Top, so videos/games naturally cover the bar. Overlay
                // would draw the bar over fullscreen content (GameMode only
                // detects games, not videos).
                implicitWidth: Appearance.sizes.verticalBarWidth + barRoot.inwardDecoratorAllowance
                Item { id: emptyMask; width: 0; height: 0 }
                mask: Region {
                    item: hoverMaskRegion
                }
                color: "transparent"

                BackgroundEffect.blurRegion: Region {
                    item: barContent.nativeBlurActive ? barContent.backgroundItem : emptyMask
                    radius: barContent.backgroundItem.radius
                }

                anchors {
                    left: !(Config.options?.bar?.bottom ?? false)
                    right: (Config.options?.bar?.bottom ?? false)
                    top: true
                    bottom: true
                }

                // Focus grab is handled by layer shell (PanelWindow)

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors.fill: parent

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            leftMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                            rightMargin: -(Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2)
                        }
                    }

                    Item {
                        id: autoHideScreenEdge
                        z: -10
                        anchors.fill: parent
                        visible: barRoot.autoHideEnabled
                        opacity: {
                            const displacement = (Config.options?.bar?.bottom ?? false)
                                ? Math.abs(barContent.anchors.rightMargin)
                                : Math.abs(barContent.anchors.leftMargin)
                            return Math.max(0, Math.min(1,
                                displacement / Math.max(1, Appearance.sizes.verticalBarWidth)))
                        }

                        Rectangle {
                            id: autoHideEdgeBand
                            x: (Config.options?.bar?.bottom ?? false)
                                ? parent.width - barRoot.screenEdgeThickness : 0
                            y: 0
                            width: barRoot.screenEdgeThickness
                            height: parent.height
                            color: Appearance.colors.colLayer0
                        }

                        Rectangle {
                            visible: barRoot.edgeShadowEnabled
                                && barRoot.edgeShadowExtent > 0
                                && barRoot.edgeShadowOpacity > 0
                            x: (Config.options?.bar?.bottom ?? false)
                                ? autoHideEdgeBand.x - barRoot.edgeShadowExtent
                                : autoHideEdgeBand.x + autoHideEdgeBand.width
                            y: barRoot.screenEdgeThickness
                                + barRoot.frameRadius
                            width: barRoot.edgeShadowExtent
                            height: Math.max(0, parent.height
                                - 2 * (barRoot.screenEdgeThickness
                                    + barRoot.frameRadius))
                            color: "transparent"
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
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

                        RoundCorner {
                            implicitSize: barRoot.frameRadius
                            color: Appearance.colors.colLayer0
                            shadowEnabled: barRoot.edgeShadowEnabled
                            shadowExtent: barRoot.edgeShadowExtent
                            shadowColor: barRoot.edgeShadowColor
                            corner: (Config.options?.bar?.bottom ?? false)
                                ? RoundCorner.CornerEnum.TopRight
                                : RoundCorner.CornerEnum.TopLeft
                            anchors {
                                top: parent.top
                                topMargin: barRoot.screenEdgeThickness
                                left: !(Config.options?.bar?.bottom ?? false)
                                    ? autoHideEdgeBand.right : undefined
                                right: (Config.options?.bar?.bottom ?? false)
                                    ? autoHideEdgeBand.left : undefined
                            }
                        }
                        RoundCorner {
                            implicitSize: barRoot.frameRadius
                            color: Appearance.colors.colLayer0
                            shadowEnabled: barRoot.edgeShadowEnabled
                            shadowExtent: barRoot.edgeShadowExtent
                            shadowColor: barRoot.edgeShadowColor
                            corner: (Config.options?.bar?.bottom ?? false)
                                ? RoundCorner.CornerEnum.BottomRight
                                : RoundCorner.CornerEnum.BottomLeft
                            anchors {
                                bottom: parent.bottom
                                bottomMargin: barRoot.screenEdgeThickness
                                left: !(Config.options?.bar?.bottom ?? false)
                                    ? autoHideEdgeBand.right : undefined
                                right: (Config.options?.bar?.bottom ?? false)
                                    ? autoHideEdgeBand.left : undefined
                            }
                        }
                    }

                    VerticalBarContent {
                        id: barContent

                        implicitWidth: Appearance.sizes.verticalBarWidth
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: undefined
                            leftMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -Appearance.sizes.verticalBarWidth : 0
                            rightMargin: 0
                        }
                        Behavior on anchors.leftMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                        }
                        Behavior on anchors.rightMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                        }

                        states: State {
                            name: "right"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: parent.right
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.rightMargin: ((Config?.options.bar.autoHide.enable && !mustShow) || GlobalStates.coverflowSelectorOpen || !GlobalStates.shellEntryReady) ? -Appearance.sizes.verticalBarWidth : 0
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
                        slotHint: (Config.options?.bar?.bottom ?? false) ? "right" : "left"
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

                }
            }
        }
    }

    // IPC target "bar" is registered once in shell.qml (always loaded, family-
    // agnostic). See the note in Bar.qml — both bars coexist under the ii
    // family, so a handler here would collide with the horizontal bar's.

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
