// Isolated active detection against a synthetic local dispatcher only.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services" as Deferred

ShellRoot {
    id: root
    readonly property string scenario: String(Quickshell.env("MEGAQML_FIXTURE_CASE"))
    property bool requested: false
    Timer {
        interval: 75
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++
            const service = Deferred.CloudStorageService
            if (root.scenario !== "present" && root.scenario !== "missing") {
                console.log("MEGAQML_QS_ACTIVE_INVALID")
                Qt.quit()
                return
            }
            if (!root.requested) {
                root.requested = true
                service.registerConsumer()
                return
            }
            const targetState = root.scenario === "present"
                ? "installed_disconnected" : "dependency_missing"
            if (service.backendState !== targetState) {
                if (ticks >= 68 || service.backendState === "unavailable") {
                    console.log("MEGAQML_QS_ACTIVE_INVALID")
                    service.unregisterConsumer()
                    Qt.quit()
                }
                return
            }
            const expected = root.scenario === "present"
            const snap = service.dependencySnapshot
            const valid = service.requestSerial === 1
                && service.consumerCount === 1
                && service.readBusy === false
                && service.safeError === ""
                && service.refreshPending === false
                && service.connected === false
                && service.liveAuthQualified === false
                && snap !== null
                && snap.installed === expected
                && snap.shell === expected
                && snap.server === expected
                && snap.login === expected
                && snap.whoami === false
                && snap.version === expected
                && JSON.stringify(snap).indexOf("path") === -1
            service.unregisterConsumer()
            if (valid && service.consumerCount === 0
                    && service.backendState === "stale") {
                console.log(expected
                    ? "MEGAQML_QS_ACTIVE_PRESENT_OK"
                    : "MEGAQML_QS_ACTIVE_MISSING_OK")
            } else {
                console.log("MEGAQML_QS_ACTIVE_INVALID")
            }
            Qt.quit()
        }
    }
}
