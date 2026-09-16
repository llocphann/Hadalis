pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.modules.common.perimeter

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
    readonly property bool enabled: root.requested && root.configurationValid
}
