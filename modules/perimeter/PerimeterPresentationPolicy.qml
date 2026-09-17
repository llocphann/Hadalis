pragma Singleton

import QtQuick
import qs
import qs.modules.common

QtObject {
    id: root

    readonly property var enabledPanels: Config.options?.enabledPanels ?? []
    readonly property bool barSurfaceEnabled: {
        const identifier = (Config.options?.bar?.vertical ?? false)
            ? "iiVerticalBar" : "iiBar"
        return root.enabledPanels.includes(identifier)
    }
    readonly property bool dockSurfaceEnabled:
        root.enabledPanels.includes("iiDock")

    function sidebarSurfaceEnabled(featureRole: bool): bool {
        return root.enabledPanels.includes(featureRole
            ? "iiSidebarLeft" : "iiSidebarRight")
    }

    // Legacy Bar stays instantiated before shell entry but its content is fully
    // off-screen. Collapse perimeter bar-family modules during the same transient
    // states while leaving reservation semantics to PerimeterReservationPolicy.
    readonly property bool barPresented: root.barSurfaceEnabled
        && GlobalStates.barOpen
        && GlobalStates.shellEntryReady
        && !GlobalStates.coverflowSelectorOpen
        && !GlobalStates.widgetEditMode

    function dockPresented(edge: string): bool {
        if (!root.dockSurfaceEnabled
                || !(Config.options?.dock?.enable ?? true)
                || !GlobalStates.shellEntryReady
                || GlobalStates.coverflowSelectorOpen
                || GlobalStates.widgetEditMode)
            return false
        // Legacy Dock yields the bottom edge while the wallpaper launcher is
        // open. Other edges are unaffected by that launcher-specific policy.
        return !(GlobalStates.wallpaperLauncherOpen
            && String(edge ?? "bottom") === "bottom")
    }
}
