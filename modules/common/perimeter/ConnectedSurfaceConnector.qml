import QtQuick

Rectangle {
    id: root
    required property var geometry
    property color fillColor: "white"
    property color strokeColor: "transparent"
    property real strokeWidth: geometry.borderWidth ?? 0

    x: geometry.connectorRect.x
    y: geometry.connectorRect.y
    width: geometry.connectorRect.width
    height: geometry.connectorRect.height
    radius: Math.min(geometry.neckRadius, width / 2, height / 2)
    color: fillColor
    border.color: strokeColor
    border.width: strokeWidth
    visible: geometry.valid && geometry.progress > 0 && width > 0 && height > 0
    opacity: geometry.progress
}
