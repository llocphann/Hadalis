// Shared-page synthetic fixture; two unchanged real page bodies, one
// real copied CloudStorageService singleton, one Python-only fake detector.
// This is component lifecycle proof, not full visual integration.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services/deferred" as Deferred

ShellRoot {
    id: root
    property var material: null
    property var waffle: null
    property var materialComponent: null
    property var waffleComponent: null
    property int stage: 0
    property real stageStarted: 0
    property real started: Date.now()

    Item {
        id: pageHost
        visible: true
        width: 1024
        height: 768
    }

    function fail(reason) {
        // Only the fixed literals in this reviewed fixture can reach here.
        console.log("MEGAQML_QS_SHARED_STAGE_" + reason)
        console.log("MEGAQML_QS_SHARED_INVALID")
        if (root.material) root.material.visible = false
        if (root.waffle) root.waffle.visible = false
        Qt.quit()
    }
    function goodMissing(svc, expectedRequest, expectedConsumers) {
        const snap = svc.dependencySnapshot
        return svc.requestSerial === expectedRequest
            && svc.consumerCount === expectedConsumers
            && svc.backendState === "dependency_missing" && !svc.readBusy
            && svc.safeError === "" && snap !== null
            && !snap.installed && !snap.shell && !snap.server
            && !snap.login && !snap.whoami && !snap.version
            && !svc.connected && !svc.liveAuthQualified
    }
    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            const svc = Deferred.CloudStorageService
            if (Date.now() - root.started > 10500) {
                root.fail("TIMEOUT")
                return
            }
            if (root.stage === 0) {
                if (svc.consumerCount !== 0 || svc.requestSerial !== 0
                        || svc.backendState !== "not_checked") {
                    root.fail("PREFLIGHT")
                    return
                }
                if (!root.materialComponent) {
                    root.materialComponent = Qt.createComponent(Qt.resolvedUrl(
                        "modules/settings/CloudStorageConfig.qml"))
                    root.waffleComponent = Qt.createComponent(Qt.resolvedUrl(
                        "modules/waffle/settings/pages/WCloudStoragePage.qml"))
                    root.stageStarted = Date.now()
                }
                if ((root.materialComponent.status === Component.Loading
                        || root.waffleComponent.status === Component.Loading)
                        && Date.now() - root.stageStarted < 3000) return
                if (root.materialComponent.status !== Component.Ready
                        || root.waffleComponent.status !== Component.Ready) {
                    root.fail("LOAD")
                    return
                }
                root.material = root.materialComponent.createObject(
                    pageHost, { visible: false, width: 1024 })
                root.waffle = root.waffleComponent.createObject(
                    pageHost, { visible: false, width: 1024 })
                if (!root.material || !root.waffle) {
                    root.fail("CREATE")
                    return
                }
                if (root.material.settingsPageIndex !== 36
                        || root.waffle.settingsPageIndex !== 19
                        || root.material.groups.length !== 5
                        || root.waffle.groups.length !== 5
                        || root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 0 || svc.requestSerial !== 0
                        || !root.material.activateSettingsSearchSection("security")
                        || !root.waffle.activateSettingsSearchSection("transfers")
                        || root.material.activeSection !== "security"
                        || root.waffle.activeSection !== "transfers") {
                    root.fail("NAVIGATION")
                    return
                }
                root.material.visible = true
                root.waffle.visible = true
                if (!root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 2 || svc.requestSerial !== 1) {
                    root.fail("REGISTER")
                    return
                }
                root.stage = 1
                return
            }
            if (root.stage === 1) {
                if (svc.backendState === "unavailable") {
                    root.fail("FIRST_RESULT")
                    return
                }
                if (svc.backendState !== "dependency_missing" || svc.readBusy) return
                if (!root.goodMissing(svc, 1, 2)) {
                    root.fail("FIRST_RESULT")
                    return
                }
                root.material.visible = false
                if (root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 1
                        || svc.backendState !== "dependency_missing") {
                    root.fail("HIDE_ONE")
                    return
                }
                svc.refreshStatic()
                if (svc.requestSerial !== 2 || !svc.readBusy) {
                    root.fail("SECOND_START")
                    return
                }
                root.stage = 2
                return
            }
            if (root.stage === 2) {
                if (svc.backendState === "unavailable") {
                    root.fail("SECOND_RESULT")
                    return
                }
                if (svc.backendState !== "dependency_missing" || svc.readBusy) return
                if (!root.goodMissing(svc, 2, 1)
                        || root.material.leaseHeld || !root.waffle.leaseHeld) {
                    root.fail("SECOND_RESULT")
                    return
                }
                root.waffle.visible = false
                if (svc.consumerCount !== 0 || root.waffle.leaseHeld
                        || svc.backendState !== "stale") {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.material.visible = true
                if (!root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 1 || svc.requestSerial !== 3) {
                    root.fail("REACQUIRE")
                    return
                }
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                if (svc.backendState === "unavailable") {
                    root.fail("THIRD_RESULT")
                    return
                }
                if (svc.backendState !== "dependency_missing" || svc.readBusy) return
                if (!root.goodMissing(svc, 3, 1) || !root.material.leaseHeld
                        || root.waffle.leaseHeld) {
                    root.fail("THIRD_RESULT")
                    return
                }
                root.material.visible = false
                if (svc.consumerCount !== 0 || root.material.leaseHeld
                        || root.waffle.leaseHeld || svc.backendState !== "stale") {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.material.destroy()
                root.waffle.destroy()
                root.material = null
                root.waffle = null
                console.log("MEGAQML_QS_UI_SHARED_OK")
                Qt.quit()
            }
        }
    }
}
