pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

QtObject {
    id: root

    readonly property bool requested:
        (Config.options?.enabledPanels ?? []).includes("iiPerimeter")
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
        if (!root.sourcesReady)
            return "missing-module-source"
        return "active"
    }
}
