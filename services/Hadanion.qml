pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Host API v1. The external package is never imported by the core shell.
Singleton {
    id: root
    property bool available: false
    property string version: ""
    property string diagnostic: "not-installed"
    property string packageRoot: ""
    property string sourceSha: ""
    property bool loadFailed: false
    property var outputs: []
    readonly property bool enabled: available && !loadFailed && Config.ready
        && Config.options?.panelFamily === "abyss"
        && Config.options?.abyss?.companion?.enabled === true
    readonly property var session: sessionLoader.status === Loader.Ready ? sessionLoader.item : null
    readonly property string sessionSource: packageRoot + "/HadalisSession.qml"
    readonly property string outputSource: packageRoot + "/HadalisOutput.qml"
    readonly property string settingsSource: available ? packageRoot + "/modules/settings/CompanionConfig.qml" : ""

    function registerOutput(output): void {
        if (!outputs.includes(output)) outputs=outputs.concat([output])
    }
    function unregisterOutput(output): void { outputs=outputs.filter(item=>item!==output) }
    function refresh(): void {
        if (probe.running) return
        available=false
        loadFailed=false
        probe.running=true
    }
    function failLoad(): void {loadFailed=true;diagnostic="load-failed"}
    function chat(): void { if (session) session.chat() }
    function status(): string {
        if (session) return JSON.stringify(Object.assign(
            {available:available,version:version,sourceSha:sourceSha,diagnostic:diagnostic},
            JSON.parse(session.status())))
        return JSON.stringify({available:available,version:version,enabled:enabled,
            sourceSha:sourceSha,sessionVisible:false,diagnostic:diagnostic,backend:{ready:false},outputs:[]})
    }
    Loader {
        id: sessionLoader
        active: root.enabled
        onStatusChanged: if(status===Loader.Error) root.failLoad()
        onActiveChanged: {
            if (active) setSource(root.sessionSource,{host:root})
            else source=""
        }
    }
    Process {
        id: probe
        command: ["/usr/bin/python3",Quickshell.shellPath("scripts/hadanion-status.py"),Quickshell.shellPath("")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result=JSON.parse(text)
                    root.packageRoot=String(result.root ?? "")
                    root.sourceSha=String(result.sourceSha ?? "")
                    root.available=result.available===true
                    root.version=String(result.version ?? "")
                    root.diagnostic=String(result.diagnostic ?? "not-installed")
                } catch (_error) {root.available=false;root.diagnostic="invalid-package"}
            }
        }
    }
    // Preserve the existing keybind and command without requiring the package.
    IpcHandler {
        target: "wull"
        function chat(): void {root.chat()}
        function status(): string {return root.status()}
    }
    IpcHandler {
        target: "hadanion"
        function refresh(): void {root.refresh()}
        function status(): string {return root.status()}
    }
    Component.onCompleted: root.refresh()
}
