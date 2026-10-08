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
    readonly property var options: Config.options?.integrations?.hadalird
    readonly property bool tlpEnabled: available && !loadFailed && Config.ready && options?.tlp === true
    readonly property bool thinkfanEnabled: available && !loadFailed && Config.ready && options?.thinkfan === true
    readonly property bool obsidianEnabled: available && !loadFailed && Config.ready && options?.obsidian === true
    readonly property bool enabled: tlpEnabled || thinkfanEnabled || obsidianEnabled
    readonly property var session: worker.status === Loader.Ready ? worker.item : null

    function settingsSource(integration): string {
        if (!available) return ""
        if (integration === "tlp") return packageRoot + "/modules/settings/TlpPowerSettings.qml"
        if (integration === "obsidian") return packageRoot + "/modules/settings/ObsidianThemeSettings.qml"
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
                } catch (_error) {root.available=false;root.diagnostic="invalid-package"}
            }
        }
    }
    IpcHandler {
        target: "hadalird"
        function refresh(): void {root.refresh()}
        function status(): string {return root.status()}
    }
    Component.onCompleted: root.refresh()
}
