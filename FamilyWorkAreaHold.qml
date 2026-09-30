pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Scope {
    id: root
    property bool guarded: false
    property bool retained: guarded
    onGuardedChanged: {
        if (guarded) { release.stop(); retained = true }
        else release.restart()
    }
    // Allow incoming layer commits to reach the compositor before releasing.
    Timer { id: release; interval: 80; onTriggered: root.retained = root.guarded }
}
