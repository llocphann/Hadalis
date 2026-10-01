// Execute the exact real SettingsPageHost and Material Cloud Storage page in
// temporary source-only dependency stubs. NO full Hadalis app or real vendor.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services/deferred" as Deferred

ShellRoot {
    id: root
    property var host: null
    property var hostComponent: null
    property var cachedCloud: null
    property int stage: 0
    property real started: Date.now()

    Item {
        id: pageHost
        visible: true
        width: 1024
        height: 768
    }
    function fail(code) {
        // Fixed literal stage labels only. Raw Qt errors stay local.
        console.log("MEGAQML_QS_HOST_STAGE_" + code)
        console.log("MEGAQML_QS_HOST_INVALID")
        if (root.host) root.host.loadEnabled = false
        Qt.quit()
    }
    function missing(svc, expectedRequests) {
        const snap = svc.dependencySnapshot
        return svc.requestSerial === expectedRequests
            && svc.consumerCount === 1 && !svc.readBusy
            && svc.backendState === "dependency_missing" && snap
            && !snap.installed && !snap.shell && !snap.server
            && !snap.login && !snap.whoami && !snap.version
            && !svc.connected && !svc.liveAuthQualified && svc.safeError === ""
    }
    function offlineControl(node) {
        if (!node) return null
        if (node.buttonText === "Offline check")
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
        interval: 55
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
                if (!root.hostComponent)
                    root.hostComponent = Qt.createComponent(Qt.resolvedUrl(
                        "modules/settings/SettingsPageHost.qml"))
                if (root.hostComponent.status === Component.Loading) return
                if (root.hostComponent.status !== Component.Ready) {
                    root.fail("HOST_LOAD")
                    return
                }
                root.host = root.hostComponent.createObject(pageHost, {
                    width: 1024, height: 768, loadEnabled: true,
                    cacheLimit: 2, requestedIndex: 0,
                    pages: [
                        {component: Qt.resolvedUrl("modules/settings/MegaHostDummy.qml").toString()},
                        {component: Qt.resolvedUrl("modules/settings/CloudStorageConfig.qml").toString()}
                    ]
                })
                if (!root.host) {
                    root.fail("HOST_CREATE")
                    return
                }
                root.stage = 1
                return
            }
            if (root.host.error) {
                root.fail("HOST_ERROR")
                return
            }
            if (root.stage === 1) {
                if (root.host.currentIndex !== 0 || !root.host.currentItem
                        || root.host.loading) return
                if (svc.consumerCount !== 0 || svc.requestSerial !== 0) {
                    root.fail("DORMANT")
                    return
                }
                root.host.requestedIndex = 1
                root.stage = 2
                return
            }
            if (root.stage === 2) {
                if (root.host.currentIndex !== 1 || !root.host.currentItem
                        || root.host.loading) return
                const page = root.host.currentItem
                if (page.settingsPageIndex !== 36 || !page.leaseHeld
                        || svc.consumerCount !== 1 || svc.requestSerial !== 1
                        || !page.activateSettingsSearchSection("security")
                        || page.activeSection !== "security") {
                    root.fail("FIRST_PAGE")
                    return
                }
                root.cachedCloud = page
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                if (svc.backendState === "unavailable") {
                    root.fail("FIRST_RESULT")
                    return
                }
                if (!root.missing(svc, 1)) return
                if (!root.cachedCloud.setSection("overview")
                        || root.cachedCloud.activeSection !== "overview"
                        || svc.preflightSerial !== 0
                        || svc.preflightState !== "not_requested") {
                    root.fail("PREFLIGHT_BUTTON")
                    return
                }
                const button = root.offlineControl(root.cachedCloud)
                if (!button || !button.visible || !button.enabled
                        || typeof button.clicked !== "function") {
                    root.fail("PREFLIGHT_BUTTON")
                    return
                }
                button.clicked()
                if (svc.preflightSerial !== 1 || !svc.preflightBusy
                        || svc.preflightState !== "checking"
                        || !root.missing(svc, 1)) {
                    root.fail("PREFLIGHT_BUTTON")
                    return
                }
                root.stage = 10
                return
            }
            if (root.stage === 10) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 1
                        || svc.preflightState !== "dependency_missing"
                        || svc.preflightError !== "" || !root.missing(svc, 1)) {
                    root.fail("PREFLIGHT_RESULT")
                    return
                }
                root.host.requestedIndex = 0
                root.stage = 4
                return
            }
            if (root.stage === 4) {
                if (root.host.currentIndex !== 0 || !root.host.currentItem
                        || root.host.loading) return
                if (root.cachedCloud.leaseHeld || svc.consumerCount !== 0
                        || svc.backendState !== "stale"
                        || svc.preflightBusy || svc.preflightSerial !== 1
                        || svc.preflightState !== "not_requested"
                        || svc.preflightError !== "") {
                    root.fail("HIDE_PAGE")
                    return
                }
                root.host.requestedIndex = 1
                root.stage = 5
                return
            }
            if (root.stage === 5) {
                if (root.host.currentIndex !== 1 || !root.host.currentItem
                        || root.host.loading) return
                if (root.host.currentItem !== root.cachedCloud
                        || !root.cachedCloud.leaseHeld || svc.consumerCount !== 1
                        || svc.requestSerial !== 2
                        || svc.preflightSerial !== 1
                        || svc.preflightState !== "not_requested") {
                    root.fail("REVISIT_CACHE")
                    return
                }
                root.stage = 6
                return
            }
            if (root.stage === 6) {
                if (svc.backendState === "unavailable") {
                    root.fail("SECOND_RESULT")
                    return
                }
                if (!root.missing(svc, 2)) return
                if (svc.preflightSerial !== 1 || svc.preflightBusy
                        || svc.preflightState !== "not_requested") {
                    root.fail("PREFLIGHT_REVISIT")
                    return
                }
                const cachedButton = root.offlineControl(root.cachedCloud)
                if (!cachedButton || !cachedButton.visible || !cachedButton.enabled
                        || typeof cachedButton.clicked !== "function") {
                    root.fail("PREFLIGHT_REVISIT")
                    return
                }
                cachedButton.clicked()
                if (svc.preflightSerial !== 2 || !svc.preflightBusy
                        || svc.preflightState !== "checking"
                        || !root.missing(svc, 2)) {
                    root.fail("PREFLIGHT_REVISIT")
                    return
                }
                root.stage = 11
                return
            }
            if (root.stage === 11) {
                if (svc.preflightState === "checking") return
                if (svc.preflightBusy || svc.preflightSerial !== 2
                        || svc.preflightState !== "dependency_missing"
                        || svc.preflightError !== "" || !root.missing(svc, 2)) {
                    root.fail("PREFLIGHT_RESULT")
                    return
                }
                root.host.loadEnabled = false
                root.stage = 7
                return
            }
            if (root.stage === 7) {
                if (svc.consumerCount !== 0
                        || svc.backendState !== "stale"
                        || root.host.currentIndex !== -1
                        || svc.preflightSerial !== 2
                        || svc.preflightState !== "not_requested"
                        || svc.preflightBusy) {
                    root.fail("HOST_RESET")
                    return
                }
                root.cachedCloud = null
                root.host.loadEnabled = true
                root.stage = 8
                return
            }
            if (root.stage === 8) {
                if (root.host.currentIndex !== 1 || !root.host.currentItem
                        || root.host.loading) return
                if (!root.host.currentItem.leaseHeld
                        || svc.consumerCount !== 1 || svc.requestSerial !== 3
                        || svc.preflightSerial !== 2
                        || svc.preflightState !== "not_requested") {
                    root.fail("REOPEN")
                    return
                }
                root.stage = 9
                return
            }
            if (root.stage === 9) {
                if (svc.backendState === "unavailable") {
                    root.fail("THIRD_RESULT")
                    return
                }
                if (!root.missing(svc, 3)) return
                if (svc.preflightSerial !== 2 || svc.preflightBusy
                        || svc.preflightState !== "not_requested"
                        || svc.preflightError !== "" || svc.connected
                        || svc.liveAuthQualified) {
                    root.fail("PREFLIGHT_REOPEN")
                    return
                }
                root.host.loadEnabled = false
                if (svc.consumerCount !== 0 || svc.backendState !== "stale") {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.host.destroy()
                root.host = null
                console.log("MEGAQML_QS_UI_HOST_OK")
                Qt.quit()
            }
        }
    }
}
