pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.abyss.looks
import "../looks/AbyssGeometry.js" as Geometry

Item {
    id: root
    required property string outputName
    required property string edge
    readonly property bool vertical: edge === "left" || edge === "right"
    signal popupRequested(string kind, real along)
    readonly property var zones: Geometry.barZones(
        (root.vertical ? Config.options?.bar?.verticalLayout : Config.options?.bar?.layout) ?? {},
        root.vertical, Config.options?.bar?.modules ?? {})
    readonly property var deformations: root.zones.map((ids,index) => ({
        edge:root.edge, along:(root.vertical?root.height:root.width)*index/5,
        span:(root.vertical?root.height:root.width)/5, depth:ids.length > 0 ? 5 : 0
    }))
    Repeater {
        model: root.zones
        Item {
            id: zone
            required property var modelData
            required property int index
            x: root.vertical ? 0 : root.width*index/5
            y: root.vertical ? root.height*index/5 : 0
            width: root.vertical ? root.width : root.width/5
            height: root.vertical ? root.height/5 : root.height
            clip: true
            Repeater {
                model: zone.modelData
                AbyssBarModule {
                    required property string modelData
                    required property int index
                    kind: modelData
                    outputName: root.outputName
                    vertical: root.vertical
                    x: root.vertical ? 0 : index*width
                    y: root.vertical ? index*height : 0
                    width: root.vertical ? zone.width : zone.width/Math.max(1,zone.modelData.length)
                    height: root.vertical ? zone.height/Math.max(1,zone.modelData.length) : zone.height
                    onRequest: kind => {
                        const point = mapToItem(root,width/2,height/2)
                        root.popupRequested(kind,root.vertical ? point.y : point.x)
                    }
                }
            }
        }
    }
}
