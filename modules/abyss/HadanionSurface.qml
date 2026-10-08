import QtQuick
import Quickshell
import qs.services
import "looks/AbyssWave.js" as Wave

// Only host handles and finite presentation outputs cross the optional API.
Item {
    id: root
    required property var host
    required property var hostLiquid
    required property var hostField
    required property var hostBar
    required property var hostLeftPanel
    required property var hostRightPanel
    required property var hostCorners
    required property var hostUtility
    required property var hostBarHover
    required property var hostRevealHover
    readonly property Item overlayParent: parent || root
    readonly property var waveFunctions: Wave
    readonly property var session: Hadanion.session
    readonly property string outputName: host.outputName
    readonly property var extension: outputLoader.status === Loader.Ready ? outputLoader.item : null
    readonly property bool editing: extension?.editing ?? false
    readonly property bool curiosityOwned: extension?.curiosityOwned ?? false
    readonly property bool utilitiesVisitActive: extension?.utilitiesVisitActive ?? false
    readonly property bool dockHeld: extension?.dockHeld ?? false
    readonly property var waterLink: extension?.waterLink ?? null
    readonly property var inputRegions: extension?.inputRegions ?? []
    function yieldToUser(): void {if(extension) extension.yieldToUser()}
    function requestCompanionChat(): void {if(extension) extension.requestCompanionChat()}
    function resetCompanionCast(): void {if(extension) extension.resetCompanionCast()}
    function companionStatus() {return extension ? extension.status() : {output:outputName,active:false}}
    Loader {
        id: outputLoader
        anchors.fill: parent
        active: root.session !== null
        onStatusChanged: if(status===Loader.Error) Hadanion.failLoad()
        onActiveChanged: {
            if (active) setSource(Hadanion.outputSource,{adapter:root})
            else source=""
        }
    }
    Component.onCompleted: Hadanion.registerOutput(root)
    Component.onDestruction: Hadanion.unregisterOutput(root)
}
