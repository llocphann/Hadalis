pragma ComponentBehavior: Bound

import qs.modules.bootGreeting
import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.tilingOverlay
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.clipboard as ClipboardModule

import qs.modules.waffle.actionCenter
import qs.modules.waffle.altSwitcher as WaffleAltSwitcherModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services
import qs.services.deferred

Item {
    id: root

    readonly property var waffleAltSwitcherOptions:
        Config.options?.waffles?.altSwitcher ?? ({})
    readonly property string waffleAltSwitcherPreset:
        root.waffleAltSwitcherOptions.preset ?? "thumbnails"
    readonly property bool waffleAltSwitcherVisual:
        root.waffleAltSwitcherPreset !== "none"
        && !((root.waffleAltSwitcherOptions.noVisualUi ?? false)
            && root.waffleAltSwitcherPreset !== "skew")

    // Immediate panels — visible at first frame or must catch early events
    component PanelLoader: LazyLoader {
        id: panelLoader
        required property string identifier
        property bool extraCondition: true
        property string workflowSourcePath: ""
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        active: enabledPanel
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: panelLoader
                panelId: panelLoader.identifier
                sourcePath: panelLoader.workflowSourcePath
                configured: panelLoader.enabledPanel
                presented: panelLoader.active
            }
    }

    // Deferred panels — loaded asynchronously after first frame to reduce boot contention
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
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 250
        property int retainIdleMs: 5 * 60 * 1000
        property bool resident: open
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
        }
        property Timer retainIdle: Timer {
            interval: onDemandLoader.retainIdleMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
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
            } else if (retainAfterUse && used) {
                retainIdle.restart()
            } else {
                closeGrace.restart()
            }
        }
        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    // === Immediate feedback panels within the deferred host ===
    // Core Waffle surfaces (bar/background/backdrop) are owned by the critical
    // startup host so they are not delayed by the rest of this module.
    PanelLoader { identifier: "wNotificationPopup"; workflowSourcePath: "modules/waffle/notificationPopup/WaffleNotificationPopup.qml"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wOnScreenDisplay"; workflowSourcePath: "modules/waffle/onScreenDisplay/WaffleOSD.qml"; component: WaffleOSDModule.WaffleOSD {} }

    // === Deferred panels ===
    OnDemandPanelLoader { identifier: "wStartMenu"; open: GlobalStates.searchOpen; retainAfterUse: true; workflowSourcePath: "modules/waffle/startMenu/WaffleStartMenu.qml"; component: WaffleStartMenu {} }
    OnDemandPanelLoader { identifier: "wActionCenter"; open: GlobalStates.waffleActionCenterOpen; retainAfterUse: true; workflowSourcePath: "modules/waffle/actionCenter/WaffleActionCenter.qml"; component: WaffleActionCenter {} }
    OnDemandPanelLoader { identifier: "wNotificationCenter"; open: GlobalStates.waffleNotificationCenterOpen; workflowSourcePath: "modules/waffle/notificationCenter/WaffleNotificationCenter.qml"; component: WaffleNotificationCenter {} }
    OnDemandPanelLoader { identifier: "wWidgets"; open: GlobalStates.waffleWidgetsOpen && (Config.options?.waffles?.modules?.widgets ?? true); workflowSourcePath: "modules/waffle/widgets/WaffleWidgets.qml"; component: WaffleWidgets {} }
    DeferredPanelLoader { identifier: "wLock"; workflowSourcePath: "modules/lock/Lock.qml"; component: Lock {} }
    DeferredPanelLoader { identifier: "wPolkit"; workflowSourcePath: "modules/polkit/Polkit.qml"; component: Polkit {} }
    OnDemandPanelLoader { identifier: "wSessionScreen"; open: GlobalStates.sessionOpen; workflowSourcePath: "modules/sessionScreen/SessionScreen.qml"; component: SessionScreen {} }
    OnDemandPanelLoader { identifier: "wTaskView"; open: GlobalStates.waffleTaskViewOpen; workflowSourcePath: "modules/waffle/taskview/WaffleTaskView.qml"; component: WaffleTaskViewModule.WaffleTaskView {} }

    // Shared modules that work with waffle
    OnDemandPanelLoader { identifier: "iiBootGreeting"; open: GlobalStates.bootGreetingOpen; workflowSourcePath: "modules/bootGreeting/BootGreeting.qml"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; workflowSourcePath: "modules/cheatsheet/Cheatsheet.qml"; component: Cheatsheet {} }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; workflowSourcePath: "modules/onScreenKeyboard/OnScreenKeyboard.qml"; component: OnScreenKeyboard {} }
    OnDemandPanelLoader { identifier: "iiOverlay"; open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets || OverlayContext.nativeDialogOpen; workflowSourcePath: "modules/ii/overlay/Overlay.qml"; component: Overlay {} }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; workflowSourcePath: "modules/overview/Overview.qml"; component: Overview {} }

    DeferredPanelLoader { identifier: "iiRegionSelector"; workflowSourcePath: "modules/regionSelector/RegionSelector.qml"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; workflowSourcePath: "modules/screenCorners/ScreenCorners.qml"; component: ScreenCorners {} }

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; workflowSourcePath: "modules/wallpaperSelector/WallpaperSelector.qml"; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; workflowSourcePath: "modules/wallpaperLauncher/WallpaperLauncher.qml"; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; workflowSourcePath: "modules/wallpaperSelector/WallpaperCoverflow.qml"; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; extraCondition: Config.options?.panelFamily !== "waffle"; workflowSourcePath: "modules/clipboard/ClipboardPanel.qml"; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; workflowSourcePath: "modules/recordingOsd/RecordingOsd.qml"; component: RecordingOsd {} }

    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        workflowSourcePath: "modules/tilingOverlay/TilingOverlay.qml"
        component: TilingOverlay {}
    }

    LazyLoader {
        id: waffleClipboardLoader
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"
        component: WaffleClipboardModule.WaffleClipboard {}
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: waffleClipboardLoader
                panelId: "wClipboard"
                sourcePath: "modules/waffle/clipboard/WaffleClipboard.qml"
                configured: Config.ready && Config.options?.panelFamily === "waffle"
                presented: waffleClipboardLoader.active
            }
    }

    LazyLoader {
        id: waffleAltSwitcherLoader
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
            && root.waffleAltSwitcherVisual
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady
            && Config.options?.panelFamily === "waffle"
            && root.waffleAltSwitcherVisual
        component: WaffleAltSwitcherModule.WaffleAltSwitcher {}
        property CodeWorkflowRuntimeDeclaration workflowDeclaration:
            CodeWorkflowRuntimeDeclaration {
                loader: waffleAltSwitcherLoader
                panelId: "wAltSwitcher"
                sourcePath: "modules/waffle/altSwitcher/WaffleAltSwitcher.qml"
                configured: Config.ready
                    && Config.options?.panelFamily === "waffle"
                    && root.waffleAltSwitcherVisual
                presented: waffleAltSwitcherLoader.active
            }
    }

    WaffleBackgroundModule.WaffleShellEditHud {}
}