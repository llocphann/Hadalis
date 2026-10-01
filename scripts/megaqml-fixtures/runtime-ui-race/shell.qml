// Adversarial shared-page fixture: two real page bodies, one copied
// CloudStorageService and one Python-only static dispatcher. Two fake present
// replies are delayed; a third fake missing reply must be the only fresh one.
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
    property real componentStarted: 0
    property real started: Date.now()
    property bool sawStaleInstalled: false

    Item {
        id: pageHost
        visible: true
        width: 1024
        height: 768
    }
    Connections {
        target: Deferred.CloudStorageService
        function onBackendStateChanged() {
            // Record even brief stale acceptance that a polling timer may miss.
            if (root.stage >= 2 && Deferred.CloudStorageService.backendState
                    === "installed_disconnected") root.sawStaleInstalled = true
        }
    }
    function fail(code) {
        // Every callsite supplies one fixed, reviewed diagnostic label.
        console.log("MEGAQML_QS_RACE_STAGE_" + code)
        console.log("MEGAQML_QS_RACE_INVALID")
        if (root.material) root.material.visible = false
        if (root.waffle) root.waffle.visible = false
        Qt.quit()
    }
    Timer {
        interval: 40
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
                    root.componentStarted = Date.now()
                }
                if ((root.materialComponent.status === Component.Loading
                        || root.waffleComponent.status === Component.Loading)
                        && Date.now() - root.componentStarted < 3000) return
                if (root.materialComponent.status !== Component.Ready
                        || root.waffleComponent.status !== Component.Ready) {
                    root.fail("LOAD")
                    return
                }
                root.material = root.materialComponent.createObject(
                    pageHost, {visible: false, width: 1024})
                root.waffle = root.waffleComponent.createObject(
                    pageHost, {visible: false, width: 1024})
                if (!root.material || !root.waffle
                        || root.material.settingsPageIndex !== 36
                        || root.waffle.settingsPageIndex !== 19
                        || root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 0) {
                    root.fail("CREATE")
                    return
                }
                root.material.visible = true
                root.waffle.visible = true
                if (!root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 2 || svc.requestSerial !== 1
                        || !svc.readBusy || svc.backendState !== "checking") {
                    root.fail("FIRST_START")
                    return
                }
                // Close one page with the first fake installed read pending.
                // The remaining consumer must safely queue a refresh.
                root.material.visible = false
                if (root.material.leaseHeld || !root.waffle.leaseHeld
                        || svc.consumerCount !== 1) {
                    root.fail("HIDE_ONE")
                    return
                }
                svc.refreshStatic()
                if (!svc.refreshPending || svc.requestSerial !== 1) {
                    root.fail("QUEUE")
                    return
                }
                root.stage = 1
                return
            }
            if (root.stage === 1) {
                if (svc.consumerCount !== 1 || root.material.leaseHeld
                        || !root.waffle.leaseHeld
                        || svc.backendState === "unavailable") {
                    root.fail("FIRST_PENDING")
                    return
                }
                if (svc.requestSerial < 2) return
                if (svc.requestSerial !== 2 || !svc.readBusy
                        || svc.backendState !== "checking"
                        || svc.dependencySnapshot !== null) {
                    root.fail("SECOND_START")
                    return
                }
                // A different page reacquires AFTER the last old consumer
                // departs, but BEFORE the second late installed reply.
                root.stage = 2
                const beforeRelease = svc.generation
                root.waffle.visible = false
                if (root.waffle.leaseHeld || svc.consumerCount !== 0
                        || svc.generation !== beforeRelease + 1) {
                    root.fail("LAST_RELEASE")
                    return
                }
                root.material.visible = true
                if (!root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 1 || svc.requestSerial !== 2
                        || svc.generation !== beforeRelease + 1
                        || !svc.refreshPending) {
                    root.fail("REACQUIRE")
                    return
                }
                return
            }
            if (root.stage === 2) {
                // Keep fail-closed stale rejection; classify the specific
                // observed reason without printing private Qt diagnostics.
                if (root.sawStaleInstalled
                        || svc.backendState === "installed_disconnected") {
                    root.fail("STALE_INSTALLED")
                    return
                }
                if (!root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 1) {
                    root.fail("STALE_LEASE")
                    return
                }
                if (svc.backendState === "unavailable") {
                    root.fail("STALE_UNAVAILABLE")
                    return
                }
                if (svc.dependencySnapshot !== null) {
                    root.fail("STALE_SNAPSHOT")
                    return
                }
                if (svc.requestSerial > 3) {
                    root.fail("STALE_REPLY")
                    return
                }
                if (svc.requestSerial < 3) return
                if (svc.requestSerial !== 3 || !svc.readBusy
                        || svc.backendState !== "checking") {
                    root.fail("THIRD_START")
                    return
                }
                root.stage = 3
                return
            }
            if (root.stage === 3) {
                if (root.sawStaleInstalled
                        || svc.backendState === "installed_disconnected"
                        || svc.backendState === "unavailable"
                        || svc.consumerCount !== 1) {
                    root.fail("THIRD_RESULT")
                    return
                }
                if (svc.backendState !== "dependency_missing" || svc.readBusy) return
                const snap = svc.dependencySnapshot
                if (svc.requestSerial !== 3 || !root.material.leaseHeld
                        || root.waffle.leaseHeld || svc.safeError !== ""
                        || !snap || snap.installed || snap.shell || snap.server
                        || snap.login || snap.whoami || snap.version
                        || svc.connected || svc.liveAuthQualified) {
                    root.fail("THIRD_RESULT")
                    return
                }
                root.material.visible = false
                if (root.material.leaseHeld || root.waffle.leaseHeld
                        || svc.consumerCount !== 0 || svc.backendState !== "stale") {
                    root.fail("FINAL_RELEASE")
                    return
                }
                root.material.destroy()
                root.waffle.destroy()
                root.material = null
                root.waffle = null
                console.log("MEGAQML_QS_UI_RACE_OK")
                Qt.quit()
            }
        }
    }
}
