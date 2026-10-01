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
    // Locate the actual signal-bearing control in each copied production page,
    // rather than invoking the service directly and bypassing the page signal.
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
                if (svc.preflightSerial !== 0 || svc.preflightBusy
                        || svc.preflightState !== "not_requested") {
                    root.fail("BUTTON_MATERIAL")
                    return
                }
                if (!root.material.setSection("overview")
                        || root.material.activeSection !== "overview") {
                    root.fail("BUTTON_MATERIAL")
                    return
                }
                const materialButton = root.offlineControl(root.material)
                if (!materialButton || !materialButton.visible || !materialButton.enabled
                        || typeof materialButton.clicked !== "function") {
                    root.fail("BUTTON_MATERIAL")
                    return
                }
                // Actual Material page onClicked must start one opt-in request.
                materialButton.clicked()
                if (svc.preflightSerial !== 1 || !svc.preflightBusy
                        || svc.preflightState !== "checking"
                        || !root.goodMissing(svc, 3, 1)) {
                    root.fail("BUTTON_MATERIAL")
                    return
                }
                root.stage = 4
                return
            }
            if (root.stage === 4) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 1
                        || svc.preflightState !== "dependency_missing"
                        || svc.preflightError !== "" || !root.goodMissing(svc, 3, 1)) {
                    root.fail("PREFLIGHT_MATERIAL")
                    return
                }
                // Waffle joins the same singleton; it must not trigger
                // another automatic static detect while Material stays open.
                root.waffle.visible = true
                if (!root.waffle.leaseHeld || !root.material.leaseHeld
                        || svc.consumerCount !== 2 || svc.requestSerial !== 3) {
                    root.fail("BUTTON_WAFFLE")
                    return
                }
                if (!root.waffle.setSection("overview")
                        || root.waffle.activeSection !== "overview") {
                    root.fail("BUTTON_WAFFLE")
                    return
                }
                const waffleButton = root.offlineControl(root.waffle)
                if (!waffleButton || !waffleButton.visible || !waffleButton.enabled
                        || typeof waffleButton.buttonClicked !== "function") {
                    root.fail("BUTTON_WAFFLE")
                    return
                }
                waffleButton.buttonClicked()
                if (svc.preflightSerial !== 2 || !svc.preflightBusy
                        || svc.preflightState !== "checking" || svc.connected
                        || svc.liveAuthQualified || svc.requestSerial !== 3) {
                    root.fail("BUTTON_WAFFLE")
                    return
                }
                root.stage = 5
                return
            }
            if (root.stage === 5) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 2
                        || svc.preflightState !== "dependency_missing"
                        || svc.preflightError !== "" || !root.goodMissing(svc, 3, 2)) {
                    root.fail("PREFLIGHT_WAFFLE")
                    return
                }
                root.material.visible = false
                if (root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 1
                        || svc.preflightState !== "dependency_missing") {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.waffle.visible = false
                if (svc.consumerCount !== 0 || root.material.leaseHeld
                        || root.waffle.leaseHeld || svc.backendState !== "stale"
                        || svc.preflightState !== "not_requested"
                        || svc.preflightBusy || svc.connected || svc.liveAuthQualified) {
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
