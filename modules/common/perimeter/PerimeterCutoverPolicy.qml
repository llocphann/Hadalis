pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

QtObject {
    id: root

    readonly property bool requested:
        (Config.options?.enabledPanels ?? []).includes("iiPerimeter")
    // Placement is perimeter-owned once the user opts in, but some legacy
    // behavior policies still need dedicated adapters. Fail safe to legacy for
    // those unsupported modes instead of silently changing interaction semantics.
    readonly property bool compatibilityReady: {
        Config.revision
        if (!Config.ready)
            return false
        const barAutoHide = Config.options?.bar?.autoHide?.enable ?? false
        const dockEnabled = Config.options?.dock?.enable ?? true
        const dockPinned = Config.options?.dock?.pinnedOnStartup ?? true
        const dockHoverReveal = Config.options?.dock?.hoverToReveal ?? false
        const dockPolicySupported = !dockEnabled
            || (dockPinned && !dockHoverReveal)
        return !barAutoHide && dockPolicySupported
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
        && root.compatibilityReady
        && root.configurationValid
        && root.sourcesReady
    readonly property bool fallbackActive: root.requested && !root.enabled
    readonly property string statusReason: {
        if (!root.requested)
            return "disabled"
        if (!Config.ready)
            return "config-loading"
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
