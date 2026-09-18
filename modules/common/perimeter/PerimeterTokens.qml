pragma Singleton
import QtQuick
QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14
    // Concave shoulder used where a directly attached body meets Bar/Screen Edge.
    // This approximates Caelestia's smooth blob union without reviving a stem.
    readonly property real joinFlareRadius: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
