// Entirely fake-installed case: real copied Material/Waffle page bodies,
// one real deferred singleton, and Python-only fake vendor dependency results.
// NEVER starts MEGAcmd, authorizes login, touches an account or asserts
// that installed binaries on the owner's machine are actually qualified.
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

    Item { id: pageHost; visible: true; width: 1024; height: 768 }

    function fail(code) {
        // Call sites are fixed/allowlisted. Never print actual QML errors.
        console.log("MEGAQML_QS_PRESENT_STAGE_" + code)
        console.log("MEGAQML_QS_PRESENT_INVALID")
        if (root.material) root.material.visible = false
        if (root.waffle) root.waffle.visible = false
        Qt.quit()
    }
    function buttonUnder(node) {
        if (!node) return null
        if (node.buttonText === "Offline check")
            return node
        const children = node.children
        if (!children) return null
        for (let i = 0; i < children.length; i++) {
            const found = root.buttonUnder(children[i])
            if (found) return found
        }
        return null
    }
    function installedAndInert(svc, requests, consumers) {
        const snap = svc.dependencySnapshot
        return svc.backendState === "installed_disconnected"
            && !svc.readBusy && svc.safeError === ""
            && svc.requestSerial === requests && svc.consumerCount === consumers
            && snap !== null && snap.installed && snap.shell && snap.server
            && snap.login && !snap.whoami && snap.version
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
                        || svc.preflightSerial !== 0
                        || svc.backendState !== "not_checked"
                        || svc.preflightState !== "not_requested") {
                    root.fail("DORMANT")
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
                    pageHost, {visible: false, width: 1024})
                root.waffle = root.waffleComponent.createObject(
                    pageHost, {visible: false, width: 1024})
                if (!root.material || !root.waffle || root.material.leaseHeld
                        || root.waffle.leaseHeld || svc.consumerCount !== 0) {
                    root.fail("CREATE")
                    return
                }
                root.material.visible = true
                if (!root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 1 || svc.requestSerial !== 1
                        || !svc.readBusy || svc.preflightSerial !== 0) {
                    root.fail("MATERIAL_START")
                    return
                }
                root.stage = 1
                return
            }
            if (root.stage === 1) {
                if (svc.backendState === "checking") return
                if (!root.installedAndInert(svc, 1, 1)
                        || !root.material.setSection("overview")
                        || root.material.activeSection !== "overview"
                        || svc.preflightState !== "not_requested") {
                    root.fail("STATIC_PRESENT")
                    return
                }
                const button = root.buttonUnder(root.material)
                if (!button || !button.visible || !button.enabled
                        || typeof button.clicked !== "function") {
                    root.fail("MATERIAL_BUTTON")
                    return
                }
                button.clicked()
                if (svc.preflightSerial !== 1 || !svc.preflightBusy
                        || svc.preflightState !== "checking"
                        || !root.installedAndInert(svc, 1, 1)) {
                    root.fail("MATERIAL_BUTTON")
                    return
                }
                root.stage = 2
                return
            }
            if (root.stage === 2) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 1
                        || svc.preflightState !== "dependencies_ready"
                        || svc.preflightError !== ""
                        || !root.installedAndInert(svc, 1, 1)) {
                    root.fail("MATERIAL_READY")
                    return
                }
                // Existing Material lease keeps the service and snapshot
                // alive while Waffle joins. There must be no second detect.
                root.waffle.visible = true
                if (!root.waffle.leaseHeld || !root.material.leaseHeld
                        || svc.consumerCount !== 2 || svc.requestSerial !== 1
                        || !root.waffle.setSection("overview")
                        || root.waffle.activeSection !== "overview") {
                    root.fail("WAFFLE_JOIN")
                    return
                }
                const button = root.buttonUnder(root.waffle)
                if (!button || !button.visible || !button.enabled
                        || typeof button.buttonClicked !== "function") {
                    root.fail("WAFFLE_BUTTON")
                    return
                }
                button.buttonClicked()
                if (svc.preflightSerial !== 2 || !svc.preflightBusy
                        || svc.preflightState !== "checking"
                        || !root.installedAndInert(svc, 1, 2)) {
                    root.fail("WAFFLE_BUTTON")
                    return
                }
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 2
                        || svc.preflightState !== "dependencies_ready"
                        || svc.preflightError !== ""
                        || !root.installedAndInert(svc, 1, 2)) {
                    root.fail("WAFFLE_READY")
                    return
                }
                root.material.visible = false
                if (root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 1
                        || svc.preflightState !== "dependencies_ready") {
                    root.fail("PARTIAL_RELEASE")
                    return
                }
                root.waffle.visible = false
                if (svc.consumerCount !== 0 || root.waffle.leaseHeld
                        || svc.backendState !== "stale"
                        || svc.preflightState !== "not_requested"
                        || svc.preflightError !== "" || svc.preflightBusy
                        || svc.connected || svc.liveAuthQualified) {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.material.destroy()
                root.waffle.destroy()
                console.log("MEGAQML_QS_UI_PRESENT_OK")
                Qt.quit()
            }
        }
    }
}
