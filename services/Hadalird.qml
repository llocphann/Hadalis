pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root
    property bool available: false
    property bool loadFailed: false
    property string diagnostic: "not-installed"
    property string packageRoot: ""
    property string version: ""
    property string sourceSha: ""
    property bool canRollback: false
    property bool managerBusy: false
    property string managerAction: ""
    property string managerError: ""
    property string managerMessage: ""
    property string latestSha: ""
    property bool updateAvailable: false
    readonly property var options: Config.options?.integrations?.hadalird
    readonly property bool tlpEnabled: available && !loadFailed && Config.ready && options?.tlp === true
    readonly property bool thinkfanEnabled: available && !loadFailed && Config.ready && options?.thinkfan === true
    readonly property bool obsidianEnabled: available && !loadFailed && Config.ready && options?.obsidian === true
    readonly property bool enabled: tlpEnabled || thinkfanEnabled || obsidianEnabled
    readonly property var session: worker.status === Loader.Ready ? worker.item : null

    // Explicit user action only. Hadalis owns transport and the signed-off
    // optional-package lifecycle, not an external installer run by the user.
    function manage(action): void {
        if (managerBusy || probe.running || !["check","install","remove","rollback"].includes(action))
            return
        managerAction = action
        managerBusy = true
        managerError = ""
        managerMessage = ""
        if (action !== "check") {
            // Release all disposable workers before switching the immutable package link.
            available = false
            loadFailed = false
        }
        managerProcess.command = ["/usr/bin/python3",
            Quickshell.shellPath("scripts/hadalird-manager.py"), action,
            "--shell-root", Quickshell.shellPath("")]
        managerProcess.running = true
        managerDeadline.restart()
    }
    function settingsSource(integration): string {
        if (!available) return ""
        if (integration === "thinkfan") return packageRoot + "/modules/settings/ThinkfanSettings.qml"
        if (integration === "tlp") return packageRoot + "/modules/settings/TlpPowerSettings.qml"
        if (integration === "obsidian") return packageRoot + "/modules/settings/ObsidianThemeSettings.qml"
        if (integration === "obsidianTodo") return packageRoot + "/modules/settings/ObsidianTodoSettings.qml"
        if (integration === "tlpRow") return packageRoot + "/modules/settings/TlpSettingRow.qml"
        if (integration === "tlpWaffle") return packageRoot + "/modules/waffle/settings/WTlpPowerSettings.qml"
        if (integration === "tlpWaffleRow") return packageRoot + "/modules/waffle/settings/WTlpSettingRow.qml"
        return ""
    }
    function backendSource(kind): string {
        if (!obsidianEnabled) return ""
        if (kind === "managed") return packageRoot + "/services/ObsidianTodoBackend.qml"
        if (kind === "daily") return packageRoot + "/services/DailyNoteTodoBackend.qml"
        return ""
    }
    function refresh(): void {
        if (probe.running) return
        available = false
        loadFailed = false
        probe.running = true
    }
    function status(): string {
        return JSON.stringify({available, enabled, diagnostic, version, sourceSha,
            managerBusy, managerError, updateAvailable, canRollback,
            integrations:{tlp:tlpEnabled,thinkfan:thinkfanEnabled,obsidian:obsidianEnabled}})
    }
    Loader {
        id: worker
        active: root.enabled
        onActiveChanged: {
            if (active) setSource(root.packageRoot + "/HadalisSession.qml", {host:root})
            else source = ""
        }
        onStatusChanged: if (status === Loader.Error) {
            root.loadFailed = true
            root.diagnostic = "load-failed"
        }
    }
    Process {
        id: probe
        command: ["/usr/bin/python3",Quickshell.shellPath("scripts/hadalird-status.py"),Quickshell.shellPath("")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    root.packageRoot = String(result.root ?? "")
                    root.version = String(result.version ?? "")
                    root.sourceSha = String(result.sourceSha ?? "")
                    root.diagnostic = String(result.diagnostic ?? "invalid-package")
                    root.available = result.available === true
                    root.canRollback = result.canRollback === true
                } catch (_error) {root.available=false;root.diagnostic="invalid-package";root.canRollback=false}
            }
        }
    }
    Process {
        id: managerProcess
        stdout: StdioCollector { id: managerOutput }
        stderr: StdioCollector { id: managerStderr }
        onExited: (exitCode) => {
            managerDeadline.stop()
            root.managerBusy = false
            try {
                const result = JSON.parse(String(managerOutput.text ?? "").trim())
                if (exitCode !== 0 || result.ok !== true) {
                    root.managerError = String(result.error ?? "Hadalird operation failed")
                } else {
                    root.managerMessage = String(result.message ?? (
                        root.managerAction === "check"
                            ? (result.updateAvailable ? "An update is available" : "Already up to date")
                            : "Operation completed"))
                    if (root.managerAction === "check") {
                        root.latestSha = String(result.latestSha ?? "")
                        root.updateAvailable = result.updateAvailable === true
                    } else {
                        root.updateAvailable = false
                        root.canRollback = result.canRollback === true
                    }
                }
            } catch (_error) {
                root.managerError = String(managerStderr.text ?? "Could not read Hadalird manager result").slice(0, 256)
            }
            if (root.managerAction !== "check") Qt.callLater(root.refresh)
        }
    }
    Timer {
        id: managerDeadline
        interval: 90000
        repeat: false
        onTriggered: {
            managerProcess.running = false
            root.managerBusy = false
            root.managerError = "Hadalird package operation timed out"
            root.refresh()
        }
    }
    IpcHandler {
        target: "hadalird"
        function refresh(): void {root.refresh()}
        function status(): string {return root.status()}
    }
    Component.onCompleted: root.refresh()
}
