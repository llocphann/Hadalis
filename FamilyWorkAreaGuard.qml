pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Keep gapless tiled clients distinguishable from fullscreen while family
// reservations are replaced. This buffer is transparent and never takes input.
Scope {
    id: root
    property bool guarded: false
    property bool retained: guarded
    onGuardedChanged: {
        if (guarded) { release.stop(); retained = true }
        else release.restart()
    }
    // Let the compositor process the incoming family's layer commits before
    // releasing the guard, including direct config/reduced-motion switches.
    Timer { id: release; interval: 80; onTriggered: root.retained = root.guarded }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            // GameMode's Niri size heuristic tolerates two logical pixels.
            // Existing fullscreen clients ignore exclusive zones.
            exclusiveZone: root.retained ? 3 : 0
            implicitHeight: 3
            anchors { top: true; left: true; right: true }
            WlrLayershell.namespace: "hadalis:family-workarea-guard"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
        }
    }
}
