// Two consecutive real Quickshell service requests against fake dispatcher.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services" as Deferred

ShellRoot {
    id: root
    readonly property string scenario: String(Quickshell.env("MEGAQML_FIXTURE_CASE"))
    property bool begun: false
    property bool intervened: false
    property real begunAt: 0
    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            const service = Deferred.CloudStorageService
            if (!["coalesce", "stale-reacquire"].includes(root.scenario)) {
                console.log("MEGAQML_QS_REFRESH_INVALID")
                Qt.quit()
                return
            }
            if (!root.begun) {
                root.begun = true
                root.begunAt = Date.now()
                service.registerConsumer()
                return
            }
            if (!root.intervened && Date.now() - root.begunAt >= 175) {
                if (service.requestSerial !== 1 || !service.readBusy) {
                    console.log("MEGAQML_QS_REFRESH_INVALID")
                    service.unregisterConsumer()
                    Qt.quit()
                    return
                }
                if (root.scenario === "coalesce") {
                    service.refreshStatic()
                    service.refreshStatic()
                    service.refreshStatic()
                } else {
                    service.unregisterConsumer()
                    if (service.consumerCount !== 0) {
                        console.log("MEGAQML_QS_REFRESH_INVALID")
                        Qt.quit()
                        return
                    }
                    service.registerConsumer()
                }
                root.intervened = true
                if (!service.refreshPending) {
                    console.log("MEGAQML_QS_REFRESH_INVALID")
                    service.unregisterConsumer()
                    Qt.quit()
                }
                return
            }
            if (!root.intervened)
                return
            if (root.scenario === "stale-reacquire"
                    && service.dependencySnapshot?.installed === true) {
                // First request was from the old consumer generation.
                console.log("MEGAQML_QS_REFRESH_INVALID")
                service.unregisterConsumer()
                Qt.quit()
                return
            }
            if (service.requestSerial === 2 && !service.readBusy
                    && service.backendState === "dependency_missing") {
                const snap = service.dependencySnapshot
                const ok = service.consumerCount === 1
                    && !service.refreshPending
                    && service.safeError === ""
                    && snap !== null
                    && snap.installed === false
                    && snap.shell === false
                    && snap.server === false
                    && snap.login === false
                    && snap.whoami === false
                    && snap.version === false
                    && service.connected === false
                    && service.liveAuthQualified === false
                service.unregisterConsumer()
                if (ok && service.consumerCount === 0
                        && service.backendState === "stale") {
                    console.log(root.scenario === "coalesce"
                        ? "MEGAQML_QS_COALESCED_OK"
                        : "MEGAQML_QS_REACQUIRE_OK")
                } else {
                    console.log("MEGAQML_QS_REFRESH_INVALID")
                }
                Qt.quit()
            } else if (Date.now() - root.begunAt >= 5400
                    || service.requestSerial > 2
                    || service.backendState === "unavailable") {
                console.log("MEGAQML_QS_REFRESH_INVALID")
                service.unregisterConsumer()
                Qt.quit()
            }
        }
    }
}
