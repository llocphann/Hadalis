import QtQuick

ShaderEffect {
    id: root

    required property real leftInset
    required property real topInset
    required property real rightInset
    required property real bottomInset
    required property real radius
    required property color edgeColor
    required property color elevationColor
    required property real elevationSize
    required property bool elevationEnabled

    blending: true
    readonly property vector4d viewport:
        Qt.vector4d(width, height, 0, 0)
    readonly property vector4d insets:
        Qt.vector4d(leftInset, topInset, rightInset, bottomInset)
    readonly property color frameColor: edgeColor
    readonly property color shadowColor: elevationEnabled
        ? elevationColor : Qt.rgba(0, 0, 0, 0)
    readonly property vector4d params:
        Qt.vector4d(radius, elevationEnabled ? elevationSize : 0, 0.75, 0)

    fragmentShader: Qt.resolvedUrl("ScreenEdgeField.frag.qsb")
}
