// Recovery after synthetic nonzero exit / timeout. No vendor process.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services" as Deferred

ShellRoot {
    id: root
    readonly property string scenario: String(Quickshell.env("MEGAQML_FIXTURE_CASE"))
    property bool begun: false
    property bool queued: false
    property real begunAt: 0
    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            const svc = Deferred.CloudStorageService
            const elapsed = Date.now() - root.begunAt
            if (!["retry-exit", "retry-timeout"].includes(root.scenario)) {
                console.log("MEGAQML_QS_RECOVERY_INVALID")
                Qt.quit()
                return
            }
            if (!root.begun) {
                root.begun = true
                root.begunAt = Date.now()
                svc.registerConsumer()
                return
            }
            if (!root.queued && elapsed >= 175) {
                if (svc.requestSerial !== 1 || !svc.readBusy) {
                    console.log("MEGAQML_QS_RECOVERY_INVALID")
                    svc.unregisterConsumer()
                    Qt.quit()
                    return
                }
                svc.refreshStatic()
                svc.refreshStatic()
                root.queued = true
                if (!svc.refreshPending) {
                    console.log("MEGAQML_QS_RECOVERY_INVALID")
                    svc.unregisterConsumer()
                    Qt.quit()
                }
                return
            }
            if (!root.queued)
                return
            if (svc.safeError !== ""
                    && svc.safeError !== "Rust helper failed before static detection completed."
                    && svc.safeError !== "Static dependency check timed out.") {
                // Also prevents the synthetic canary from reaching safeError.
                console.log("MEGAQML_QS_RECOVERY_INVALID")
                svc.unregisterConsumer()
                Qt.quit()
                return
            }
            if (svc.requestSerial > 2) {
                console.log("MEGAQML_QS_RECOVERY_INVALID")
                svc.unregisterConsumer()
                Qt.quit()
                return
            }
            if (svc.requestSerial === 2 && !svc.readBusy
                    && svc.backendState === "dependency_missing") {
                const snap = svc.dependencySnapshot
                const valid = svc.consumerCount === 1
                    && !svc.refreshPending
                    && svc.safeError === ""
                    && svc.connected === false
                    && svc.liveAuthQualified === false
                    && snap !== null
                    && snap.installed === false
                    && snap.shell === false
                    && snap.server === false
                    && snap.login === false
                    && snap.whoami === false
                    && snap.version === false
                    && JSON.stringify(snap).indexOf("path") === -1
                    && (root.scenario !== "retry-timeout"
                        || (elapsed >= 5700 && elapsed < 10200))
                svc.unregisterConsumer()
                if (valid && svc.consumerCount === 0
                        && svc.backendState === "stale") {
                    console.log(root.scenario === "retry-timeout"
                        ? "MEGAQML_QS_TIMEOUT_RECOVERY_OK"
                        : "MEGAQML_QS_EXIT_RECOVERY_OK")
                } else {
                    console.log("MEGAQML_QS_RECOVERY_INVALID")
                }
                Qt.quit()
            } else if (elapsed >= (root.scenario === "retry-timeout" ? 10800 : 5400)) {
                console.log("MEGAQML_QS_RECOVERY_INVALID")
                svc.unregisterConsumer()
                Qt.quit()
            }
        }
    }
}
