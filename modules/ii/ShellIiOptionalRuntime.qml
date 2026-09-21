pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

// Non-core ii runtime. This file is intentionally source-loaded by
// ShellIiPanelsImpl so an optional renderer/integration regression cannot make
// Sidebar, Dashboard, Overview, RegionSelector or ShellUpdate unavailable.
Item {
    id: root

    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property int closeGraceMs: 300
        property bool resident: open
        readonly property bool configuredPanelEnabled:
            (Config.options?.enabledPanels ?? []).includes(identifier)
        readonly property bool enabledPanel: Config.ready
            && (configuredPanelEnabled || open)
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
        }

        onOpenChanged: {
            if (open) {
                closeGrace.stop()
                resident = true
            } else {
                closeGrace.restart()
            }
        }

        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    OnDemandPanelLoader {
        identifier: "iiOverlay"
        open: GlobalStates.overlayOpen
            || OverlayContext.hasPinnedWidgets
            || OverlayContext.nativeDialogOpen
        source: "overlay/Overlay.qml"
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "controlPanelToggle"
            description: "Toggles control panel on press"
            onPressed: GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut { name: "oskToggle"; description: "Toggles on screen keyboard on press"; onPressed: GlobalStates.oskOpen = !GlobalStates.oskOpen }
            GlobalShortcut { name: "oskOpen"; description: "Opens on screen keyboard on press"; onPressed: GlobalStates.oskOpen = true }
            GlobalShortcut { name: "oskClose"; description: "Closes on screen keyboard on press"; onPressed: GlobalStates.oskOpen = false }
            GlobalShortcut { name: "overlayToggle"; description: "Toggles overlay on press"; onPressed: GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
            GlobalShortcut { name: "sessionToggle"; description: "Toggles session screen on press"; onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
            GlobalShortcut { name: "sessionOpen"; description: "Opens session screen on press"; onPressed: GlobalStates.sessionOpen = true }
            GlobalShortcut { name: "sessionClose"; description: "Closes session screen on press"; onPressed: GlobalStates.sessionOpen = false }
            GlobalShortcut { name: "cheatsheetToggle"; description: "Toggles cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
            GlobalShortcut { name: "cheatsheetOpen"; description: "Opens cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = true }
            GlobalShortcut { name: "cheatsheetClose"; description: "Closes cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = false }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "mediaControlsToggle"
                description: "Toggles media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
            GlobalShortcut {
                name: "mediaControlsOpen"
                description: "Opens media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = true
            }
            GlobalShortcut {
                name: "mediaControlsClose"
                description: "Closes media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = false
            }
            GlobalShortcut {
                name: "mediaControlsPlayPause"
                description: "Toggles play/pause when media controls are open"
                onPressed: {
                    const player = MprisController.activePlayer
                    if (GlobalStates.mediaControlsOpen && player?.canTogglePlaying)
                        player.togglePlaying()
                }
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarLeftToggle"
                description: "Toggles left sidebar on press"
                onPressed: GlobalStates.toggleSidebarLeft("")
            }
            GlobalShortcut {
                name: "sidebarLeftOpen"
                description: "Opens left sidebar on press"
                onPressed: GlobalStates.openSidebarLeft("")
            }
            GlobalShortcut {
                name: "sidebarLeftClose"
                description: "Closes left sidebar on press"
                onPressed: GlobalStates.closeSidebarLeft()
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarRightToggle"
                description: "Toggles right sidebar on press"
                onPressed: GlobalStates.toggleSidebarRight("")
            }
            GlobalShortcut {
                name: "sidebarRightOpen"
                description: "Opens right sidebar on press"
                onPressed: GlobalStates.openSidebarRight("")
            }
            GlobalShortcut {
                name: "sidebarRightClose"
                description: "Closes right sidebar on press"
                onPressed: GlobalStates.closeSidebarRight()
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "dashboardToggle"
            description: "Toggles the dashboard on press"
            onPressed: GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
        }
    }

    LazyLoader {
        active: Config.ready && (Config.options?.background?.effects?.ripple?.enable ?? false)
        component: Variants {
            model: Quickshell.screens

            PanelWindow {
                id: rippleWindow
                required property ShellScreen modelData
                screen: modelData
                focusable: false
                color: "transparent"
                visible: ripple.playing

                WlrLayershell.namespace: "quickshell:charging-ripple"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                implicitWidth: modelData.width
                implicitHeight: modelData.height

                FluidRipple {
                    id: ripple
                    anchors.fill: parent
                    color: Appearance.colors.colPrimary
                    duration: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000

                    Component.onCompleted: {
                        if (Config.options?.background?.effects?.ripple?.reload ?? true)
                            spawn()
                    }

                    Connections {
                        target: Battery
                        function onIsPluggedInChanged() {
                            if (Config.options?.background?.effects?.ripple?.charging ?? true)
                                ripple.spawn()
                        }
                    }

                    Connections {
                        target: NiriService
                        function onInOverviewChanged() {
                            if (NiriService.inOverview
                                    && (Config.options?.background?.effects?.ripple?.overview ?? true)
                                    && rippleWindow.modelData.name === NiriService.currentOutput)
                                ripple.spawn(0, 0)
                        }
                    }

                    Connections {
                        target: GlobalStates
                        function onScreenLockedChanged() {
                            if (GlobalStates.screenLocked
                                    && (Config.options?.background?.effects?.ripple?.lock ?? true))
                                ripple.spawn()
                        }
                        function onSessionOpenChanged() {
                            if (GlobalStates.sessionOpen
                                    && (Config.options?.background?.effects?.ripple?.session ?? true))
                                ripple.spawn()
                        }
                        function onRequestRipple(x: real, y: real, screenName: string) {
                            if (rippleWindow.modelData.name === screenName)
                                ripple.spawn(x, y)
                        }
                    }
                }
            }
        }
    }

    ShellLayoutEditorWindow {
        family: "ii"
        styleKey: Appearance.globalStyle
        accentColor: Appearance.colors.colPrimary
        surfaceColor: Appearance.colors.colLayer1
        elevatedSurfaceColor: Appearance.colors.colLayer2
        textColor: Appearance.colors.colOnLayer1
        secondaryTextColor: Appearance.colors.colSubtext
        borderColor: Appearance.colors.colLayer0Border
        fontFamily: Appearance.font.family.main
        titlePixelSize: Appearance.font.pixelSize.normal
        bodyPixelSize: Appearance.font.pixelSize.smaller
        smallPixelSize: Appearance.font.pixelSize.smallest
        panelRadius: Appearance.rounding.large
        controlRadius: Appearance.rounding.full
        animationDuration: Appearance.animationsEnabled
            ? Appearance.animation.elementMoveFast.duration : 0
    }
}
