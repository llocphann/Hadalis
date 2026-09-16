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

    // Placement is perimeter-owned once the user opts in, but some legacy
    // behavior policies still need dedicated adapters. Fail safe to legacy for
    // unsupported modes only when the corresponding surface is actually owned;
    // disabled chrome must not block an otherwise valid perimeter cutover.
    readonly property bool compatibilityReady: {
        Config.revision
        if (!Config.ready)
            return false
        const enabledPanels = Config.options?.enabledPanels ?? []
        const barIdentifier = (Config.options?.bar?.vertical ?? false)
            ? "iiVerticalBar" : "iiBar"
        const barOwned = enabledPanels.includes(barIdentifier)
        const barAutoHide = Config.options?.bar?.autoHide?.enable ?? false
        const barPolicySupported = !barOwned || !barAutoHide

        const dockOwned = enabledPanels.includes("iiDock")
        const dockEnabled = Config.options?.dock?.enable ?? true
        const dockPinned = Config.options?.dock?.pinnedOnStartup ?? true
        const dockHoverReveal = Config.options?.dock?.hoverToReveal ?? false
        const dockPolicySupported = !dockOwned || !dockEnabled
            || (dockPinned && !dockHoverReveal)
        return barPolicySupported && dockPolicySupported
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
