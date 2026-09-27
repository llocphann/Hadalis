pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.abyss.looks
import "looks/AbyssLayout.js" as Placement

// Drafts never write Config. Only Done merges this output into the latest profile.
Item {
    id: root
    required property string outputName
    required property var moduleLayer
    required property var controller
    property var draft: []
    property var handles: []
    property string selectedId: ""
    property real gap: 8
    property bool outputOnly: true
    property real lastImpulse: 0
    property var inputRegions: []
    readonly property var selected: draft.find(p => p.id === selectedId)
    readonly property var draftOptions: Object.assign({},Config.options?.abyss?.modules,{gap:gap})
    function refreshHandles(): void { handles = draft.map(p => p.id) }
    function begin(): void {
        draft = JSON.parse(JSON.stringify(Placement.resolve(Config.options?.abyss?.modules,outputName,
            Placement.seed(moduleLayer.zones,moduleLayer.edge,width,height))))
        gap = Placement.optionsForOutput(Config.options?.abyss?.modules,outputName).gap
        selectedId = ""
        refreshHandles()
        forceActiveFocus()
    }
    function finish(save): void {
        if (save) Config.setNestedValues(Placement.saveProfile(Config.options?.abyss?.modules,outputName,draft,gap,outputOnly))
        GlobalStates.abyssEditing = false
    }
    function reset(): void {
        draft = Placement.seed(moduleLayer.zones,moduleLayer.edge,width,height)
        gap = 8
        selectedId = ""
        refreshHandles()
    }
    function change(key,value): void {
        draft = draft.map(p => p.id === selectedId ? Object.assign({},p,{[key]:value}) : p)
    }
    function move(id,x,y): void {
        selectedId = id
        draft = Placement.move(draft,id,x,y,width,height)
        const now = Date.now()
        if (now-lastImpulse > 80) {
            const p = draft.find(p => p.id === id)
            controller.impulse(p.edge,p.position*(p.edge === "top" || p.edge === "bottom" ? width : height),90,.35,1,"drag")
            lastImpulse = now
        }
    }
    function add(kind): void {
        if (draft.length >= 24) return
        const existing = draft.find(p => p.kind === kind && !p.enabled)
        if (existing) { selectedId = existing.id;change("enabled",true);return }
        const id = kind+"-"+Date.now()
        draft = Placement.normalize(draft.concat([{id:id,kind:kind,edge:"top",position:.5}]),"top")
        selectedId = id
        refreshHandles()
    }
    onVisibleChanged: if (visible) begin()
    Component.onCompleted: if (visible) begin()
    Component.onDestruction: if (GlobalStates.abyssEditorTargetOutput === outputName) GlobalStates.abyssEditing = false
    Keys.onEscapePressed: finish(false)
    Keys.onReturnPressed: finish(true)
    Repeater {
        model: root.handles
        onItemAdded: (index,item) => root.inputRegions = root.inputRegions.concat([item.inputRegion])
        onItemRemoved: (index,item) => root.inputRegions = root.inputRegions.filter(region => region !== item.inputRegion)
        Item {
            id: handle
            required property string modelData
            readonly property var record: root.moduleLayer.layoutRecords.find(p => p.id === modelData)
            readonly property Region inputRegion: Region { item: handle }
            x: record?.content.x ?? 0; y: record?.content.y ?? 0
            width: record?.content.width ?? 0; height: record?.content.height ?? 0
            visible: record !== undefined
            Rectangle {
                anchors.fill: parent; anchors.margins: -3
                color: Qt.alpha(AbyssStyle.accent,drag.pressed ? .22 : .08)
                radius: 8
                border.width: root.selectedId === handle.modelData ? 2 : 1
                border.color: Qt.alpha(AbyssStyle.accent,.6)
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed: root.selectedId = handle.modelData
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const point = mapToItem(root,mouse.x,mouse.y)
                    root.move(handle.modelData,point.x,point.y)
                }
            }
        }
    }
    // Anchor hints paint only; the work area remains click-through in edit mode.
    Repeater {
        model: ["top","right","bottom","left"]
        AbyssLabel {
            required property string modelData
            text: modelData.toUpperCase()
            opacity: .55
            x: modelData === "left" ? 50 : modelData === "right" ? root.width-width-50 : (root.width-width)/2
            y: modelData === "top" ? 64 : modelData === "bottom" ? root.height-220 : (root.height-height)/2
        }
    }
    AbyssBodyHost {
        id: editorBody
        anchors.fill: parent
        edge: "bottom"; identity: "edgeEditor"; outputName: root.outputName
        controller: root.controller
        open: root.visible
        span: Math.min(root.width-80,1000); along: (root.width-span)/2; depth: 192
        embeddedItem: toolbar
    }
    readonly property Region toolbarRegion: Region { item: toolbar }
    readonly property var regions: inputRegions.concat([toolbarRegion])
    ColumnLayout {
        id: toolbar
        parent: editorBody.contentParent
        anchors.fill: parent
        spacing: 6
        RowLayout {
            AbyssLabel { text: "Live Edge Editor · "+root.outputName; font.bold: true; Layout.fillWidth: true }
            AbyssButton { text: "Reset"; onClicked: root.reset() }
            AbyssButton { text: "Cancel"; onClicked: root.finish(false) }
            AbyssButton { text: "Done"; glyph: "check"; onClicked: root.finish(true) }
        }
        RowLayout {
            ComboBox { id: palette; model: Placement.catalog; Layout.preferredWidth: 190 }
            AbyssButton { text: "Add module"; glyph: "add"; enabled: root.draft.length<24; onClicked: root.add(palette.currentText) }
            AbyssLabel { text: "Gap" }
            AbyssSlider { from: 0; to: 32; value: root.gap; onMoved: root.gap=value; Layout.fillWidth: true }
            CheckBox { text: "This output only"; checked: root.outputOnly; onToggled: root.outputOnly=checked }
        }
        RowLayout {
            AbyssLabel { text: root.selected?.kind ?? "Drag a module to any edge"; Layout.fillWidth: true }
            ComboBox { model: root.draft.map(p => p.id); onActivated: root.selectedId=currentText; Layout.preferredWidth: 170 }
            AbyssButton { text: root.selected?.enabled === false ? "Enable" : "Disable"; enabled: root.selected !== undefined; onClicked: root.change("enabled",!root.selected.enabled) }
            AbyssButton { text: "Remove"; enabled: root.selected !== undefined; onClicked: { root.draft=root.draft.filter(p => p.id!==root.selectedId);root.selectedId="";root.refreshHandles() } }
            AbyssLabel { text: "Size" }
            AbyssSlider { from: .6; to: 1.8; value: root.selected?.size ?? 1; enabled: root.selected !== undefined; Layout.preferredWidth: 100; onMoved: root.change("size",value) }
        }
        AbyssLabel { text: "Drag along an edge to reorder. Drag toward another edge to move there. Enter saves; Escape cancels."; color: AbyssStyle.textColorMuted }
    }
}
