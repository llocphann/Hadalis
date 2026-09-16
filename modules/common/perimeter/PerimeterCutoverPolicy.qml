pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

QtObject {
    id: root

    readonly property bool requested:
        (Config.options?.enabledPanels ?? []).includes("iiPerimeter")
    // Match shell.qml's family loader contract exactly: every non-Waffle value
    // resolves to the ii panel tree, while Waffle unloads all ii critical/panel
    // hosts. Keep request intent persistent across family switches, but never
    // report the perimeter runtime active when its owning family is not loaded.
    readonly property bool familyActive:
        (Config.options?.panelFamily ?? "ii") !== "waffle"

    function modulePlacedAnywhere(moduleId: string): bool {
        const targetModule = String(moduleId ?? "")
        if (!targetModule)
            return false
        for (const screen of Quickshell.screens) {
            const outputName = String(screen?.name ?? "")
            if (!outputName || !PerimeterConfig.validate(outputName))
                continue
            for (const slotId of PerimeterTopology.slotIds) {
                for (const instanceId of PerimeterConfig.slotInstanceIds(outputName, slotId)) {
                    const instance = PerimeterConfig.instanceDescriptor(outputName, instanceId)
                    if (String(instance?.moduleId ?? "") === targetModule)
                        return true
                }
            }
        }
        return false
    }

    function reservationKindPlacedAnywhere(reservationKind: string): bool {
        const targetKind = String(reservationKind ?? "")
        if (!targetKind)
            return false
        for (const screen of Quickshell.screens) {
            const outputName = String(screen?.name ?? "")
            if (!outputName || !PerimeterConfig.validate(outputName))
                continue
            for (const slotId of PerimeterTopology.slotIds) {
                for (const instanceId of PerimeterConfig.slotInstanceIds(outputName, slotId)) {
                    const instance = PerimeterConfig.instanceDescriptor(outputName, instanceId)
                    const registration = ModuleRegistry.resolve(instance?.moduleId)
                    if (String(registration?.reservationKind ?? "") === targetKind)
                        return true
                }
            }
        }
        return false
    }

    // Placement is perimeter-owned once the user opts in, but some legacy
    // behavior policies still need dedicated adapters. `enabledPanels` decides
    // whether a semantic surface is enabled; PerimeterConfig alone decides
    // whether Connected Perimeter actually owns an instance on any output.
    // Unsupported legacy behavior must not resurrect chrome that the perimeter
    // layout intentionally left unplaced.
    readonly property bool compatibilityReady: {
        Config.revision
        ModuleRegistry.moduleIds
        if (!Config.ready)
            return false
        const enabledPanels = Config.options?.enabledPanels ?? []
        const barIdentifier = (Config.options?.bar?.vertical ?? false)
            ? "iiVerticalBar" : "iiBar"
        const barOwned = enabledPanels.includes(barIdentifier)
            && root.reservationKindPlacedAnywhere("bar")
        const barAutoHide = Config.options?.bar?.autoHide?.enable ?? false
        const barPolicySupported = !barOwned || !barAutoHide

        const dockOwned = enabledPanels.includes("iiDock")
            && root.reservationKindPlacedAnywhere("dock")
        const dockEnabled = Config.options?.dock?.enable ?? true
        const dockPinned = Config.options?.dock?.pinnedOnStartup ?? true
        const dockHoverReveal = Config.options?.dock?.hoverToReveal ?? false
        const dockPolicySupported = !dockOwned || !dockEnabled
            || (dockPinned && !dockHoverReveal)

        // Legacy SidebarHost owns the edge-hover activation strip. Connected
        // Perimeter does not implement that interaction yet, so keep legacy
        // ownership only when an enabled semantic sidebar is actually placed.
        const leftSidebarOwned = enabledPanels.includes("iiSidebarLeft")
            && root.modulePlacedAnywhere("left-sidebar")
        const rightSidebarOwned = enabledPanels.includes("iiSidebarRight")
            && root.modulePlacedAnywhere("right-sidebar")
        const sidebarOwned = leftSidebarOwned || rightSidebarOwned
        const sidebarEdgeOpen = Config.options?.sidebar?.edgeOpen?.enable ?? false
        const sidebarPolicySupported = !sidebarOwned || !sidebarEdgeOpen

        return barPolicySupported && dockPolicySupported
            && sidebarPolicySupported
    }
    readonly property bool configurationValid: {
        Config.revision
        if (!Config.ready || Quickshell.screens.length === 0)
            return false
        for (const screen of Quickshell.screens) {
            const outputName = String(screen?.name ?? "")
            if (!outputName || !PerimeterConfig.validate(outputName))
                return false
        }
        return true
    }
    readonly property bool sourcesReady: {
        // Track registry replacement as a first-class dependency so a source
        // registration/reset immediately re-evaluates cutover readiness.
        ModuleRegistry.moduleIds
        if (!root.configurationValid)
            return false
        for (const screen of Quickshell.screens) {
            const outputName = String(screen?.name ?? "")
            if (!outputName
                    || !ModuleRegistry.validateConfiguredModules(
                        outputName, true))
                return false
        }
        return true
    }
    readonly property bool enabled: root.requested
        && root.familyActive
        && root.compatibilityReady
        && root.configurationValid
        && root.sourcesReady
    readonly property bool fallbackActive: root.requested && !root.enabled
    readonly property string statusReason: {
        if (!root.requested)
            return "disabled"
        if (!Config.ready)
            return "config-loading"
        if (!root.familyActive)
            return "inactive-family"
        if (Quickshell.screens.length === 0)
            return "no-outputs"
        if (!root.configurationValid)
            return "invalid-config"
        if (!root.compatibilityReady)
            return "unsupported-runtime-policy"
        if (!root.sourcesReady)
            return "missing-module-source"
        return "active"
    }
}
