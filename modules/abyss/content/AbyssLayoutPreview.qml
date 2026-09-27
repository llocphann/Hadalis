import QtQuick
import "../looks/AbyssPresentation.js" as Presentation

// Reuse the actual popup/indicator layouts but disable their controls while
// positioning. Editing a Volume preview must never change the live sink.
Item {
    id:root
    property string kind:"volume"
    property string outputName:""
    property var participant:null
    enabled:false
    readonly property real desiredWidth: feature.item?.desiredWidth ?? 390
    readonly property real desiredHeight: feature.item?.desiredHeight ?? 120
    Loader {
        id:feature;anchors.fill:parent
        sourceComponent:Presentation.osds.includes(root.kind) ? indicator : popup
    }
    Component { id:indicator;AbyssOsdContent { indicatorKind:root.kind;outputName:root.outputName } }
    Component { id:popup;AbyssPopupContent { kind:root.kind;outputName:root.outputName;participant:root.participant } }
}
