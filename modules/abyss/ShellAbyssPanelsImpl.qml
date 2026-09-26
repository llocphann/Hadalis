import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common

// Critical and specialist workflows deliberately retain their shared renderer.
// Native perimeter content is composed by the critical Abyss host.
Item {
    component DemandPanel: LazyLoader {
        required property string identifier
        property bool open: false
        active: Config.ready && GlobalStates.deferredPanelsReady && open
            && (Config.options?.enabledPanels ?? []).includes(identifier)
    }
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssLock")
        source: "../lock/Lock.qml"
    }
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("abyssPolkit")
        source: "../polkit/Polkit.qml"
    }
    DemandPanel { identifier: "abyssSessionScreen"; open: GlobalStates.sessionOpen; source: "../sessionScreen/SessionScreen.qml" }
    DemandPanel { identifier: "iiRegionSelector"; open: GlobalStates.regionSelectorOpen; source: "../regionSelector/RegionSelector.qml" }
    DemandPanel { identifier: "iiTilingOverlay"; open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen; source: "../tilingOverlay/TilingOverlay.qml" }
    DemandPanel { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; source: "../onScreenKeyboard/OnScreenKeyboard.qml" }
    DemandPanel { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; source: "../cheatsheet/Cheatsheet.qml" }
    DemandPanel { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; source: "../wallpaperSelector/WallpaperSelector.qml" }
    DemandPanel { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; source: "../wallpaperLauncher/WallpaperLauncher.qml" }
    DemandPanel { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; source: "../wallpaperSelector/WallpaperCoverflow.qml" }
    DemandPanel { identifier: "iiShellUpdate"; open: ShellUpdates.overlayOpen; source: "../shellUpdate/ShellUpdateOverlay.qml" }
    DemandPanel { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; source: "../recordingOsd/RecordingOsd.qml" }
}
