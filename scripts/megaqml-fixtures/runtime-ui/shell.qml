// Component creation test: real reviewed Cloud Storage page logic with
// minimal visual dependency stubs. Not a full Hadalis Settings render.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "./services/deferred" as Deferred

ShellRoot {
    id: root
    readonly property string kind: String(Quickshell.env("MEGAQML_UI_KIND"))
    property var page: null
    property var component: null
    property real componentStarted: 0
    property real started: 0
    Timer {
        interval: 75
        repeat: true
        running: true
        onTriggered: {
            const svc = Deferred.CloudStorageService
            if (root.kind !== "material" && root.kind !== "waffle") {
                console.log("MEGAQML_QS_UI_STAGE_SCENARIO")
                console.log("MEGAQML_QS_UI_INVALID")
                Qt.quit()
                return
            }
            if (root.page === null) {
                if (svc.consumerCount !== 0 || svc.requestSerial !== 0
                        || svc.backendState !== "not_checked") {
                    console.log("MEGAQML_QS_UI_STAGE_PREFLIGHT")
                    console.log("MEGAQML_QS_UI_INVALID")
                    Qt.quit()
                    return
                }
                const location = root.kind === "material"
                    ? "modules/settings/CloudStorageConfig.qml"
                    : "modules/waffle/settings/pages/WCloudStoragePage.qml"
                // QML can load a component asynchronously. Keep the same
                // component instance; never spawn a second service or page.
                if (root.component === null) {
                    root.componentStarted = Date.now()
                    root.component = Qt.createComponent(Qt.resolvedUrl(location))
                }
                if (root.component && root.component.status === Component.Loading
                        && Date.now() - root.componentStarted < 3000) return
                if (!root.component || root.component.status !== Component.Ready) {
                    console.log("MEGAQML_QS_UI_STAGE_COMPONENT")
                    console.log("MEGAQML_QS_UI_INVALID")
                    Qt.quit()
                    return
                }
                const page = root.component.createObject(null, { visible: false, width: 1024 })
                if (!page) {
                    console.log("MEGAQML_QS_UI_STAGE_CONSTRUCT")
                    console.log("MEGAQML_QS_UI_INVALID")
                    Qt.quit()
                    return
                }
                root.page = page
                const expectedIndex = root.kind === "material" ? 36 : 19
                if (page.settingsPageIndex !== expectedIndex
                        || page.leaseHeld || page.activeSection !== "overview"
                        || page.groups.length !== 5 || page.setSection("__unknown__")
                        || !page.activateSettingsSearchSection("transfers")
                        || page.activeSection !== "transfers"
                        || !page.activateSettingsSearchSection("security")
                        || page.activeSection !== "security"
                        || !page.activateSettingsSearchSection("overview")
                        || page.activeSection !== "overview"
                        || svc.consumerCount !== 0 || svc.requestSerial !== 0) {
                    console.log("MEGAQML_QS_UI_STAGE_NAVIGATION")
                    console.log("MEGAQML_QS_UI_INVALID")
                    page.destroy()
                    Qt.quit()
                    return
                }
                root.started = Date.now()
                page.visible = true
                return
            }
            if (svc.backendState === "dependency_missing" && !svc.readBusy) {
                const snap = svc.dependencySnapshot
                const valid = root.page.leaseHeld
                    && svc.consumerCount === 1
                    && svc.requestSerial === 1
                    && svc.safeError === ""
                    && snap !== null && !snap.installed
                    && !snap.shell && !snap.server
                    && !snap.login && !snap.whoami && !snap.version
                    && !svc.connected && !svc.liveAuthQualified
                root.page.visible = false
                const released = !root.page.leaseHeld
                    && svc.consumerCount === 0
                    && svc.backendState === "stale"
                root.page.destroy()
                root.page = null
                if (!valid) console.log("MEGAQML_QS_UI_STAGE_DETECTION")
                else if (!released) console.log("MEGAQML_QS_UI_STAGE_RELEASE")
                console.log(valid && released
                    ? (root.kind === "material"
                        ? "MEGAQML_QS_UI_MATERIAL_OK"
                        : "MEGAQML_QS_UI_WAFFLE_OK")
                    : "MEGAQML_QS_UI_INVALID")
                Qt.quit()
            } else if (Date.now() - root.started >= 5250
                    || svc.backendState === "unavailable") {
                console.log("MEGAQML_QS_UI_STAGE_DEADLINE")
                console.log("MEGAQML_QS_UI_INVALID")
                root.page.visible = false
                root.page.destroy()
                root.page = null
                Qt.quit()
            }
        }
    }
}
