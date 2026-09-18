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
                readonly property bool edgeShadowEnabled: bar.showBarBackground
                    && (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
                readonly property int edgeShadowExtent: edgeShadowEnabled
                    ? Math.max(0, Math.min(32,
                        Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 12)))
                    : 0
                readonly property real edgeShadowOpacity: Math.max(0, Math.min(0.60,
                    Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.24)))
                readonly property color edgeShadowColor:
                    ColorUtils.applyAlpha(Appearance.m3colors.m3shadow, edgeShadowOpacity)
                readonly property real inwardDecoratorAllowance:
                    Math.max(Appearance.rounding.screenRounding, edgeShadowExtent)
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

                    // Same inward shadow contract as Screen Edge / horizontal Bar.
                    Rectangle {
                        id: barEdgeShadow
                        visible: barRoot.edgeShadowEnabled
                            && barRoot.edgeShadowExtent > 0
                            && barRoot.edgeShadowOpacity > 0
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            topMargin: showBarBackground ? Appearance.rounding.screenRounding : 0
                            bottomMargin: showBarBackground ? Appearance.rounding.screenRounding : 0
                            left: !(Config.options?.bar?.bottom ?? false) ? barContent.right : undefined
                            right: (Config.options?.bar?.bottom ?? false) ? barContent.left : undefined
                        }
                        width: barRoot.edgeShadowExtent
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

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: barContent.right
                            right: undefined
                        }
                        width: Appearance.rounding.screenRounding
                        active: showBarBackground

                        states: State {
                            name: "right"
                            when: (Config.options?.bar?.bottom ?? false)
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: barContent.left
                                }
                            }
                        }

                        sourceComponent: Item {
                            id: hugDecorators
                            implicitHeight: Appearance.rounding.screenRounding

                            readonly property bool isRight: Config.options?.bar?.bottom ?? false
                            // Color must match the Material bar background exactly.
                            readonly property color solidColor: showBarBackground
                                ? Appearance.colors.colLayer0
                                : "transparent"

                            // Top Material corner.
                            RoundCorner {
                                id: topCorner
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "right"
                                    when: hugDecorators.isRight
                                    PropertyChanges {
                                        topCorner.corner: RoundCorner.CornerEnum.TopRight
                                    }
                                }
                            }

                            // Bottom Material corner.
                            RoundCorner {
                                id: bottomCorner
                                anchors {
                                    bottom: parent.bottom
                                    left: !hugDecorators.isRight ? parent.left : undefined
                                    right: hugDecorators.isRight ? parent.right : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: hugDecorators.solidColor

                                corner: RoundCorner.CornerEnum.BottomLeft
                                states: State {
                                    name: "right"
                                    when: hugDecorators.isRight
                                    PropertyChanges {
                                        bottomCorner.corner: RoundCorner.CornerEnum.BottomRight
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
