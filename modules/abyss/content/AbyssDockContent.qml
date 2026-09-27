pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.abyss.looks

Item {
    id: root
    property string outputName: ""
    property string edge: "bottom"
    property var participant: null
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property var apps: TaskbarApps.apps.filter(app => app.appId !== "SEPARATOR")
    readonly property string lease: "abyssDock:"+outputName
    property string heldLease: ""
    function react(index, strength): void {
        if (!participant?.controller) return
        const rec = participant.record
        const extent = root.vertical ? root.height : root.width
        const size = extent/(root.apps.length+1)
        const padding = root.vertical ? rec.content.y-rec.along : rec.content.x-rec.along
        participant.controller.impulse(edge,rec.along+padding+(index+.5)*size,size,strength,1,"module")
    }
    function syncLease(): void {
        if (heldLease.length) CompositorService.setSortingConsumer(heldLease,false)
        heldLease = lease
        CompositorService.setSortingConsumer(heldLease,true)
    }
    onLeaseChanged: if (heldLease.length) Qt.callLater(syncLease)
    Component.onCompleted: Qt.callLater(syncLease)
    Component.onDestruction: if (heldLease.length) CompositorService.setSortingConsumer(heldLease,false)
    Repeater {
        model: root.apps
        AbyssButton {
            id: appButton
            required property var modelData
            required property int index
            readonly property var entry: AppSearch.lookupDesktopEntry(modelData.appId)
            x: root.vertical ? 0 : index*width
            y: root.vertical ? index*height : 0
            width: root.vertical ? root.width : root.width/(root.apps.length+1)
            height: root.vertical ? root.height/(root.apps.length+1) : root.height
            description: (entry?.name || modelData.appId)+(modelData.pinned ? " · pinned" : "")
            onHoveredChanged: root.react(index,hovered ? .4 : -.15)
            onDownChanged: root.react(index,down ? 1 : -.3)
            onClicked: {
                if (modelData.toplevels.length > 0) modelData.toplevels[0].activate()
                else if (entry) AppSearch.launchEntry(entry)
            }
            Image {
                anchors.centerIn: parent
                width: Math.min(32,parent.width-4); height: Math.min(32,parent.height-4)
                source: AppSearch.getIconSource(appButton.entry?.icon || appButton.modelData.appId,"application-x-executable")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                opacity: appButton.hovered ? 1 : 0.88
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: 2; color: AbyssStyle.accent; visible: appButton.modelData.toplevels.length > 0 }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: TaskbarApps.togglePin(appButton.modelData.appId) }
        }
    }
    AbyssButton {
        x: root.vertical ? 0 : root.apps.length*width
        y: root.vertical ? root.apps.length*height : 0
        width: root.vertical ? root.width : root.width/(root.apps.length+1)
        height: root.vertical ? root.height/(root.apps.length+1) : root.height
        glyph: "apps"; description: "Open launcher"
        onHoveredChanged: root.react(root.apps.length,hovered ? .4 : -.15)
        onDownChanged: root.react(root.apps.length,down ? 1 : -.3)
        onClicked: GlobalStates.toggleOverview(root.outputName)
    }
}
