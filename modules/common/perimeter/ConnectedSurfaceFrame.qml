import QtQuick
import QtQuick.Effects

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
    // A directly joined edge remains a rounded panel edge, matching Caelestia's
    // PanelBg/BlobGroup composition. Corners that touch Screen Edge/Bar inherit
    // the physical frame radius instead of being squared; free corners keep the
    // normal popup radius. Join flares remain a separate smooth-union shoulder.
    property bool joinTop: false
    property bool joinBottom: false
    property bool joinLeft: false
    property bool joinRight: false
    property real attachedCornerRadius: PerimeterTokens.attachedCornerRadius
    property real joinFlareRadius: PerimeterTokens.joinFlareRadius
    property bool hoverEnabled: false
    readonly property bool bodyHovered: bodyHover.hovered

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
        z: 1
        x: root.geometry.animatedBodyRect.x
        y: root.geometry.animatedBodyRect.y
        width: root.geometry.animatedBodyRect.width
        height: root.geometry.animatedBodyRect.height
        readonly property real surfaceRadius: Math.min(
            root.geometry.outerRadius, width / 2, height / 2)
        readonly property real attachedRadius: Math.max(0, Math.min(
            root.attachedCornerRadius, width / 2, height / 2))
        radius: surfaceRadius
        topLeftRadius: (root.joinTop || root.joinLeft)
            ? attachedRadius : surfaceRadius
        topRightRadius: (root.joinTop || root.joinRight)
            ? attachedRadius : surfaceRadius
        bottomLeftRadius: (root.joinBottom || root.joinLeft)
            ? attachedRadius : surfaceRadius
        bottomRightRadius: (root.joinBottom || root.joinRight)
            ? attachedRadius : surfaceRadius
        color: root.fillColor
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: root.visible && width > 0 && height > 0

        HoverHandler {
            id: bodyHover
            enabled: root.hoverEnabled && body.visible
        }
    }

    // Use the same radius-aware RectangularShadow renderer that the shell's
    // stable surface primitives use. Attached sides hard-clip the shadow while
    // every free side keeps the configured Screen Edge/Bar falloff.
    Item {
        id: shadowClip
        z: 0
        visible: root.shadowEnabled && root.shadowExtent > 0 && body.visible
            && (root.shadowTop || root.shadowBottom
                || root.shadowLeft || root.shadowRight)
        x: body.x - (root.shadowLeft ? root.shadowExtent + 2 : 0)
        y: body.y - (root.shadowTop ? root.shadowExtent + 2 : 0)
        width: body.width
            + (root.shadowLeft ? root.shadowExtent + 2 : 0)
            + (root.shadowRight ? root.shadowExtent + 2 : 0)
        height: body.height
            + (root.shadowTop ? root.shadowExtent + 2 : 0)
            + (root.shadowBottom ? root.shadowExtent + 2 : 0)
        clip: true

        RectangularShadow {
            x: body.x - shadowClip.x
            y: body.y - shadowClip.y
            width: body.width
            height: body.height
            radius: body.surfaceRadius + root.shadowExtent * 0.75
            blur: root.shadowExtent
            spread: 0
            offset: Qt.vector2d(0, 0)
            color: root.shadowColor
            // Connected bodies translate every frame and can reverse mid-slide.
            // Keep the shadow live so cached FBO state cannot blink or lag.
            cached: false
        }
    }

    // Caelestia-style smooth-union shoulders at the endpoints of every directly
    // attached edge. The body already carries the shared rounded contact corner;
    // these flares only approximate BlobGroup smoothing between that rounded
    // panel and the owning Bar/Screen Edge, never replace the corner itself.
    ConnectedSurfaceJoinFlares {
        z: 2
        anchors.fill: parent
        bodyItem: body
        fillColor: root.fillColor
        flareRadius: root.joinFlareRadius
        progress: root.geometry.revealProgress ?? root.geometry.progress ?? 1
        joinTop: root.joinTop
        joinBottom: root.joinBottom
        joinLeft: root.joinLeft
        joinRight: root.joinRight
    }

    // Retained only for consumers that explicitly need legacy connector
    // geometry. StyledPopup keeps connectorVisible=false, so ordinary Bar
    // popups are direct-body surfaces plus the concave shoulders above.
    ConnectedSurfaceConnector {
        id: connector
        geometry: root.geometry
        fillColor: root.fillColor
        strokeColor: root.borderColor
        strokeWidth: root.connectorBorderWidth
        connectorEnabled: root.connectorVisible
    }
}
