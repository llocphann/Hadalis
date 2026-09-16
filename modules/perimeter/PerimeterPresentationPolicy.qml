pragma Singleton

import QtQuick
import Quickshell
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

    function _outputAllowed(screenList, outputName: string): bool {
        const name = String(outputName ?? "")
        if (!name)
            return false
        const list = screenList ?? []
        if (!list || list.length === 0)
            return true
        const matchedScreens = Quickshell.screens.filter(screen => {
            const screenName = String(screen?.name ?? "")
            return screenName.length > 0 && list.includes(screenName)
        })
        // Match legacy Bar/Dock fallback safety: if every configured monitor name
        // is stale after output re-enumeration, keep the surface on all outputs.
        return matchedScreens.length === 0 || list.includes(name)
    }

    function barOutputEnabled(outputName: string): bool {
        return root._outputAllowed(Config.options?.bar?.screenList ?? [], outputName)
    }

    function dockOutputEnabled(outputName: string): bool {
        return root._outputAllowed(Config.options?.dock?.screenList ?? [], outputName)
    }

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

    function barPresentedForOutput(outputName: string): bool {
        return root.barPresented && root.barOutputEnabled(outputName)
    }

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

    function dockPresentedForOutput(outputName: string, edge: string): bool {
        return root.dockOutputEnabled(outputName) && root.dockPresented(edge)
    }
}
