pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import qs.modules.abyss.settings
import "looks/AbyssLayout.js" as Placement
import "looks/AbyssPresentation.js" as Presentation

// Drafts never write Config. Only Done merges this output into the latest profile.
Item {
    id: root
    required property string outputName
    required property var moduleLayer
    required property var controller
    property var edgeInsets: Placement.edgeInsetsForModules(moduleLayer.placements,moduleLayer.layoutOptions,
        Appearance.fontSizeScale,AbyssStyle.perimeterThickness,AbyssStyle.barThickness,false)
    property var draft: []
    property var handles: []
    property string selectedId: ""
    property real gap: 8
    property var edgeSizes: ({top:1,right:1,bottom:1,left:1})
    property var edgeThicknesses: ({top:-1,right:-1,bottom:-1,left:-1})
    property real moduleScale: 1
    property var singleModuleExpansion: ({top:"edge",right:"edge",bottom:"edge",left:"edge"})
    property string editingEdge: "top"
    property var guides: []
    property bool snapEnabled: true
    property bool outputOnly: true
    property bool editingPopups: false
    property var draftPositions: []
    property var positionEdits: []
    property alias previewKind:previewPositions.kind
    readonly property var previewPosition: Presentation.resolve(draftPositions,previewKind,outputOnly ? outputName : "")
    property alias previewHost:previewBody
    readonly property string previewNearbyCorner: Placement.adjacentEdge({edge:previewBody.edge,along:previewBody.along,span:previewBody.span},width,height)
    property real lastImpulse: 0
    property var inputRegions: []
    readonly property string nearbyCorner: Placement.adjacentEdge(moduleLayer.layoutRecords.find(p=>p.id===selectedId),width,height)
    readonly property var selected: draft.find(p => p.id === selectedId)
    readonly property var draftOptions: Object.assign({},Config.options?.abyss?.modules,{gap:gap,edgeSizes:edgeSizes,size:moduleScale,
        singleModuleExpansion:singleModuleExpansion,edgeThicknesses:edgeThicknesses,edgeThickness:AbyssStyle.perimeterThickness})
    function refreshHandles(): void { handles = draft.map(p => p.id) }
    function begin(): void {
        draft = JSON.parse(JSON.stringify(Placement.resolve(Config.options?.abyss?.modules,outputName,
            Placement.seed(moduleLayer.zones,moduleLayer.edge,width,height))))
        const options = Placement.optionsForOutput(Config.options?.abyss?.modules,outputName)
        gap = options.gap
        edgeSizes = Object.assign({top:1,right:1,bottom:1,left:1},options.edgeSizes)
        edgeThicknesses = Object.assign({top:-1,right:-1,bottom:-1,left:-1},options.edgeThicknesses)
        moduleScale = options.size
        singleModuleExpansion = Object.assign({top:"edge",right:"edge",bottom:"edge",left:"edge"},options.singleModuleExpansion)
        editingEdge = moduleLayer.edge
        guides = []
        draftPositions=JSON.parse(JSON.stringify(Config.options?.abyss?.positions ?? []))
        positionEdits=[];editingPopups=false
        selectedId = ""
        refreshHandles()
        forceActiveFocus()
    }
    function finish(save): void {
        if (save) {
            const writes=Placement.saveProfile(Config.options?.abyss?.modules,outputName,draft,gap,outputOnly,edgeSizes,singleModuleExpansion,moduleScale,edgeThicknesses)
            let positions=Config.options?.abyss?.positions ?? []
            positionEdits.forEach(edit=>positions=Presentation.save(positions,edit.kind,edit.outputName,edit.values))
            if(positionEdits.length) writes["abyss.positions"]=positions
            Config.setNestedValues(writes)
        }
        guides = []
        GlobalStates.abyssEditing = false
    }
    function reset(): void {
        draft = Placement.seed(moduleLayer.zones,moduleLayer.edge,width,height)
        gap = 8
        edgeSizes = {top:1,right:1,bottom:1,left:1}
        moduleScale = 1
        edgeThicknesses = {top:-1,right:-1,bottom:-1,left:-1}
        singleModuleExpansion = {top:"edge",right:"edge",bottom:"edge",left:"edge"}
        guides = []
        selectedId = ""
        draftPositions=JSON.parse(JSON.stringify(Config.options?.abyss?.positions ?? []));positionEdits=[]
        refreshHandles()
    }
    function change(key,value): void {
        draft = draft.map(p => p.id === selectedId ? Object.assign({},p,{[key]:value}) : p)
    }
    function editPosition(positions,kind,output,values): void {
        draftPositions=positions
        positionEdits=positionEdits.filter(edit=>edit.kind!==kind || edit.outputName!==output)
            .concat([{kind:kind,outputName:output,values:values}])
    }
    function movePreview(x,y): void {
        const location=Placement.project(x,y,width,height), horizontal=["top","bottom"].includes(location.edge)
        const length=horizontal ? width : height, point=horizontal ? x : y
        const inset=horizontal ? previewBody.edgeInsets.left : previewBody.edgeInsets.top
        const endInset=horizontal ? previewBody.edgeInsets.right : previewBody.edgeInsets.bottom
        const ratio=Math.max(0,Math.min(1,(point-previewBody.span/2-inset)/Math.max(1,length-inset-endInset-previewBody.span)))
        const values=Object.assign({},previewPosition,{edge:location.edge,alignment:"custom",position:ratio})
        const output=outputOnly ? outputName : ""
        editPosition(Presentation.save(draftPositions,previewKind,output,values),previewKind,output,values)
    }
    function move(id,x,y,snap = true): void {
        selectedId = id
        if (snap && snapEnabled) {
            const options = Object.assign({},draftOptions,{extents:moduleLayer.measuredExtents,editing:true})
            const result = Placement.snapMove(draft,id,x,y,width,height,options,Appearance.fontSizeScale)
            draft = result.placements
            guides = result.guides
        } else { draft = Placement.move(draft,id,x,y,width,height); guides = [] }
        editingEdge = draft.find(p => p.id===id)?.edge ?? editingEdge
        const now = Date.now()
        if (now-lastImpulse > 80) {
            const p = draft.find(p => p.id === id)
            controller.impulse(p.edge,p.position*(p.edge === "top" || p.edge === "bottom" ? width : height),90,.35,1,"drag")
            lastImpulse = now
        }
    }
    onSelectedChanged: if (selected) editingEdge = selected.edge
    function add(kind): void {
        if (draft.length >= 24) return
        const existing = draft.find(p => p.kind === kind && !p.enabled)
        if (existing) { selectedId = existing.id;change("enabled",true);return }
        const id = kind+"-"+Date.now()
        draft = Placement.normalize(draft.concat([{id:id,kind:kind,edge:editingEdge,position:.5}]),"top")
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
            readonly property Region inputRegion: Region { item:handle;width:root.editingPopups ? 0 : handle.width }
            x: record?.content.x ?? 0; y: record?.content.y ?? 0
            width: record?.content.width ?? 0; height: record?.content.height ?? 0
            visible: record !== undefined && !root.editingPopups
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
                onReleased: root.guides = []
                onCanceled: root.guides = []
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const point = mapToItem(root,mouse.x,mouse.y)
                    root.move(handle.modelData,point.x,point.y,!(mouse.modifiers & Qt.ShiftModifier))
                }
            }
        }
    }
    Repeater {
        model: root.guides
        Item {
            required property var modelData
            anchors.fill: parent
            Rectangle {
                x: modelData.horizontal ? modelData.along : 0
                y: modelData.horizontal ? 0 : modelData.along
                width: modelData.horizontal ? 1 : root.width
                height: modelData.horizontal ? root.height : 1
                color: AbyssStyle.accent; opacity: .6
            }
            AbyssLabel {
                text: modelData.label
                x: modelData.horizontal ? modelData.along+8 : root.width/2
                y: modelData.horizontal ? 76 : modelData.along+8
                color: AbyssStyle.accent
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
        edgeInsets: root.edgeInsets
        open: root.visible
        span: Math.min(root.width-48,1180); along: (root.width-span)/2; depth: Math.max(246,toolbar.implicitHeight+padding*2)
        embeddedItem: toolbar
    }
    AbyssBodyHost {
        id:previewBody;anchors.fill:parent;identity:"editorPreview";outputName:root.outputName
        controller:root.controller;placementPriority:-2;largeSurface:true
        open:root.visible && root.editingPopups
        contentKind:root.previewKind;source:"content/AbyssLayoutPreview.qml"
        edge:Presentation.edge(root.previewPosition,root.moduleLayer.edge)
        joinedEdge:Presentation.osds.includes(root.previewKind) && root.previewPosition.joinCorner===true ? root.previewNearbyCorner : ""
        edgeInsets:Placement.clearanceInsets(root.edgeInsets,root.moduleLayer.deformations,edge,along,span)
        span:(["top","bottom"].includes(edge) ? contentItem.item?.desiredWidth ?? 390 : contentItem.item?.desiredHeight ?? 120)+padding*2
        depth:(["top","bottom"].includes(edge) ? contentItem.item?.desiredHeight ?? 120 : contentItem.item?.desiredWidth ?? 390)+padding*2
        along:Presentation.along(root.previewPosition,edge,span,root.width,root.height,
            ((["top","bottom"].includes(edge) ? root.width : root.height)-span)/2,root.edgeInsets)
        MouseArea {
            parent:previewBody.contentParent;anchors.fill:parent
            cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPositionChanged:mouse=> { if(pressed) { const point=mapToItem(root,mouse.x,mouse.y);root.movePreview(point.x,point.y) } }
        }
    }
    readonly property Region previewRegion: Region { x:previewBody.inputBounds.x;y:previewBody.inputBounds.y;width:previewBody.inputBounds.width;height:previewBody.inputBounds.height }
    readonly property Region toolbarRegion: Region { item: toolbar }
    readonly property Region paletteRegion: Region { item: palette.popup.contentItem; width: palette.popup.visible ? palette.popup.contentItem.width : 0 }
    readonly property Region selectionRegion: Region { item: selection.popup.contentItem; width: selection.popup.visible ? selection.popup.contentItem.width : 0 }
    readonly property Region edgeRegion: Region { item: edgeChoice.popup.contentItem; width: edgeChoice.popup.visible ? edgeChoice.popup.contentItem.width : 0 }
    readonly property Region alignmentRegion: Region { item: alignmentChoice.popup.contentItem; width: alignmentChoice.popup.visible ? alignmentChoice.popup.contentItem.width : 0 }
    readonly property var regions: inputRegions.concat([toolbarRegion,paletteRegion,selectionRegion,edgeRegion,alignmentRegion,previewRegion],root.editingPopups ? previewPositions.inputRegions : [])
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
            SelectionGroupButton { buttonText:"Modules";toggled:!root.editingPopups;onClicked:root.editingPopups=false }
            SelectionGroupButton { buttonText:"Popups / IPC";toggled:root.editingPopups;onClicked:root.editingPopups=true }
            Item { Layout.fillWidth:true }
            AbyssCheckBox { visible:root.editingPopups;text:"This output only";checked:root.outputOnly;onToggled:root.outputOnly=checked }
        }
        AbyssPositionSettings {
            id:previewPositions;visible:root.editingPopups;kind:"volume"
            commitImmediately:false;positions:root.draftPositions
            outputSelectionEnabled:false;outputName:root.outputOnly ? root.outputName : ""
            nearbyEdge:root.previewNearbyCorner
            allowedKinds:["clock","resources","battery","media","weather","wifi","bluetooth","utilities","volume","brightness","mic","mediaOsd","keyboardLayout"]
            onPositionsEdited:(positions,kind,outputName,values)=>root.editPosition(positions,kind,outputName,values)
        }
        RowLayout {
            visible:!root.editingPopups
            StyledComboBox { id: palette; model: Placement.catalog.map(kind => ({label:Placement.label(kind),kind:kind})); textRole:"label";valueRole:"kind";Layout.preferredWidth: 190 }
            AbyssButton { text: "Add module"; glyph: "add"; enabled: root.draft.length<24; onClicked: root.add(palette.currentValue) }
            AbyssLabel { text: "Gap" }
            AbyssSlider { unit:"px";from: 0; to: 32; value: root.gap; onMoved: root.gap=value; Layout.fillWidth: true }
            AbyssCheckBox { text: "This output only"; checked: root.outputOnly; onToggled: root.outputOnly=checked }
        }
        RowLayout {
            visible:!root.editingPopups
            AbyssLabel { text: "Edge" }
            StyledComboBox { id: edgeChoice; model:["top","right","bottom","left"]; currentIndex:model.indexOf(root.editingEdge); onActivated:root.editingEdge=currentText; Layout.preferredWidth:110 }
            AbyssLabel { text: "Shared size" }
            AbyssSlider { from:.6;to:1.8;value:Placement.edgeSize(root.draftOptions,root.editingEdge);Layout.fillWidth:true;onMoved:root.edgeSizes=Object.assign({},root.edgeSizes,{[root.editingEdge]:value}) }
            AbyssCheckBox { text:"Snap to guides";checked:root.snapEnabled;onToggled:root.snapEnabled=checked }
        }
        RowLayout {
            visible:!root.editingPopups
            AbyssLabel { text:"Edge thickness" }
            AbyssSlider {
                unit:"px";from:10;to:40;stepSize:1;Layout.fillWidth:true
                value:Placement.edgeThickness(root.draftOptions,root.editingEdge)
                onMoved:root.edgeThicknesses=Object.assign({},root.edgeThicknesses,{[root.editingEdge]:value})
            }
            AbyssButton {
                text:"Inherit surface";enabled:(root.edgeThicknesses[root.editingEdge] ?? -1)>=0
                onClicked:root.edgeThicknesses=Object.assign({},root.edgeThicknesses,{[root.editingEdge]:-1})
            }
        }
        RowLayout {
            visible:!root.editingPopups
            AbyssLabel { text:"Overall size" }
            AbyssSlider { from:.6;to:1.8;value:root.moduleScale;Layout.fillWidth:true;onMoved:root.moduleScale=value }
            AbyssCheckBox {
                text:"Single module expands the whole Edge"
                enabled:root.draft.filter(p=>p.enabled && p.edge===root.editingEdge).length===1
                checked:root.singleModuleExpansion[root.editingEdge]!=="local"
                onToggled:root.singleModuleExpansion=Object.assign({},root.singleModuleExpansion,{[root.editingEdge]:checked ? "edge" : "local"})
                StyledToolTip { text:"Disable to expand only the surface around a single module. Application space remains reserved for it." }
            }
        }
        RowLayout {
            visible:!root.editingPopups
            StyledComboBox {
                id: selection
                model: root.draft.map(p => ({label:Placement.label(p.kind)+(p.enabled ? "" : " (disabled)"),id:p.id}))
                textRole:"label";valueRole:"id";currentIndex:root.draft.findIndex(p => p.id===root.selectedId)
                displayText:root.selected ? Placement.label(root.selected.kind) : "Select a module"
                onActivated:root.selectedId=currentValue;Layout.preferredWidth:190
            }
            AbyssButton { text: root.selected?.enabled === false ? "Enable" : "Disable"; enabled: root.selected !== undefined; onClicked: root.change("enabled",!root.selected.enabled) }
            AbyssButton { text: "Remove"; enabled: root.selected !== undefined; onClicked: { root.draft=root.draft.filter(p => p.id!==root.selectedId);root.selectedId="";root.refreshHandles() } }
            StyledComboBox {
                id: alignmentChoice
                model:[{label:"Free position",value:"free"},{label:"Align start",value:"start"},{label:"Align center",value:"center"},{label:"Align end",value:"end"}]
                textRole:"label";valueRole:"value";currentIndex:Math.max(0,model.findIndex(p => p.value===root.selected?.alignment))
                enabled:root.selected !== undefined;onActivated:root.change("alignment",currentValue);Layout.preferredWidth:146
            }
            AbyssCheckBox {
                text:"Custom size";checked:root.selected?.customSize ?? false;enabled:root.selected !== undefined
                onToggled: {
                    if(checked) root.change("size",Placement.edgeSize(root.draftOptions,root.selected.edge))
                    root.change("customSize",checked)
                }
            }
            AbyssCheckBox {
                text: root.nearbyCorner ? "Join "+root.nearbyCorner+" Edge" : "Join nearby corner"
                checked: root.selected?.joinCorner ?? false
                enabled: root.selected !== undefined && (!!root.nearbyCorner || checked)
                onToggled: root.change("joinCorner",checked)
                StyledToolTip { text: root.nearbyCorner ? "Fuse this module's nearby popup with both Screen Edges, preserving its content layout." : "Move the module within 160 px of a corner to join the adjacent Screen Edge." }
            }
            AbyssSlider { from: .6; to: 1.8; value: root.selected?.customSize ? root.selected.size : Placement.edgeSize(root.draftOptions,root.selected?.edge ?? root.editingEdge); enabled: root.selected?.customSize ?? false; Layout.fillWidth:true; onMoved: root.change("size",value) }
        }
        AbyssLabel {
            text: root.editingPopups
                ? "Drag preview · Enter save · Esc cancel"
                : "Drag to move/reorder · Shift free · Enter save · Esc cancel"
            color: AbyssStyle.textColorMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
