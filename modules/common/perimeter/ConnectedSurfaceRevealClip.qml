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

    readonly property rect revealRect: root.geometry?.revealClipRect
        ?? Qt.rect(0, 0, 0, 0)

    x: revealRect.x
    y: revealRect.y
    width: revealRect.width
    height: revealRect.height
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
