pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property string requestedOutput: Quickshell.env("HADALIS_U1_OUTPUT") || ""
    readonly property bool fullscreenProbeEnabled: {
        const value = String(Quickshell.env("HADALIS_U1_FULLSCREEN_PROBE") || "").toLowerCase()
        return value === "1" || value === "true" || value === "yes"
    }
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

    // Test-only normal xdg-toplevel. Nested-Niri validation fullscreens this
    // window to verify Top/Overlay ordering without touching the host session.
    Loader {
        active: root.fullscreenProbeEnabled
        sourceComponent: FloatingWindow {
            visible: true
            title: "Hadalis U1 Fullscreen Probe"
            implicitWidth: 720
            implicitHeight: 480
            color: "#00ff00"
        }
    }
}
