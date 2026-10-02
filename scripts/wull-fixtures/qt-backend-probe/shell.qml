// Private no-artwork/NO-Wull Qt-window backing capability probe only.
// No compositor, Niri, host screen, shader, wallpaper or PNG access.
import QtQuick
import Quickshell

ShellRoot {
    id: root
    property bool finished: false
    function complete(value): void {
        if (finished) return
        finished = true
        console.log("WULL_BACKEND_PROBE=" + value)
        Qt.quit()
    }
    FloatingWindow {
        id: testWindow
        visible: true
        color: "transparent"
        implicitWidth: 128
        implicitHeight: 96
        title: "Private synthetic Qt backend probe"
        Item { anchors.fill: parent }
    }
    Timer {
        interval: 1900; running: true; repeat: false
        onTriggered: root.complete(testWindow.backingWindowVisible
            ? "BACKING" : "NO_BACKING")
    }
    Timer {
        interval: 4500; running: true; repeat: false
        onTriggered: root.complete("TIMED_OUT")
    }
}
