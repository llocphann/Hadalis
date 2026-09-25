pragma ComponentBehavior: Bound

import qs.modules.bootGreeting
import qs.modules.lock
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.tilingOverlay
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.shellUpdate
import qs.modules.clipboard as ClipboardModule

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: panelsRoot

    component PanelLoader: LazyLoader {
        id: panelLoader
        required property string identifier
        property bool extraCondition: true
        property string workflowSourcePath: ""
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        loading: enabledPanel
        activeAsync: enabledPanel
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: panelLoader
                panelId: panelLoader.identifier
                sourcePath: panelLoader.workflowSourcePath
                configured: panelLoader.enabledPanel
                presented: panelLoader.active
            }
    }

    component DeferredPanelLoader: LazyLoader {
        id: deferredPanelLoader
        required property string identifier
        property bool extraCondition: true
        property string workflowSourcePath: ""
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        loading: Config.ready && GlobalStates.shellEntryReady && enabledPanel
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && enabledPanel
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: deferredPanelLoader
                panelId: deferredPanelLoader.identifier
                sourcePath: deferredPanelLoader.workflowSourcePath
                configured: deferredPanelLoader.enabledPanel
                presented: deferredPanelLoader.active
            }
    }

    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property bool keepLoaded: false
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 300
        property int retainIdleMs: 5 * 60 * 1000
        property bool resident: open || keepLoaded
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open || onDemandLoader.keepLoaded
        }
        property Timer retainIdle: Timer {
            interval: onDemandLoader.retainIdleMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open || onDemandLoader.keepLoaded
        }
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
        property string workflowSourcePath: ""
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: onDemandLoader
                panelId: onDemandLoader.identifier
                sourcePath: onDemandLoader.workflowSourcePath
                configured: onDemandLoader.enabledPanel
                presented: onDemandLoader.open
            }

        onOpenChanged: {
            if (open) {
                used = true
                closeGrace.stop()
                retainIdle.stop()
                resident = true
            } else if (!keepLoaded) {
                if (retainAfterUse && used)
                    retainIdle.restart()
                else
                    closeGrace.restart()
            }
        }
        onKeepLoadedChanged: {
            if (keepLoaded) {
                closeGrace.stop()
                retainIdle.stop()
                resident = true
            } else if (!open) {
                if (retainAfterUse && used)
                    retainIdle.restart()
                else
                    closeGrace.restart()
            }
        }

        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    function screensFor(list: var): var {
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matched.length > 0 ? matched : screens
    }

    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; source: "../background/Backdrop.qml" }
    PanelLoader { identifier: "iiNotificationPopup"; workflowSourcePath: "modules/notificationPopup/NotificationPopup.qml"; component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; workflowSourcePath: "modules/onScreenDisplay/OnScreenDisplay.qml"; component: OnScreenDisplay {} }

    OnDemandPanelLoader { identifier: "iiBootGreeting"; open: GlobalStates.bootGreetingOpen; workflowSourcePath: "modules/bootGreeting/BootGreeting.qml"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; source: "../cheatsheet/Cheatsheet.qml" }
    OnDemandPanelLoader {
        identifier: "iiControlPanel"
        open: GlobalStates.controlPanelOpen
        keepLoaded: Config.options?.controlPanel?.keepLoaded ?? false
        source: "../controlPanel/ControlPanel.qml"
    }
    OnDemandPanelLoader {
        identifier: "iiDashboard"
        open: GlobalStates.dashboardOpen
        // Lazy until first use, then resident for the shell session. Dashboard
        // owns its own hidden render/input gating while closed.
        keepLoaded: (Config.options?.dashboard?.keepLoaded ?? false) || used
        source: "../dashboard/Dashboard.qml"
    }
    DeferredPanelLoader { identifier: "iiLock"; workflowSourcePath: "modules/lock/Lock.qml"; component: Lock {} }
    OnDemandPanelLoader {
        identifier: "iiMediaControls"
        open: GlobalStates.mediaControlsOpen
        // Avoid boot-time player/screen binding fan-out. Keep the lightweight
        // outer scope warm briefly after first use; its own player surface still
        // releases after the existing 350 ms close animation.
        retainAfterUse: true
        workflowSourcePath: "modules/mediaControls/MediaControls.qml"
        component: MediaControls {}
    }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; workflowSourcePath: "modules/onScreenKeyboard/OnScreenKeyboard.qml"; component: OnScreenKeyboard {} }
    OnDemandPanelLoader {
        identifier: "iiOverlay"
        open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets || OverlayContext.nativeDialogOpen
        workflowSourcePath: "modules/ii/overlay/Overlay.qml"
        component: Overlay {}
    }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; source: "../overview/Overview.qml" }
    DeferredPanelLoader { identifier: "iiPolkit"; workflowSourcePath: "modules/polkit/Polkit.qml"; component: Polkit {} }

    DeferredPanelLoader { identifier: "iiRegionSelector"; workflowSourcePath: "modules/regionSelector/RegionSelector.qml"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; workflowSourcePath: "modules/screenCorners/ScreenCorners.qml"; component: ScreenCorners {} }
    OnDemandPanelLoader { identifier: "iiSessionScreen"; open: GlobalStates.sessionOpen; workflowSourcePath: "modules/sessionScreen/SessionScreen.qml"; component: SessionScreen {} }

    Variants {
        model: panelsRoot.screensFor(Config.options?.sidebar?.screenList ?? [])

        PanelWindow {
            id: dualSidebarBackdrop
            required property var modelData
            readonly property bool leftPresented:
                (Config.options?.enabledPanels ?? []).includes("iiSidebarLeft")
                && GlobalStates.sidebarLeftOpen
                && GlobalStates.sidebarLeftPresentationOutput === (modelData?.name ?? "")
            readonly property bool rightPresented:
                (Config.options?.enabledPanels ?? []).includes("iiSidebarRight")
                && GlobalStates.sidebarRightOpen
                && GlobalStates.sidebarRightPresentationOutput === (modelData?.name ?? "")
            screen: modelData
            visible: leftPresented || rightPresented
            updatesEnabled: leftPresented || rightPresented
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:dualSidebarBackdrop"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item { id: emptyDualSidebarMask; width: 0; height: 0 }
            mask: Region {
                item: dualSidebarBackdrop.leftPresented || dualSidebarBackdrop.rightPresented
                    ? dualSidebarBackdropArea : emptyDualSidebarMask
            }

            MouseArea {
                id: dualSidebarBackdropArea
                anchors.fill: parent
                enabled: dualSidebarBackdrop.leftPresented || dualSidebarBackdrop.rightPresented
                onClicked: {
                    if (dualSidebarBackdrop.leftPresented)
                        GlobalStates.closeSidebarLeft()
                    if (dualSidebarBackdrop.rightPresented)
                        GlobalStates.closeSidebarRight()
                }
            }
        }
    }

    DeferredPanelLoader { identifier: "iiSidebarLeft"; source: "../sidebarLeft/SidebarLeft.qml" }
    DeferredPanelLoader { identifier: "iiSidebarRight"; source: "../sidebarRight/SidebarRight.qml" }

    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        workflowSourcePath: "modules/tilingOverlay/TilingOverlay.qml"
        component: TilingOverlay {}
    }

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; workflowSourcePath: "modules/wallpaperSelector/WallpaperSelector.qml"; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; workflowSourcePath: "modules/wallpaperLauncher/WallpaperLauncher.qml"; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; workflowSourcePath: "modules/wallpaperSelector/WallpaperCoverflow.qml"; component: WallpaperCoverflow {} }
    OnDemandPanelLoader { identifier: "iiClipboard"; open: GlobalStates.clipboardOpen; retainAfterUse: true; closeGraceMs: 250; workflowSourcePath: "modules/clipboard/ClipboardPanel.qml"; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiShellUpdate"; open: ShellUpdates.overlayOpen; closeGraceMs: 250; workflowSourcePath: "modules/shellUpdate/ShellUpdateOverlay.qml"; component: ShellUpdateOverlay {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; workflowSourcePath: "modules/recordingOsd/RecordingOsd.qml"; component: RecordingOsd {} }

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
                        if (Config.options?.background?.effects?.ripple?.reload ?? true) {
                            spawn();
                        }
                    }

                    Connections {
                        target: Battery
                        function onIsPluggedInChanged() {
                            if (Config.options?.background?.effects?.ripple?.charging ?? true) {
                                ripple.spawn();
                            }
                        }
                    }

                    Connections {
                        target: NiriService
                        function onInOverviewChanged() {
                            if (NiriService.inOverview && (Config.options?.background?.effects?.ripple?.overview ?? true)) {
                                if (rippleWindow.modelData.name === NiriService.currentOutput) {
                                    ripple.spawn(0, 0);
                                }
                            }
                        }
                    }

                    Connections {
                        target: GlobalStates
                        function onScreenLockedChanged() {
                            if (GlobalStates.screenLocked && (Config.options?.background?.effects?.ripple?.lock ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onSessionOpenChanged() {
                            if (GlobalStates.sessionOpen && (Config.options?.background?.effects?.ripple?.session ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onRequestRipple(x: real, y: real, screenName: string) {
                            if (rippleWindow.modelData.name === screenName) {
                                ripple.spawn(x, y);
                            }
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
