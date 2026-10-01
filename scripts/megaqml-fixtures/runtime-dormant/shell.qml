// Never register a consumer here: load only the dormant real service.
// The runner copies the exact reviewed service and parser into a temporary
// configuration root, which contains no production native dispatcher or vendor
// executable. No other Hadalis services are loaded by this fixture.
import QtQuick
import Quickshell
import "./services" as Deferred

ShellRoot {
    id: root
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
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
