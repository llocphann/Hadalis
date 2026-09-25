pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: bar
    // Hug is the only supported Classic Bar surface. Its body is structural
    // in BarContent rather than mediated by a compatibility visibility flag.
    // Legacy Bar surface values are normalized once by SettingsPageRegistry at
    // shell startup. The live Bar consumes only canonical Hug state.

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
                readonly property string outputName: String(barLoader.modelData?.name ?? "")
                readonly property bool fullscreenCovered: barRoot.outputName.length > 0
                    && GameMode.hasFullscreenOnOutput(barRoot.outputName)

                // Keep this window mapped across fullscreen. Niri can map the
                // full-output Screen Edge frame after the bar, obscuring the
                // entire bar while leaving its input region interactive. Put
                // the bar above that Top-layer frame and gate its paint/input
                // during fullscreen without destroying the layer surface.
                readonly property real panelSurfaceHeight: Appearance.sizes.barHeight
                readonly property bool rightDeadPixelWorkaround: (Config.options?.interactions?.deadPixelWorkaround?.enable ?? false)
                    && barRoot.anchors.right
                readonly property bool bottomDeadPixelWorkaround: (Config.options?.interactions?.deadPixelWorkaround?.enable ?? false)
                    && barRoot.anchors.bottom


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
                    || CodeWorkflowPicker.holdsOutput(barRoot.outputName)
                    || GlobalStates.barPopupHoverHeld(barRoot.outputName)
                    || (GlobalStates.overviewOpen
                        && (!GlobalStates.overviewTargetOutput
                            || GlobalStates.overviewTargetOutput === barRoot.outputName))
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone:
                    (barRoot.fullscreenCovered || GlobalStates.coverflowSelectorOpen || (Config?.options.bar.autoHide.enable && (!mustShow || !Config?.options.bar.autoHide.pushWindows))) ? 0 :
                    barRoot.panelSurfaceHeight
                WlrLayershell.namespace: "quickshell:bar"
                WlrLayershell.layer: WlrLayer.Overlay
                implicitHeight: barRoot.panelSurfaceHeight
                // Explicit zero-size item prevents ambiguous null input region during
                // surface map/unmap transitions. Region { item: null } can be interpreted
                // as "full surface accepts input" by the compositor, causing an invisible
                // input-blocking area at the top of the screen.
                Item { id: emptyMask; width: 0; height: 0 }
                mask: Region {
                    item: barRoot.fullscreenCovered ? emptyMask : hoverMaskRegion
                }
                color: "transparent"

                // Shaped compositor blur; Niri applies the request only inside the
                // actual Classic bar background rather than across the whole layer surface.
                BackgroundEffect.blurRegion: Region {
                    Region {
                        item: !barRoot.fullscreenCovered && barContent.nativeBlurActive
                            ? barContent.backgroundItem : emptyMask
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
                    enabled: !barRoot.fullscreenCovered
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
                        // FULLSCREEN-BAR-CONTENT-LIFECYCLE-LOCK:
                        // Keep the QML content subtree continuously presented.
                        // Toggling either visible or opacity across fullscreen
                        // can strand native-rendered Text/MaterialSymbol nodes
                        // after focus moves to a sibling window on the same
                        // workspace. Hide fullscreen spatially instead, using
                        // the same off-surface margin path as normal auto-hide.
                        readonly property bool spatiallyHidden:
                            barRoot.fullscreenCovered
                            || (Config?.options.bar.autoHide.enable && !mustShow)
                            || GlobalStates.coverflowSelectorOpen
                            || !GlobalStates.shellEntryReady
                        nativeBlurAllowed: false
                        // Keep the spectrum live through the visible slide-out
                        // tail, then release CAVA once the Bar is off-screen.
                        presentationActive: !barRoot.fullscreenCovered
                            && (barRoot.anchors.bottom
                                ? barContent.anchors.bottomMargin > -barRoot.panelSurfaceHeight + 1
                                : barContent.anchors.topMargin > -barRoot.panelSurfaceHeight + 1)

                        implicitHeight: barRoot.panelSurfaceHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: barContent.spatiallyHidden ? -barRoot.panelSurfaceHeight : 0
                            bottomMargin: barRoot.bottomDeadPixelWorkaround ? -1 : 0
                            rightMargin: barRoot.rightDeadPixelWorkaround ? -1 : 0
                        }
                        Behavior on anchors.topMargin {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                        }
                        Behavior on anchors.bottomMargin {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
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
                                anchors.bottomMargin: barContent.spatiallyHidden ? -barRoot.panelSurfaceHeight : 0
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

                }
            }
        }
    }

    // IPC target "bar" is registered once in shell.qml (always loaded, family-
    // agnostic). Both Bar and VerticalBar are instantiated under the ii family,
    // so a handler here would collide with VerticalBar's and Quickshell would
    // drop one with a "registered but will not be used" warning.

}
