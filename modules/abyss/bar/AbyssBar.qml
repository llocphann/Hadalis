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
    property bool editing: false
    readonly property bool vertical: edge === "left" || edge === "right"
    signal popupRequested(string kind, string edge, real along)
    signal interaction(string edge, real along, real span, real strength)
    readonly property var zones: Geometry.barZones(
        (root.vertical ? Config.options?.bar?.verticalLayout : Config.options?.bar?.layout) ?? {},
        root.vertical, Config.options?.bar?.modules ?? {})
    readonly property var placements: draftPlacements ?? Layout.resolve(Config.options?.abyss?.modules,outputName,
        Layout.seed(zones,edge,width,height))
    readonly property var layoutRecords: Layout.geometry(placements,width,height,Config.options?.abyss?.modules,Appearance.fontSizeScale)
    property var inputRegions: []
    property int revision: 0
    readonly property var deformations: {
        const unused = revision
        return layoutRecords.map((rec,index) => {
            const module = modules.itemAt(index)
            return Geometry.panel(width,height,{left:8,top:8,right:8,bottom:8},rec.edge,rec.along-8,rec.span+16,
                rec.depth+(module?.hovered ? 4 : 0)+(module?.pressed ? 3 : 0),1,0)
        })
    }
    Repeater {
        id: modules
        model: root.layoutRecords
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
            required property var modelData
            required property int index
            readonly property Region inputRegion: Region { item: module }
            kind: modelData.kind
            outputName: root.outputName
            vertical: modelData.vertical
            compact: modelData.compact
            enabled: !root.editing
            x: modelData.content.x; y: modelData.content.y
            width: modelData.content.width; height: modelData.content.height
            onInteraction: strength => root.interaction(modelData.edge,modelData.along+modelData.span/2,modelData.span,strength*modelData.influence)
            onRequest: kind => root.popupRequested(kind,modelData.edge,modelData.along+modelData.span/2)
        }
    }
}
