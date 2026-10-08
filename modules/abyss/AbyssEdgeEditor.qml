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
    property var edgeWidthAffectsModules: ({top:true,right:true,bottom:true,left:true})
    property var edgeJoinModules: ({top:false,right:false,bottom:false,left:false})
    property real moduleScale: 1
    property var singleModuleExpansion: ({top:"edge",right:"edge",bottom:"edge",left:"edge"})
    property string editingEdge: "top"
    // Keep the editor controls on the least-contended Screen Edge. The selected
    // module's Edge receives a large penalty, while a small hysteresis bonus
    // keeps the toolbar from oscillating between equal candidates mid-drag.
    property string toolbarEdge: "bottom"
    readonly property bool toolbarOnHorizontalEdge:
        toolbarEdge === "top" || toolbarEdge === "bottom"
    property var guides: []
    property bool snapEnabled: true
    property bool outputOnly: true
    property bool editingPopups: false
    property var draftPositions: []
    property var positionEdits: []
    property alias previewKind:previewPositions.kind
    readonly property var previewPosition: Presentation.resolve(draftPositions,previewKind,outputOnly ? outputName : "")
    property alias previewHost:previewBody
    readonly property string previewNearbyCorner:
        Presentation.nearbyEdge(previewBody.edge,previewBody.along,
            previewBody.span,width,height)
    property real lastImpulse: 0
    property var inputRegions: []
    readonly property string nearbyCorner: Placement.adjacentEdge(moduleLayer.layoutRecords.find(p=>p.id===selectedId),width,height)
    readonly property var selected: draft.find(p => p.id === selectedId)
    readonly property var draftOptions: Object.assign({},Config.options?.abyss?.modules,{gap:gap,edgeSizes:edgeSizes,size:moduleScale,
        singleModuleExpansion:singleModuleExpansion,edgeThicknesses:edgeThicknesses,edgeWidthAffectsModules:edgeWidthAffectsModules,edgeJoinModules:edgeJoinModules,edgeThickness:AbyssStyle.perimeterThickness})

    function toolbarEdgeScore(edge): real {
        let score = (edge === toolbarEdge ? -4 : 0)
        // Side placement remains available, but top/bottom wins close ties
        // because the existing control rows are naturally horizontal.
        if (edge === "left" || edge === "right")
            score += 6
        if (edge === editingEdge)
            score += selected ? 54 : 12

        if (root.editingPopups) {
            // Popup/IPC previews are first-class edit targets too. Keep the
            // controls off the preview's physical Edge (and its joined Edge)
            // so dragging a persistent example never happens under the toolbar.
            if (edge === previewBody.edge) {
                const edgeLength = ["top","bottom"].includes(edge)
                    ? root.width : root.height
                const occupancy = Math.min(1,
                    previewBody.span / Math.max(1, edgeLength))
                score += 260 + occupancy * 120
            }
            if (previewBody.joinedEdge.length > 0
                    && edge === previewBody.joinedEdge)
                score += 180
        }

        for (let i = 0; i < draft.length; ++i) {
            const placement = draft[i]
            if (placement?.enabled === false || placement?.edge !== edge)
                continue
            const scale = placement?.customSize
                ? Number(placement?.size ?? 1)
                : Placement.edgeSize(draftOptions,edge)
            score += 18 + Math.max(.5,scale) * 8
            if (placement?.id === selectedId)
                score += 220
        }
        return score
    }

    function bestToolbarEdge(): string {
        const candidates = ["bottom","top","right","left"]
        let best = candidates[0]
        let bestScore = toolbarEdgeScore(best)
        for (let i = 1; i < candidates.length; ++i) {
            const score = toolbarEdgeScore(candidates[i])
            if (score < bestScore) {
                best = candidates[i]
                bestScore = score
            }
        }
        return best
    }

    function scheduleToolbarRelocation(): void {
        if (visible)
            toolbarRelocate.restart()
    }

    function relocateToolbar(): void {
        const next = bestToolbarEdge()
        if (next !== toolbarEdge)
            toolbarEdge = next
    }

    function refreshHandles(): void { handles = draft.map(p => p.id) }
    function begin(): void {
        draft = JSON.parse(JSON.stringify(Placement.resolve(Config.options?.abyss?.modules,outputName,
            Placement.seed(moduleLayer.zones,moduleLayer.edge,width,height))))
        const options = Placement.optionsForOutput(Config.options?.abyss?.modules,outputName)
        gap = options.gap
        edgeSizes = Object.assign({top:1,right:1,bottom:1,left:1},options.edgeSizes)
        edgeThicknesses = Object.assign({top:-1,right:-1,bottom:-1,left:-1},options.edgeThicknesses)
        edgeWidthAffectsModules = Object.assign({top:true,right:true,bottom:true,left:true},options.edgeWidthAffectsModules)
        edgeJoinModules = Object.assign({top:false,right:false,bottom:false,left:false},options.edgeJoinModules)
        moduleScale = options.size
        singleModuleExpansion = Object.assign({top:"edge",right:"edge",bottom:"edge",left:"edge"},options.singleModuleExpansion)
        editingEdge = moduleLayer.edge
        guides = []
        draftPositions=JSON.parse(JSON.stringify(Config.options?.abyss?.positions ?? []))
        positionEdits=[];editingPopups=false
        selectedId = ""
        refreshHandles()
        Qt.callLater(() => root.relocateToolbar())
        forceActiveFocus()
    }
    function finish(save): void {
        if (save) {
            const writes=Placement.saveProfile(Config.options?.abyss?.modules,outputName,draft,gap,outputOnly,edgeSizes,singleModuleExpansion,moduleScale,edgeThicknesses,edgeWidthAffectsModules,edgeJoinModules)
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
        edgeWidthAffectsModules = {top:true,right:true,bottom:true,left:true}
        edgeJoinModules = {top:false,right:false,bottom:false,left:false}
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
        root.scheduleToolbarRelocation()
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
        root.scheduleToolbarRelocation()
        const now = Date.now()
        if (now-lastImpulse > 80) {
            const p = draft.find(p => p.id === id)
            controller.impulse(p.edge,p.position*(p.edge === "top" || p.edge === "bottom" ? width : height),90,.35,1,"drag")
            lastImpulse = now
        }
    }
    onSelectedChanged: {
        if (selected)
            editingEdge = selected.edge
        root.scheduleToolbarRelocation()
    }
    onEditingEdgeChanged: root.scheduleToolbarRelocation()
    onDraftChanged: root.scheduleToolbarRelocation()
    onEditingPopupsChanged: root.scheduleToolbarRelocation()
    onPreviewPositionChanged: root.scheduleToolbarRelocation()
    onPreviewKindChanged: root.scheduleToolbarRelocation()
    onOutputOnlyChanged: root.scheduleToolbarRelocation()

    Timer {
        id: toolbarRelocate
        interval: 90
        repeat: false
        onTriggered: root.relocateToolbar()
    }

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
    // The hint for the Edge that owns the editor must stay outside its body,
    // otherwise it reads like part of the control surface.
    Repeater {
        model: ["top","right","bottom","left"]
        AbyssLabel {
            required property string modelData
            readonly property var editorSurface: editorBody.record?.surface ?? null
            readonly property bool editorEdge: modelData === root.toolbarEdge
            text: modelData.toUpperCase()
            opacity: .55
            x: {
                if (editorEdge && editorSurface) {
                    if (modelData === "left")
                        return Math.min(root.width-width-10,
                            editorSurface.x+editorSurface.width+12)
                    if (modelData === "right")
                        return Math.max(10,editorSurface.x-width-12)
                }
                return modelData === "left" ? 50
                    : modelData === "right" ? root.width-width-50
                    : (root.width-width)/2
            }
            y: {
                if (editorEdge && editorSurface) {
                    if (modelData === "top")
                        return Math.min(root.height-height-10,
                            editorSurface.y+editorSurface.height+12)
                    if (modelData === "bottom")
                        return Math.max(10,editorSurface.y-height-12)
                }
                return modelData === "top" ? 64
                    : modelData === "bottom" ? root.height-220
                    : (root.height-height)/2
            }
        }
    }
    AbyssBodyHost {
        id: editorBody
        anchors.fill: parent
        edge: root.toolbarEdge
        identity: "edgeEditor"
        outputName: root.outputName
        controller: root.controller
        edgeInsets: root.edgeInsets
        open: root.visible
        // Horizontal Edges use the familiar wide control strip. If both are
        // busy, the same editor can move to a side Edge with a deeper body and
        // a long vertical span instead of covering the module being edited.
        span: root.toolbarOnHorizontalEdge
            ? Math.min(root.width-48,1180)
            : Math.min(root.height-48,920)
        along: ((root.toolbarOnHorizontalEdge ? root.width : root.height)-span)/2
        depth: root.toolbarOnHorizontalEdge
            ? Math.max(246,toolbar.implicitHeight+padding*2)
            : Math.min(root.width-48,
                Math.max(340,Math.min(460,root.width*.32)))
        embeddedItem: toolbar
    }
    AbyssBodyHost {
        id:previewBody;anchors.fill:parent;identity:"editorPreview";outputName:root.outputName
        controller:root.controller;placementPriority:-2;largeSurface:true
        open:root.visible && root.editingPopups
        contentKind:root.previewKind;source:"content/AbyssLayoutPreview.qml"
        edge:Presentation.edge(root.previewPosition,root.moduleLayer.edge)
        joinedEdge:Presentation.joinedEdge(root.previewKind,
            root.previewPosition,edge,along,span,root.width,root.height)
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
    Item {
        id: toolbar
        parent: editorBody.contentParent
        anchors.fill: parent
        implicitWidth: root.toolbarOnHorizontalEdge
            ? toolbarColumn.implicitWidth : 410
        implicitHeight: toolbarColumn.implicitHeight

        Flickable {
            id: toolbarScroll
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: toolbarColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: !root.toolbarOnHorizontalEdge
                && contentHeight > height

            ColumnLayout {
                id: toolbarColumn
                width: toolbarScroll.width
                spacing: root.toolbarOnHorizontalEdge ? 6 : 10

                RowLayout {
                    Layout.fillWidth: true
                    AbyssLabel {
                        text: "Live Edge Editor · "+root.outputName
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    AbyssButton {
                        text: "Reset"; glyph: "restart_alt"; compact: true
                        description: "Reset layout draft"
                        onClicked: root.reset()
                    }
                    AbyssButton {
                        text: "Cancel"; glyph: "close"; compact: true
                        description: "Cancel editing"
                        onClicked: root.finish(false)
                    }
                    AbyssButton {
                        text: "Done"; glyph: "check"
                        description: "Save layout changes"
                        onClicked: root.finish(true)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    SelectionGroupButton {
                        buttonIcon:"widgets";buttonText:"Modules";toggled:!root.editingPopups
                        onClicked:root.editingPopups=false
                    }
                    SelectionGroupButton {
                        buttonIcon:"open_in_new";buttonText:"Popups / IPC";toggled:root.editingPopups
                        onClicked:root.editingPopups=true
                    }
                    Item { Layout.fillWidth:true }
                    AbyssCheckBox {
                        visible:root.editingPopups
                        text:"This output only"
                        checked:root.outputOnly
                        onToggled:root.outputOnly=checked
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    visible: !root.toolbarOnHorizontalEdge
                    color: Qt.alpha(AbyssStyle.accent,.18)
                }

                AbyssLabel {
                    visible: !root.toolbarOnHorizontalEdge
                    text: root.editingPopups
                        ? "Popup / IPC placement" : "Module placement"
                    font.bold: true
                    color: Appearance.m3colors.darkmode ? AbyssStyle.textColorMuted : "#1a1a1a"
                    Layout.fillWidth: true
                }

                AbyssPositionSettings {
                    id:previewPositions
                    visible:root.editingPopups
                    kind:"volume"
                    compactVertical:!root.toolbarOnHorizontalEdge
                    compactActions:root.toolbarOnHorizontalEdge
                    commitImmediately:false
                    positions:root.draftPositions
                    outputSelectionEnabled:false
                    outputName:root.outputOnly ? root.outputName : ""
                    nearbyEdge:root.previewNearbyCorner
                    allowedKinds:["clock","resources","battery","media","weather","wifi","utilities","launcher",
                        "quickNotes","notificationCenter","notifications",
                        "volume","brightness","mic","mediaOsd","keyboardLayout"]
                    onPositionsEdited:(positions,kind,outputName,values)=>
                        root.editPosition(positions,kind,outputName,values)
                }

                GridLayout {
                    visible:!root.editingPopups
                    Layout.fillWidth:true
                    columns:root.toolbarOnHorizontalEdge ? 5 : 1
                    rowSpacing:6
                    columnSpacing:6

                    StyledComboBox {
                        id: palette
                        model: Placement.catalog.map(kind => ({label:Placement.label(kind),kind:kind}))
                        textRole:"label";valueRole:"kind"
                        Layout.preferredWidth: root.toolbarOnHorizontalEdge ? 190 : -1
                        Layout.fillWidth: !root.toolbarOnHorizontalEdge
                    }
                    AbyssButton {
                        text:"Add module";glyph:"add"
                        compact:root.toolbarOnHorizontalEdge
                        description:"Add selected module"
                        enabled:root.draft.length<24
                        Layout.fillWidth: !root.toolbarOnHorizontalEdge
                        onClicked:root.add(palette.currentValue)
                    }
                    AbyssLabel { text:"Gap" }
                    AbyssSlider {
                        unit:"px";from:0;to:32;value:root.gap
                        onMoved:root.gap=value
                        Layout.fillWidth:true
                    }
                    AbyssCheckBox {
                        text:"This output only";checked:root.outputOnly
                        Layout.fillWidth: !root.toolbarOnHorizontalEdge
                        onToggled:root.outputOnly=checked
                    }
                }

                Rectangle {
                    Layout.fillWidth:true;height:1
                    visible:!root.toolbarOnHorizontalEdge && !root.editingPopups
                    color:Qt.alpha(AbyssStyle.accent,.12)
                }

                GridLayout {
                    visible:!root.editingPopups
                    Layout.fillWidth:true
                    columns:root.toolbarOnHorizontalEdge ? 5 : 1
                    rowSpacing:6
                    columnSpacing:6

                    AbyssLabel { text:"Edge" }
                    StyledComboBox {
                        id:edgeChoice
                        model:["top","right","bottom","left"]
                        currentIndex:model.indexOf(root.editingEdge)
                        onActivated:root.editingEdge=currentText
                        Layout.preferredWidth:root.toolbarOnHorizontalEdge ? 110 : -1
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                    }
                    AbyssLabel { text:"Shared size" }
                    AbyssSlider {
                        from:.6;to:1.8
                        value:Placement.edgeSize(root.draftOptions,root.editingEdge)
                        Layout.fillWidth:true
                        onMoved:root.edgeSizes=Object.assign(
                            {},root.edgeSizes,{[root.editingEdge]:value})
                    }
                    AbyssButton {
                        text:"Snap to guides";glyph:"grid_4x4"
                        compact:root.toolbarOnHorizontalEdge
                        description:"Snap module movement to alignment guides"
                        checkable:true;checked:root.snapEnabled
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        onToggled:root.snapEnabled=checked
                    }
                }

                GridLayout {
                    visible:!root.editingPopups
                    Layout.fillWidth:true
                    columns:root.toolbarOnHorizontalEdge ? 3 : 1
                    rowSpacing:6
                    columnSpacing:6

                    AbyssLabel { text:"Edge width" }
                    AbyssSlider {
                        unit:"px";from:0;to:40;stepSize:1
                        Layout.fillWidth:true
                        value:Placement.edgeThickness(
                            root.draftOptions,root.editingEdge)
                        onMoved:root.edgeThicknesses=Object.assign(
                            {},root.edgeThicknesses,
                            {[root.editingEdge]:value})
                    }
                    AbyssButton {
                        text:"Inherit surface";glyph:"layers"
                        description:"Inherit the physical surface thickness"
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        enabled:(root.edgeThicknesses[root.editingEdge] ?? -1)>=0
                        onClicked:root.edgeThicknesses=Object.assign(
                            {},root.edgeThicknesses,
                            {[root.editingEdge]:-1})
                    }
                }

                AbyssButton {
                    visible:!root.editingPopups;Layout.fillWidth:true
                    text:"Width affects modules";glyph:"width"
                    description:"Scale inherited modules with this Edge (0px hides them), or change only the bare Edge and retain local module bulges. Custom module sizes stay independent."
                    checkable:true;checked:root.edgeWidthAffectsModules[root.editingEdge]!==false
                    onToggled:root.edgeWidthAffectsModules=Object.assign({},root.edgeWidthAffectsModules,{[root.editingEdge]:checked})
                }

                AbyssCheckBox {
                    objectName:"abyssJoinNearbyModules"
                    visible:!root.editingPopups && root.edgeWidthAffectsModules[root.editingEdge]===false
                    text:"Join nearby modules"
                    checked:root.edgeJoinModules[root.editingEdge]===true
                    Layout.fillWidth:true
                    onToggled:root.edgeJoinModules=Object.assign({},root.edgeJoinModules,{[root.editingEdge]:checked})
                    StyledToolTip {text:"Connect neighboring module surfaces on this Edge. Distant groups keep their own bulges; module sizes stay unchanged."}
                }

                GridLayout {
                    visible:!root.editingPopups
                    Layout.fillWidth:true
                    columns:root.toolbarOnHorizontalEdge ? 3 : 1
                    rowSpacing:6
                    columnSpacing:6

                    AbyssLabel { text:"Overall size" }
                    AbyssSlider {
                        from:.6;to:1.8;value:root.moduleScale
                        Layout.fillWidth:true
                        onMoved:root.moduleScale=value
                    }
                    AbyssButton {
                        text:"Expand whole Edge";glyph:"fit_screen"
                        compact:root.toolbarOnHorizontalEdge
                        description:"Expand a single module across the whole Edge; turn off to expand only its local surface."
                        checkable:true
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        enabled:root.draft.filter(
                            p=>p.enabled && p.edge===root.editingEdge).length===1
                        checked:root.singleModuleExpansion[root.editingEdge]!=="local"
                        onToggled:root.singleModuleExpansion=Object.assign(
                            {},root.singleModuleExpansion,
                            {[root.editingEdge]:checked ? "edge" : "local"})
                    }
                }

                Rectangle {
                    Layout.fillWidth:true;height:1
                    visible:!root.toolbarOnHorizontalEdge && !root.editingPopups
                    color:Qt.alpha(AbyssStyle.accent,.12)
                }

                GridLayout {
                    visible:!root.editingPopups
                    Layout.fillWidth:true
                    columns:root.toolbarOnHorizontalEdge ? 7 : 1
                    rowSpacing:6
                    columnSpacing:6

                    StyledComboBox {
                        id:selection
                        model:root.draft.map(p => ({
                            label:Placement.label(p.kind)
                                +(p.enabled ? "" : " (disabled)"),
                            id:p.id}))
                        textRole:"label";valueRole:"id"
                        currentIndex:root.draft.findIndex(
                            p => p.id===root.selectedId)
                        displayText:root.selected
                            ? Placement.label(root.selected.kind)
                            : "Select a module"
                        onActivated:root.selectedId=currentValue
                        Layout.preferredWidth:root.toolbarOnHorizontalEdge ? 190 : -1
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                    }
                    AbyssButton {
                        text:root.selected?.enabled === false
                            ? "Enable" : "Disable"
                        glyph:root.selected?.enabled === false
                            ? "visibility" : "visibility_off"
                        compact:root.toolbarOnHorizontalEdge
                        description:text
                        enabled:root.selected !== undefined
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        onClicked:root.change("enabled",!root.selected.enabled)
                    }
                    AbyssButton {
                        text:"Remove";glyph:"delete"
                        compact:root.toolbarOnHorizontalEdge
                        description:"Remove selected module"
                        enabled:root.selected !== undefined
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        onClicked:{
                            root.draft=root.draft.filter(
                                p => p.id!==root.selectedId)
                            root.selectedId=""
                            root.refreshHandles()
                        }
                    }
                    StyledComboBox {
                        id:alignmentChoice
                        model:[
                            {label:"Free position",value:"free"},
                            {label:"Align start",value:"start"},
                            {label:"Align center",value:"center"},
                            {label:"Align end",value:"end"}]
                        textRole:"label";valueRole:"value"
                        currentIndex:Math.max(0,model.findIndex(
                            p => p.value===root.selected?.alignment))
                        enabled:root.selected !== undefined
                        onActivated:root.change("alignment",currentValue)
                        Layout.preferredWidth:root.toolbarOnHorizontalEdge ? 146 : -1
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                    }
                    AbyssCheckBox {
                        text:"Custom size"
                        checked:root.selected?.customSize ?? false
                        enabled:root.selected !== undefined
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        onToggled:{
                            if(checked) root.change(
                                "size",Placement.edgeSize(
                                    root.draftOptions,root.selected.edge))
                            root.change("customSize",checked)
                        }
                    }
                    AbyssCheckBox {
                        text:root.nearbyCorner
                            ? "Join "+root.nearbyCorner+" Edge"
                            : "Join nearby corner"
                        checked:root.selected?.joinCorner ?? false
                        enabled:root.selected !== undefined
                            && (!!root.nearbyCorner || checked)
                        Layout.fillWidth:!root.toolbarOnHorizontalEdge
                        onToggled:root.change("joinCorner",checked)
                        StyledToolTip {
                            text:root.nearbyCorner
                                ? "Fuse this module's nearby popup with both Screen Edges, preserving its content layout."
                                : "Move the module within 160 px of a corner to join the adjacent Screen Edge."
                        }
                    }
                    AbyssSlider {
                        from:.6;to:1.8
                        value:root.selected?.customSize
                            ? root.selected.size
                            : Placement.edgeSize(
                                root.draftOptions,
                                root.selected?.edge ?? root.editingEdge)
                        enabled:root.selected?.customSize ?? false
                        Layout.fillWidth:true
                        onMoved:root.change("size",value)
                    }
                }

                AbyssLabel {
                    text:root.toolbarOnHorizontalEdge
                        ? (root.editingPopups
                            ? "Drag preview · Enter save · Esc cancel"
                            : "Drag to move/reorder · Shift free · Enter save · Esc cancel")
                        : (root.editingPopups
                            ? "Drag · Enter save · Esc cancel"
                            : "Drag · Shift free · Enter save · Esc cancel")
                    color: Appearance.m3colors.darkmode
                        ? AbyssStyle.textColorMuted : "#1a1a1a"
                    Layout.fillWidth:true
                    wrapMode:Text.WordWrap
                }
            }
        }
    }
}
