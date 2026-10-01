// Small isolated Quickshell smoke. No UI, shell integration or vendor process.
import QtQuick
import Quickshell

ShellRoot {
    id: root
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("MEGAQML_QS_BASELINE_OK")
            Qt.quit()
        }
    }
}
