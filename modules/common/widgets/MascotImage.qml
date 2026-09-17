import QtQuick

// Compatibility boundary for shell surfaces that can optionally host mascot art.
// The mascot asset/runtime pack is not part of the required runtime payload, so
// missing mascot support must degrade to each consumer's existing icon/content
// fallback rather than making the local QML module fail to resolve.
Image {
    id: root

    property string pose: ""
    property string surface: ""
    property string fallbackSurface: ""

    // Consumers already gate their fallback UI on this property. Keep the
    // optional feature fail-closed until a mascot provider explicitly owns it.
    readonly property bool active: false

    visible: false
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    cache: true
}
