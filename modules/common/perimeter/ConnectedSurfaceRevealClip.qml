import QtQuick

// Fixed reveal viewport for connected surfaces.
//
// Children continue to use full-output coordinates, but pixels translated into
// the owning Bar/Screen Edge side are clipped at the resting attachment seam.
// This creates a true slide-under reveal without scaling the popup body.
Item {
    id: root

    required property var geometry
    default property alias content: contentLayer.data
    property real contactOverlap: PerimeterTokens.seamOverlap

    readonly property rect revealRect: root.geometry?.revealClipRect
        ?? Qt.rect(0, 0, 0, 0)
    readonly property string edge: String(root.geometry?.edge ?? "")
    readonly property real overlap: Math.max(0, root.contactOverlap)

    // Expand only into the owning edge. The mathematical attachment boundary
    // stays unchanged while the renderer gets enough room for the shared seam
    // overlap strip.
    x: revealRect.x - (root.edge === "left" ? root.overlap : 0)
    y: revealRect.y - (root.edge === "top" ? root.overlap : 0)
    width: revealRect.width
        + ((root.edge === "left" || root.edge === "right") ? root.overlap : 0)
    height: revealRect.height
        + ((root.edge === "top" || root.edge === "bottom") ? root.overlap : 0)
    visible: root.geometry?.valid === true
        && Number(root.geometry?.progress ?? 0) > 0
    clip: true

    Item {
        id: contentLayer
        x: -root.x
        y: -root.y
        width: root.parent?.width ?? 0
        height: root.parent?.height ?? 0
    }
}
