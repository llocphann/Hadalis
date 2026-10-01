// Independent fake-only concurrent static/preflight deadline regression.
// Copies the real Material page + service, never executes installed MEGAcmd.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services/deferred" as Deferred

ShellRoot {
    id: root
    property var page: null
    property var pageComponent: null
    property int stage: 0
    property bool bothChildrenStarted: false
    property real startTime: Date.now()
    property real loadStart: 0

    Item { id: pageHost; visible: true; width: 1024; height: 768 }

    function fail(reason) {
        // Strictly fixed diagnostic tokens. No raw child or QML text.
        console.log("MEGAQML_QS_OVERLAP_STAGE_" + reason)
        console.log("MEGAQML_QS_OVERLAP_INVALID")
        if (root.page) root.page.visible = false
        Qt.quit()
    }
    function missing(svc) {
        const snap = svc.dependencySnapshot
        return svc.requestSerial === 2
            && svc.consumerCount === 1 && !svc.readBusy
            && svc.backendState === "dependency_missing"
            && svc.safeError === "" && snap !== null
            && !snap.installed && !snap.shell && !snap.server
            && !snap.login && !snap.whoami && !snap.version
            && !svc.connected && !svc.liveAuthQualified
    }
    function offlineControl(node) {
        if (!node) return null
        if (node.buttonText === "Check connection readiness (offline)")
            return node
        const children = node.children
        if (!children) return null
        for (let i = 0; i < children.length; i++) {
            const found = root.offlineControl(children[i])
            if (found) return found
        }
        return null
    }

    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            const svc = Deferred.CloudStorageService
            if (Date.now() - root.startTime > 10500) {
                root.fail("TIMEOUT")
                return
            }
            if (root.stage === 0) {
                if (svc.consumerCount !== 0 || svc.requestSerial !== 0
                        || svc.preflightSerial !== 0
                        || svc.backendState !== "not_checked") {
                    root.fail("DORMANT")
                    return
                }
                if (!root.pageComponent) {
                    root.pageComponent = Qt.createComponent(Qt.resolvedUrl(
                        "modules/settings/CloudStorageConfig.qml"))
                    root.loadStart = Date.now()
                }
                if (root.pageComponent.status === Component.Loading
                        && Date.now() - root.loadStart < 3000) return
                if (root.pageComponent.status !== Component.Ready) {
                    root.fail("LOAD")
                    return
                }
                root.page = root.pageComponent.createObject(
                    pageHost, { visible: false, width: 1024 })
                if (!root.page || root.page.leaseHeld
                        || svc.consumerCount !== 0) {
                    root.fail("CREATE")
                    return
                }
                root.page.visible = true
                if (!root.page.leaseHeld || svc.consumerCount !== 1
                        || svc.requestSerial !== 1 || !svc.readBusy
                        || svc.backendState !== "checking"
                        || svc.preflightSerial !== 0) {
                    root.fail("STATIC_START")
                    return
                }
                root.stage = 1
                return
            }
            if (root.stage === 1) {
                // Wait until the real static child has received stdin before
                // clicking the actual Material offline readiness button.
                if (svc._pendingInput !== "") return
                if (!svc.readBusy || svc.backendState !== "checking"
                        || !root.page.setSection("overview")) {
                    root.fail("OVERLAP_START")
                    return
                }
                const button = root.offlineControl(root.page)
                if (!button || !button.visible || !button.enabled
                        || typeof button.clicked !== "function") {
                    root.fail("OVERLAP_START")
                    return
                }
                button.clicked()
                if (!svc.preflightBusy || svc.preflightSerial !== 1
                        || svc.preflightState !== "checking"
                        || !svc.readBusy || svc.requestSerial !== 1
                        || svc.connected || svc.liveAuthQualified) {
                    root.fail("OVERLAP_START")
                    return
                }
                root.stage = 2
                return
            }
            if (root.stage === 2) {
                if (svc.backendState !== "checking"
                        || svc.preflightState !== "checking") {
                    root.fail("CHILD_START")
                    return
                }
                if (svc._preflightInput !== "") return
                // Both first fake processes are running and have received
                // input; a missing-spawn false positive cannot pass.
                root.bothChildrenStarted = true
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                if (svc.backendState === "checking") return
                if (svc.readBusy || svc.preflightBusy) return
                if (!root.bothChildrenStarted
                        || svc.backendState !== "unavailable"
                        || svc.safeError !== "Static dependency check timed out."
                        || svc.dependencySnapshot !== null
                        || svc.preflightState !== "unavailable"
                        || svc.preflightError
                            !== "Offline readiness invalidated by static dependency timeout."
                        || svc._preflightGeneration !== -1
                        || svc.requestSerial !== 1
                        || svc.preflightSerial !== 1
                        || svc.consumerCount !== 1
                        || svc.connected || svc.liveAuthQualified) {
                    root.fail("CANCEL_REAP")
                    return
                }
                // A new explicit static check must work after both children
                // are reaped. Fake detect #2 is fast and reports missing.
                svc.refreshStatic()
                if (!svc.readBusy || svc.requestSerial !== 2
                        || svc.backendState !== "checking"
                        || svc.preflightBusy) {
                    root.fail("STATIC_RETRY")
                    return
                }
                root.stage = 4
                return
            }
            if (root.stage === 4) {
                if (svc.backendState === "checking") return
                if (!root.missing(svc)
                        || svc.preflightBusy
                        || svc.preflightState !== "unavailable"
                        || svc.preflightSerial !== 1
                        || svc.preflightError
                            !== "Offline readiness invalidated by static dependency timeout.") {
                    root.fail("STATIC_RECOVER")
                    return
                }
                const button = root.offlineControl(root.page)
                if (!button || !button.enabled
                        || typeof button.clicked !== "function") {
                    root.fail("PREFLIGHT_RETRY")
                    return
                }
                button.clicked()
                if (!svc.preflightBusy || svc.preflightSerial !== 2
                        || svc.preflightState !== "checking"
                        || !root.missing(svc)) {
                    root.fail("PREFLIGHT_RETRY")
                    return
                }
                root.stage = 5
                return
            }
            if (root.stage === 5) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 2
                        || svc.preflightState !== "dependency_missing"
                        || svc.preflightError !== ""
                        || !root.missing(svc)) {
                    root.fail("PREFLIGHT_RECOVER")
                    return
                }
                root.page.visible = false
                if (root.page.leaseHeld || svc.consumerCount !== 0
                        || svc.backendState !== "stale"
                        || svc.preflightBusy
                        || svc.preflightState !== "not_requested"
                        || svc.preflightError !== ""
                        || svc.connected || svc.liveAuthQualified) {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.page.destroy()
                root.page = null
                console.log("MEGAQML_QS_UI_OVERLAP_OK")
                Qt.quit()
            }
        }
    }
}
