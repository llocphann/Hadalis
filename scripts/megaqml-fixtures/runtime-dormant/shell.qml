// Never register a consumer here: load only the dormant real service.
// Quickshell.shellPath resolves to this isolated fixture directory, not the
// production repository root, so even an accidental process call cannot reach
// scripts/native-dispatch or an actual vendor binary.
import QtQuick
import Quickshell
import "../../../services/deferred" as Deferred

ShellRoot {
    id: root
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            Quickshell.watchFiles = false
            const service = Deferred.CloudStorageService
            if (service.consumerCount === 0
                    && service.requestSerial === 0
                    && service.readBusy === false
                    && service.dependencySnapshot === null
                    && service.backendState === "not_checked"
                    && service.connected === false
                    && service.liveAuthQualified === false) {
                console.log("MEGAQML_QS_DORMANT_OK")
            } else {
                console.log("MEGAQML_QS_DORMANT_INVALID")
            }
            Qt.quit()
        }
    }
}
