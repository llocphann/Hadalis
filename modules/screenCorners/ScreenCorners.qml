import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: screenCorners
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property var actionForCorner: ({
        "topLeft": outputName => GlobalStates.toggleSidebarLeft(outputName),
        "bottomLeft": outputName => GlobalStates.toggleSidebarLeft(outputName),
        "topRight": outputName => GlobalStates.toggleSidebarRight(outputName),
        "bottomRight": outputName => GlobalStates.toggleSidebarRight(outputName)
    })

    component CornerPanelWindow: PanelWindow {
        id: cornerPanelWindow
        property var screen: QsWindow.window?.screen
        property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
        property bool fullscreen
        property string corner: ""
        readonly property bool isTopLeft: corner === "topLeft"
        readonly property bool isTopRight: corner === "topRight"
        readonly property bool isBottomLeft: corner === "bottomLeft"
        readonly property bool isBottomRight: corner === "bottomRight"
        readonly property bool isTop: isTopLeft || isTopRight
        readonly property bool isBottom: isBottomLeft || isBottomRight
        readonly property bool isLeft: isTopLeft || isBottomLeft
        readonly property bool isRight: isTopRight || isBottomRight

        // Interaction-only corner windows. Physical rounding is owned exclusively
        // by ScreenEdges.qml's canonical full-screen frame.
        readonly property bool cornerOpenEnabled: Config?.options?.sidebar?.cornerOpen?.enable ?? false
        readonly property bool cornerOpenAtBottom: Config?.options?.sidebar?.cornerOpen?.bottom ?? false
        readonly property bool cornerOpenMatchesPosition: cornerOpenAtBottom === cornerPanelWindow.isBottom
        readonly property bool shouldShowCornerOpen: cornerOpenEnabled
            && cornerOpenMatchesPosition && !fullscreen
        readonly property string orbitCorner: Config.options?.orbit?.hotCorner ?? "topRight"
        readonly property string cornerName: cornerPanelWindow.corner
        readonly property string outputName: cornerPanelWindow.screen?.name ?? ""
        readonly property bool orbitConflictsWithNiriOverview: CompositorService.isNiri
            && NiriService.isOverviewHotCornerActive(outputName, cornerName)
        readonly property bool shouldShowOrbitHotCorner: CompositorService.isNiri
            && (Config.options?.panelFamily ?? "ii") !== "waffle"
            && (Config.options?.orbit?.enable ?? true)
            && (Config.options?.orbit?.hotCornerEnable ?? true)
            && cornerName === orbitCorner
            && !orbitConflictsWithNiriOverview
            && !fullscreen
        readonly property bool quickNotesInteractionBlocked:
            GlobalStates.screenLocked
            || GlobalStates.bootGreetingOpen
            || GlobalStates.crosshairOpen
            || GlobalStates.sidebarLeftOpen
            || GlobalStates.sidebarRightOpen
            || GlobalStates.mediaControlsOpen
            || GlobalStates.oskOpen
            || GlobalStates.overlayOpen
            || GlobalStates.overviewOpen
            || GlobalStates.altSwitcherOpen
            || GlobalStates.clipboardOpen
            || GlobalStates.settingsOverlayOpen
            || GlobalStates.settingsNativeDialogOpen
            || GlobalStates.regionSelectorOpen
            || GlobalStates.tilingOverlayPickerOpen
            || GlobalStates.annotationEditorOpen
            || GlobalStates.sessionOpen
            || GlobalStates.wallpaperSelectorOpen
            || GlobalStates.wallpaperLauncherOpen
            || GlobalStates.widgetEditMode
            || GlobalStates.shellLayoutEditMode
            || GlobalStates.cheatsheetOpen
            || GlobalStates.coverflowSelectorOpen
            || GlobalStates.controlPanelOpen
            || GlobalStates.dashboardOpen
            || GlobalStates.searchOpen
        readonly property string quickNotesMonitorMode:
            Config.options?.quickNotes?.monitorMode ?? "all"
        readonly property bool quickNotesMonitorAllowed:
            quickNotesMonitorMode !== "primary"
            || outputName === (GlobalStates.primaryScreen?.name ?? "")

        function quickNotesBarTargetsOutput(): bool {
            if (outputName.length === 0)
                return false
            const configured = Config.options?.bar?.screenList ?? []
            if (!configured || configured.length === 0)
                return true
            const connectedMatches = Quickshell.screens.filter(screen => {
                const name = String(screen?.name ?? "")
                return name.length > 0 && configured.includes(name)
            })
            return connectedMatches.length === 0 || configured.includes(outputName)
        }

        readonly property bool quickNotesBarVertical:
            Config.options?.bar?.vertical ?? false
        readonly property bool quickNotesBarTrailing:
            Config.options?.bar?.bottom ?? false
        readonly property string quickNotesBarPanelId:
            quickNotesBarVertical ? "iiVerticalBar" : "iiBar"
        readonly property bool quickNotesBarOwnsConfiguredEdge:
            GlobalStates.barOpen
            && !GlobalStates.widgetEditMode
            && (Config.options?.enabledPanels ?? []).includes(quickNotesBarPanelId)
            && !(Config.options?.bar?.autoHide?.enable ?? false)
            && cornerPanelWindow.quickNotesBarTargetsOutput()
        readonly property bool quickNotesBarOwnsLeft:
            quickNotesBarOwnsConfiguredEdge
            && quickNotesBarVertical && !quickNotesBarTrailing
        readonly property bool quickNotesBarOwnsBottom:
            quickNotesBarOwnsConfiguredEdge
            && !quickNotesBarVertical && quickNotesBarTrailing
        readonly property string quickNotesAttachmentEdge:
            quickNotesBarOwnsLeft ? "left" : "bottom"
        readonly property real quickNotesAttachmentThickness:
            quickNotesBarOwnsLeft ? Appearance.sizes.verticalBarWidth
            : quickNotesBarOwnsBottom ? Appearance.sizes.barHeight
            : Math.max(1, Math.min(32,
                Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))

        readonly property bool shouldShowQuickNotesCorner:
            (Config.options?.panelFamily ?? "ii") !== "waffle"
            && (Config.options?.quickNotes?.enable ?? true)
            && cornerPanelWindow.quickNotesMonitorAllowed
            && cornerPanelWindow.isBottomLeft
            && !cornerPanelWindow.shouldShowOrbitHotCorner
            && !cornerPanelWindow.orbitConflictsWithNiriOverview
            && !cornerPanelWindow.quickNotesInteractionBlocked
            && !fullscreen
        // Explicit corner features own their physical corner before the legacy
        // sidebar trigger. This lets bottom-left become Quick Notes without
        // deleting the old corner-open compatibility settings.
        readonly property bool shouldShowSidebarCornerOpen: shouldShowCornerOpen
            && !shouldShowOrbitHotCorner
            && !shouldShowQuickNotesCorner

        visible: !fullscreen && (shouldShowSidebarCornerOpen
            || shouldShowOrbitHotCorner || shouldShowQuickNotesCorner)

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: orbitHotCornerLoader.active ? orbitHotCornerLoader
                : quickNotesCornerLoader.active ? quickNotesCornerLoader
                : (sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null)
        }
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        anchors {
            top: cornerPanelWindow.isTopLeft || cornerPanelWindow.isTopRight
            left: cornerPanelWindow.isBottomLeft || cornerPanelWindow.isTopLeft
            bottom: cornerPanelWindow.isBottomLeft || cornerPanelWindow.isBottomRight
            right: cornerPanelWindow.isTopRight || cornerPanelWindow.isBottomRight
        }
        margins {
            right: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.right) * -1
            bottom: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.bottom) * -1
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        Item {
            id: cornerWidget
            anchors.fill: parent

            // Size for corner open interaction area
            readonly property int cornerOpenWidth: Config.options?.sidebar?.cornerOpen?.cornerRegionWidth ?? 20
            readonly property int cornerOpenHeight: Config.options?.sidebar?.cornerOpen?.cornerRegionHeight ?? 20
            readonly property int orbitHotCornerSize: Math.max(4, Math.min(40,
                Config.options?.orbit?.hotCornerSize ?? 12))
            readonly property int orbitHotCornerActivationDistance: Math.max(1, Math.min(32,
                Config.options?.orbit?.hotCornerActivationDistance ?? 2))
            readonly property int orbitHotCornerHitSize: Math.max(
                orbitHotCornerSize, orbitHotCornerActivationDistance)
            readonly property int quickNotesCornerSize: Math.max(4, Math.min(48,
                Config.options?.quickNotes?.cornerSize ?? 14))

            implicitWidth: Math.max(0,
                cornerPanelWindow.shouldShowSidebarCornerOpen ? cornerOpenWidth : 0,
                cornerPanelWindow.shouldShowOrbitHotCorner ? orbitHotCornerHitSize : 0,
                cornerPanelWindow.shouldShowQuickNotesCorner ? quickNotesCornerSize : 0)
            implicitHeight: Math.max(0,
                cornerPanelWindow.shouldShowSidebarCornerOpen ? cornerOpenHeight : 0,
                cornerPanelWindow.shouldShowOrbitHotCorner ? orbitHotCornerHitSize : 0,
                cornerPanelWindow.shouldShowQuickNotesCorner ? quickNotesCornerSize : 0)

            Loader {
                id: orbitHotCornerLoader
                active: cornerPanelWindow.shouldShowOrbitHotCorner
                anchors {
                    top: cornerPanelWindow.isTop ? parent.top : undefined
                    bottom: cornerPanelWindow.isBottom ? parent.bottom : undefined
                    left: cornerPanelWindow.isLeft ? parent.left : undefined
                    right: cornerPanelWindow.isRight ? parent.right : undefined
                }

                sourceComponent: MouseArea {
                    id: orbitHotCornerArea
                    implicitWidth: cornerWidget.orbitHotCornerHitSize
                    implicitHeight: cornerWidget.orbitHotCornerHitSize
                    hoverEnabled: true
                    property bool armed: true
                    property bool atCorner: false

                    function triggerOrbit(): void {
                        if (!armed || !atCorner)
                            return
                        armed = false
                        orbitDwellTimer.stop()
                        GlobalStates.openOrbit(cornerPanelWindow.screen?.name ?? "")
                    }

                    onPositionChanged: mouse => {
                        const distance = cornerWidget.orbitHotCornerActivationDistance
                        const atX = cornerPanelWindow.isRight
                            ? mouse.x >= width - distance : mouse.x <= distance
                        const atY = cornerPanelWindow.isTop
                            ? mouse.y <= distance : mouse.y >= height - distance
                        atCorner = atX && atY
                        if (!atCorner) {
                            armed = true
                            orbitDwellTimer.stop()
                            return
                        }
                        if (!armed)
                            return
                        const dwell = Config.options?.orbit?.hotCornerDwellMs ?? 0
                        if (dwell <= 0)
                            triggerOrbit()
                        else if (!orbitDwellTimer.running)
                            orbitDwellTimer.restart()
                    }
                    onExited: {
                        atCorner = false
                        orbitDwellTimer.stop()
                        if (!GlobalStates.overviewOpen || GlobalStates.overviewMode !== "orbit")
                            armed = true
                    }

                    Timer {
                        id: orbitDwellTimer
                        interval: Math.max(1, Config.options?.orbit?.hotCornerDwellMs ?? 0)
                        onTriggered: orbitHotCornerArea.triggerOrbit()
                    }
                }
            }

            // Bottom-left Quick Notes uses a dwell-gated synthetic
            // containsMouse property. StyledPopup can therefore keep its normal
            // pointer bridge between the tiny corner anchor and the popup body
            // without opening on accidental high-speed corner passes.
            Loader {
                id: quickNotesCornerLoader
                active: cornerPanelWindow.shouldShowQuickNotesCorner
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                }

                sourceComponent: Item {
                    id: quickNotesAnchor
                    implicitWidth: cornerWidget.quickNotesCornerSize
                    implicitHeight: cornerWidget.quickNotesCornerSize
                    property bool dwellReady: false
                    property bool containsMouse:
                        dwellReady && quickNotesHitArea.containsMouse

                    MouseArea {
                        id: quickNotesHitArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton

                        onEntered: {
                            if (quickNotesPopup.active) {
                                quickNotesDwellTimer.stop()
                                quickNotesAnchor.dwellReady = true
                            } else {
                                quickNotesDwellTimer.restart()
                            }
                        }
                        onExited: {
                            quickNotesDwellTimer.stop()
                            quickNotesAnchor.dwellReady = false
                        }
                    }

                    Timer {
                        id: quickNotesDwellTimer
                        interval: Math.max(1,
                            Config.options?.quickNotes?.hoverDelayMs ?? 220)
                        repeat: false
                        onTriggered: {
                            if (quickNotesHitArea.containsMouse)
                                quickNotesAnchor.dwellReady = true
                        }
                    }

                    QuickNotesPopup {
                        id: quickNotesPopup
                        anchorItem: quickNotesAnchor
                        cornerAttachmentEdge: cornerPanelWindow.quickNotesAttachmentEdge
                        cornerAttachmentThickness: cornerPanelWindow.quickNotesAttachmentThickness
                    }
                }
            }

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: cornerPanelWindow.shouldShowSidebarCornerOpen
                anchors {
                    top: (cornerPanelWindow.isTopLeft || cornerPanelWindow.isTopRight) ? parent.top : undefined
                    bottom: (cornerPanelWindow.isBottomLeft || cornerPanelWindow.isBottomRight) ? parent.bottom : undefined
                    left: (cornerPanelWindow.isLeft) ? parent.left : undefined
                    right: (cornerPanelWindow.isTopRight || cornerPanelWindow.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: cornerWidget.cornerOpenWidth
                    implicitHeight: cornerWidget.cornerOpenHeight
                    hoverEnabled: true
                    onPositionChanged: {
                        if (Config.options?.sidebar?.cornerOpen?.clickless ?? false) return;
                        if (!(Config.options?.sidebar?.cornerOpen?.clicklessCornerEnd ?? false)) return;
                        const verticalOffset = Config.options?.sidebar?.cornerOpen?.clicklessCornerVerticalOffset ?? 10;
                        const correctX = (cornerPanelWindow.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerPanelWindow.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerPanelWindow.isTop && mouseArea.mouseY > verticalOffset || cornerPanelWindow.isBottom && mouseArea.mouseY < mouseArea.height - verticalOffset);
                        if (correctX && correctY)
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                    }
                    onEntered: {
                        if (Config.options?.sidebar?.cornerOpen?.clickless ?? false)
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                    }
                    onPressed: {
                        if (!(Config.options?.sidebar?.cornerOpen?.clickless ?? false)) {
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                            if (Config.options?.background?.effects?.ripple?.hotcorners ?? true) {
                                GlobalStates.requestRipple(0, 0, cornerPanelWindow.screen.name);
                            }
                        }
                    }
                    onScrollDown: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerPanelWindow.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness - 0.05);
                        else {
                            Audio.decrementVolume();
                        }
                    }
                    onScrollUp: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerPanelWindow.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness + 0.05);
                        else {
                            Audio.incrementVolume();
                        }
                    }
                    onMovedAway: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerPanelWindow.isLeft)
                            GlobalStates.osdBrightnessOpen = false;
                        else
                            GlobalStates.osdVolumeOpen = false;
                    }

                    Loader {
                        active: Config.options?.sidebar?.cornerOpen?.visualize ?? false
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData
            property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(modelData) : null

            // Hide when fullscreen
            property list<HyprlandWorkspace> workspacesForMonitor: CompositorService.isHyprland
                ? Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
                : []
            property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
            property bool fullscreen: {
                if (CompositorService.isHyprland) {
                    return activeWorkspaceWithFullscreen != undefined;
                }
                // Corner windows are interaction-only and reserve no work area,
                // so they can safely follow automatic fullscreen detection.
                if (CompositorService.isNiri)
                    return GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
                return false;
            }

            CornerPanelWindow {
                screen: modelData
                corner: "topLeft"
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: "topRight"
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: "bottomLeft"
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: "bottomRight"
                fullscreen: monitorScope.fullscreen
            }
        }
    }
}
