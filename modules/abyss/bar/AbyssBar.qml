pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.abyss.looks
import "../looks/AbyssGeometry.js" as Geometry
import "../looks/AbyssLayout.js" as Layout

// Foreground modules embedded in the reservoir; this Item never paints a bar.
Item {
    id: root
    required property string outputName
    required property string edge
    property var draftPlacements: null
    property var draftOptions: null
    property bool editing: false
    property var liquidController: null
    property var measuredExtents: ({})
    readonly property var layoutOptions: Object.assign({},draftOptions ?? Layout.optionsForOutput(Config.options?.abyss?.modules,outputName),{extents:measuredExtents,editing:editing,edgeThickness:AbyssStyle.perimeterThickness})
    function measure(id, span): void {
        if (!Number.isFinite(span) || Math.abs((measuredExtents[id] ?? -1)-span)<.5) return
        measuredExtents = Object.assign({},measuredExtents,{[id]:span})
    }
    readonly property bool vertical: edge === "left" || edge === "right"
    signal popupRequested(string kind, string edge, real along)
    signal interaction(string edge, real along, real span, real strength)
    readonly property var zones: Geometry.barZones(
        (root.vertical ? Config.options?.bar?.verticalLayout : Config.options?.bar?.layout) ?? {},
        root.vertical, Config.options?.bar?.modules ?? {})
    readonly property var placements: draftPlacements ?? Layout.resolve(Config.options?.abyss?.modules,outputName,
        Layout.seed(zones,edge,width,height))
    readonly property var layoutRecords: Layout.geometry(placements,width,height,layoutOptions,Appearance.fontSizeScale)
    property var inputRegions: []
    property int revision: 0
    // Resting Screen Edge is flat. Interaction bulges come only from the opt-in solver.
    readonly property var deformations: []

    property var moduleIds: []
    function syncModuleIds(): void {
        const next=placements.filter(p=>p.enabled).map(p=>p.id)
        if (JSON.stringify(next)!==JSON.stringify(moduleIds)) moduleIds=next
    }
    function itemForId(id): var { return modules.itemAt(moduleIds.indexOf(id)) }
    onPlacementsChanged: syncModuleIds()
    Component.onCompleted: syncModuleIds()
    Repeater {
        id: modules
        model: root.moduleIds
        onItemAdded: (index,item) => {
            root.inputRegions = root.inputRegions.concat([item.inputRegion])
            root.revision++
        }
        onItemRemoved: (index,item) => {
            root.inputRegions = root.inputRegions.filter(region => region !== item.inputRegion)
            root.revision++
        }
        AbyssBarModule {
            id: module
            required property string modelData
            required property int index
            readonly property var placement: root.placements.find(p=>p.id===modelData)
            readonly property Region inputRegion: Region { item: module }
            readonly property var geometry: root.layoutRecords.find(rec => rec.id === modelData)
            liquidController: root.liquidController
            attachedEdge: placement?.edge ?? "top"
            popupJoinedEdge: placement?.joinCorner ? Layout.adjacentEdge(geometry,root.width,root.height) : ""
            contentScale: (geometry?.span ?? 0)/Math.max(1,naturalSpan)
            onNaturalSpanChanged: root.measure(modelData,naturalSpan)
            Component.onCompleted: root.measure(modelData,naturalSpan)
            kind: placement?.kind ?? "clock"
            outputName: root.outputName
            vertical: placement?.edge === "left" || placement?.edge === "right"
            compact: placement?.compact ?? false
            enabled: !root.editing
            x: geometry?.content.x ?? 0; y: geometry?.content.y ?? 0
            width: geometry?.content.width ?? 0; height: geometry?.content.height ?? 0
            onInteraction: strength => { if (geometry) root.interaction(geometry.edge,geometry.along+geometry.span/2,geometry.span,strength*geometry.influence) }
            onRequest: kind => { if (geometry) root.popupRequested(kind,geometry.edge,geometry.along+geometry.span/2) }
        }
    }
}
