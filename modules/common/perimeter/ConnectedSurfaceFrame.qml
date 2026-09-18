import QtQuick

Item {
    id: root

    required property var geometry
    property color fillColor: "white"
    property color borderColor: "transparent"
    property real borderWidth: geometry.borderWidth ?? 0
    property real connectorBorderWidth: 0
    property bool connectorVisible: true
    property bool shadowEnabled: false
    property real shadowExtent: 0
    property color shadowColor: "transparent"
    property bool shadowTop: true
    property bool shadowBottom: true
    property bool shadowLeft: true
    property bool shadowRight: true
    // A directly joined edge is part of the same visual surface. Square only
    // the body corners touching that edge so no rounded-card notch appears at
    // the Screen Edge seam; callers that do not opt in keep normal rounding.
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false

    readonly property Item bodyItem: body
    readonly property Item connectorItem: connector
    readonly property Item blurItem: blurBounds
    readonly property rect visualBounds: geometry.visualBounds
    readonly property rect blurRect: geometry.blurRect

    visible: geometry.valid && geometry.progress > 0

    // Expanded rectangular blur proxy. It never participates in the input mask.
    Item {
        id: blurBounds
        x: root.geometry.blurRect.x
        y: root.geometry.blurRect.y
        width: root.geometry.blurRect.width
        height: root.geometry.blurRect.height
    }

    Rectangle {
        id: body
        x: root.geometry.animatedBodyRect.x
        y: root.geometry.animatedBodyRect.y
        width: root.geometry.animatedBodyRect.width
        height: root.geometry.animatedBodyRect.height
        readonly property real surfaceRadius: Math.min(
            root.geometry.outerRadius, width / 2, height / 2)
        radius: surfaceRadius
        topLeftRadius: (root.joinTop || root.joinLeft) ? 0 : surfaceRadius
        topRightRadius: (root.joinTop || root.joinRight) ? 0 : surfaceRadius
        bottomLeftRadius: (root.joinBottom || root.joinLeft) ? 0 : surfaceRadius
        bottomRightRadius: (root.joinBottom || root.joinRight) ? 0 : surfaceRadius
        color: root.fillColor
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: root.visible && width > 0 && height > 0
    }

    // Caelestia-style direct-edge surfaces have no separate neck shadow. Draw
    // the same one-sided gradient used by Screen Edge only on the popup's free
    // sides, leaving attached Bar/Screen-Edge seams shadow-free.
    Rectangle {
        z: -1
        visible: root.shadowEnabled && root.shadowTop
            && root.shadowExtent > 0 && body.visible
        x: body.x
        y: body.y - root.shadowExtent
        width: body.width
        height: root.shadowExtent
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.shadowColor }
        }
    }
    Rectangle {
        z: -1
        visible: root.shadowEnabled && root.shadowBottom
            && root.shadowExtent > 0 && body.visible
        x: body.x
        y: body.y + body.height
        width: body.width
        height: root.shadowExtent
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: root.shadowColor }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        z: -1
        visible: root.shadowEnabled && root.shadowLeft
            && root.shadowExtent > 0 && body.visible
        x: body.x - root.shadowExtent
        y: body.y
        width: root.shadowExtent
        height: body.height
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.shadowColor }
        }
    }
    Rectangle {
        z: -1
        visible: root.shadowEnabled && root.shadowRight
            && root.shadowExtent > 0 && body.visible
        x: body.x + body.width
        y: body.y
        width: root.shadowExtent
        height: body.height
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.shadowColor }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // Render after the body so the flared connector erases the body outline at
    // the attachment edge. The connector itself stays unoutlined by default so
    // the bar, shoulder and body read as one continuous surface.
    ConnectedSurfaceConnector {
        id: connector
        geometry: root.geometry
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.connectorBorderWidth
        connectorEnabled: root.connectorVisible
    }
}
