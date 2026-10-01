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
    // Inspect local error strings without ever logging their raw contents,
    // which may contain private file paths or environment-specific details.
    function emitComponentCause() {
        if (!root.component) {
            console.log("MEGAQML_QS_UI_CAUSE_ABSENT")
            return
        }
        if (root.component.status === Component.Loading) {
            console.log("MEGAQML_QS_UI_CAUSE_LOADING_TIMEOUT")
            return
        }
        let detail = ""
        try { detail = String(root.component.errorString()).toLowerCase() }
        catch (ignored) { console.log("MEGAQML_QS_UI_CAUSE_NO_ERROR_API"); return }
        // Fixed, exact known type names only; never emit raw errorString().
        // Nested type errors are often more useful than the root's generic
        // "CloudStorageConfig unavailable" / "WCloudStoragePage unavailable".
        const typeHints = [
            ["contentpage", "CONTENT_PAGE"],
            ["settingstasknavigator", "TASK_NAVIGATOR"],
            ["settingscardsection", "CARD_SECTION"],
            ["settingsgroup", "SETTINGS_GROUP"],
            ["styledcombobox", "STYLED_COMBO"],
            ["settingsnote", "SETTINGS_NOTE"],
            ["styledtext", "STYLED_TEXT"],
            ["ripplebutton", "RIPPLE_BUTTON"],
            ["wsettingspage", "W_SETTINGS_PAGE"],
            ["wsettingscard", "W_SETTINGS_CARD"],
            ["wsettingsdropdown", "W_SETTINGS_DROPDOWN"],
            ["wsettingsinfobar", "W_INFO_BAR"],
            ["wsettingsbutton", "W_SETTINGS_BUTTON"],
            ["cloudstorageservice", "SHARED_SERVICE"],
            ["translation", "TRANSLATION"],
            ["appearance", "APPEARANCE"]
        ]
        for (const [typeName, fixedCode] of typeHints) {
            if (detail.includes(typeName + " is not a type") ||
                    detail.includes("type " + typeName + " unavailable") ||
                    detail.includes(typeName + " unavailable")) {
                console.log("MEGAQML_QS_UI_TYPE_" + fixedCode)
                return
            }
        }
        if (detail.includes("non-existent default property") ||
                detail.includes("nonexistent default property")) {
            console.log("MEGAQML_QS_UI_CAUSE_DEFAULT_PROPERTY")
        } else if (detail.includes("is not a type") ||
                detail.includes("unavailable type")) {
            console.log("MEGAQML_QS_UI_CAUSE_TYPE_RESOLUTION")
        } else if ((detail.includes("module ") && detail.includes("is not installed")) ||
                   detail.includes("failed to import")) {
            console.log("MEGAQML_QS_UI_CAUSE_MISSING_IMPORT")
        } else if (detail.includes("non-existent property") ||
                   detail.includes("read-only property") ||
                   detail.includes("cannot override final property")) {
            console.log("MEGAQML_QS_UI_CAUSE_PROPERTY_ASSIGNMENT")
        } else if (detail.includes("singleton")) {
            console.log("MEGAQML_QS_UI_CAUSE_SINGLETON")
        } else if (detail.includes("syntax error") ||
                   detail.includes("unexpected token")) {
            console.log("MEGAQML_QS_UI_CAUSE_SYNTAX")
        } else if (!detail) {
            console.log("MEGAQML_QS_UI_CAUSE_NO_DETAIL")
        } else {
            console.log("MEGAQML_QS_UI_CAUSE_OTHER")
        }
    }
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
                    root.emitComponentCause()
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
