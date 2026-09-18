pragma Singleton
import QtQuick
QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14
    // Concave shoulder used where a directly attached body meets Bar/Screen Edge.
    // This approximates Caelestia's smooth blob union without reviving a stem.
    readonly property real joinFlareRadius: outerRadius
    // Shared popup reveal is a short directional slide from the owning edge.
    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    // Straight and curved shadow primitives overlap by one logical pixel at
    // their tangent so antialiasing cannot expose a hairline break.
    readonly property real shadowSeamOverlap: 1
    readonly property real screenMargin: 4
}
