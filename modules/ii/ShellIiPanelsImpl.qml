pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

Item {
    id: panelsRoot

    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        loading: enabledPanel
        activeAsync: enabledPanel
    }

    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        loading: Config.ready && GlobalStates.shellEntryReady
            && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
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
    PanelLoader { identifier: "iiNotificationPopup"; source: "../notificationPopup/NotificationPopup.qml" }
    PanelLoader { identifier: "iiOnScreenDisplay"; source: "../onScreenDisplay/OnScreenDisplay.qml" }

    DeferredPanelLoader { identifier: "iiBootGreeting"; source: "../bootGreeting/BootGreeting.qml" }
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
        keepLoaded: Config.options?.dashboard?.keepLoaded ?? false
        source: "../dashboard/Dashboard.qml"
    }
    DeferredPanelLoader { identifier: "iiLock"; source: "../lock/Lock.qml" }
    DeferredPanelLoader { identifier: "iiMediaControls"; source: "../mediaControls/MediaControls.qml" }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; source: "../onScreenKeyboard/OnScreenKeyboard.qml" }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; source: "../overview/Overview.qml" }
    DeferredPanelLoader { identifier: "iiPolkit"; source: "../polkit/Polkit.qml" }

    DeferredPanelLoader { identifier: "iiRegionSelector"; source: "../regionSelector/RegionSelector.qml" }
    DeferredPanelLoader { identifier: "iiScreenCorners"; source: "../screenCorners/ScreenCorners.qml" }
    OnDemandPanelLoader { identifier: "iiSessionScreen"; open: GlobalStates.sessionOpen; source: "../sessionScreen/SessionScreen.qml" }

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
        source: "../tilingOverlay/TilingOverlay.qml"
    }

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; source: "../wallpaperSelector/WallpaperSelector.qml" }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; source: "../wallpaperLauncher/WallpaperLauncher.qml" }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; source: "../wallpaperSelector/WallpaperCoverflow.qml" }
    OnDemandPanelLoader { identifier: "iiClipboard"; open: GlobalStates.clipboardOpen; retainAfterUse: true; closeGraceMs: 250; source: "../clipboard/ClipboardPanel.qml" }
    OnDemandPanelLoader { identifier: "iiShellUpdate"; open: ShellUpdates.overlayOpen; closeGraceMs: 250; source: "../shellUpdate/ShellUpdateOverlay.qml" }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; source: "../recordingOsd/RecordingOsd.qml" }

    // Optional integrations/renderers are isolated behind a URL boundary so a
    // failure there cannot take down the deferred core panel router.
    LazyLoader {
        loading: Config.ready && GlobalStates.deferredPanelsReady
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady
        source: "ShellIiOptionalRuntime.qml"
    }

}
