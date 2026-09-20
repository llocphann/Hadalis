pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property string requestedOutput: Quickshell.env("HADALIS_U1_OUTPUT") || ""
    readonly property var selectedScreens: {
        if (requestedOutput.length === 0)
            return Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []
        return Quickshell.screens.filter(screen => String(screen?.name ?? "") === requestedOutput)
    }

    Component.onCompleted: {
        if (selectedScreens.length === 0)
            console.error("[Hadalis U1] no output matched HADALIS_U1_OUTPUT=" + requestedOutput)
    }

    Variants {
        model: root.selectedScreens
        U1Surface {}
    }
}
