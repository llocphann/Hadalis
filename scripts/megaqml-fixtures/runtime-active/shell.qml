// Isolated active detection against a synthetic local dispatcher only.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services" as Deferred

ShellRoot {
    id: root
    readonly property string scenario: String(Quickshell.env("MEGAQML_FIXTURE_CASE"))
    property bool requested: false
    property real requestedAt: 0
    Timer {
        interval: 75
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            ticks++
            const service = Deferred.CloudStorageService
            if (!["present", "missing", "wrong-id", "unsafe-secret", "malformed", "exit-failure", "hang"].includes(root.scenario)) {
                console.log("MEGAQML_QS_ACTIVE_INVALID")
                Qt.quit()
                return
            }
            if (!root.requested) {
                root.requested = true
                root.requestedAt = Date.now()
                service.registerConsumer()
                return
            }
            const invalidReply = ["wrong-id", "unsafe-secret", "malformed"].includes(root.scenario)
            const lifecycleFailure = ["exit-failure", "hang"].includes(root.scenario)
            const targetState = invalidReply || lifecycleFailure ? "unavailable"
                : root.scenario === "present" ? "installed_disconnected" : "dependency_missing"
            if (service.backendState !== targetState) {
                if (Date.now() - root.requestedAt >= (root.scenario === "hang" ? 10200 : 5100)
                        || service.backendState === "unavailable") {
                    console.log("MEGAQML_QS_ACTIVE_INVALID")
                    service.unregisterConsumer()
                    Qt.quit()
                }
                return
            }
            if (lifecycleFailure) {
                // Deadline must invalidate the response, kill/reap the Python-only
                // fake child and never leak fabricated stderr into safeError.
                if (service.readBusy) {
                    if (Date.now() - root.requestedAt > 10200) {
                        console.log("MEGAQML_QS_ACTIVE_INVALID")
                        service.unregisterConsumer()
                        Qt.quit()
                    }
                    return
                }
                const elapsed = Date.now() - root.requestedAt
                const expectedError = root.scenario === "hang"
                    ? "Static dependency check timed out."
                    : "Rust helper failed before static detection completed."
                const valid = service.consumerCount === 1
                    && service.requestSerial === 1
                    && service.readBusy === false
                    && service.dependencySnapshot === null
                    && service.backendState === "unavailable"
                    && service.safeError === expectedError
                    && service.refreshPending === false
                    && service.connected === false
                    && service.liveAuthQualified === false
                    && (root.scenario !== "hang" || (elapsed >= 5750 && elapsed < 8800))
                service.unregisterConsumer()
                if (valid && service.consumerCount === 0) {
                    console.log(root.scenario === "hang"
                        ? "MEGAQML_QS_TIMEOUT_OK"
                        : "MEGAQML_QS_EXIT_FAILURE_OK")
                } else {
                    console.log("MEGAQML_QS_ACTIVE_INVALID")
                }
                Qt.quit()
                return
            }
            if (invalidReply) {
                const rejected = service.consumerCount === 1
                    && service.requestSerial === 1
                    && service.readBusy === false
                    && service.dependencySnapshot === null
                    && service.backendState === "unavailable"
                    && service.safeError === "Incompatible or oversized Cloud Storage response."
                    && service.connected === false
                    && service.liveAuthQualified === false
                    && service.refreshPending === false
                service.unregisterConsumer()
                if (rejected && service.consumerCount === 0
                        && service.backendState === "unavailable") {
                    console.log("MEGAQML_QS_REJECTED_OK")
                } else {
                    console.log("MEGAQML_QS_ACTIVE_INVALID")
                }
                Qt.quit()
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
