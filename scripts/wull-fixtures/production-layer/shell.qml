// Bounded manual probe: instantiate the unmodified production AbyssPerimeter.
// Its config, XDG state, session bus, and lifetime are owned by the local runner.
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss

ShellRoot {
    id: root
    AbyssPerimeter { }
    Timer {
        id: readyTick
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            if (Config.ready) {
                GlobalStates.shellEntryReady = true
                GlobalStates.deferredPanelsReady = true
                console.log("WULL_PRODUCTION_FIXTURE_READY")
                readyTick.stop()
            }
        }
    }
}
