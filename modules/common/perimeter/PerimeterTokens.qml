pragma Singleton
import QtQuick
import qs.modules.common

QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14

    // Physical Screen Edge / Bar perimeter radius. The default remains
    // Caelestia border.rounding=25 and Settings may change only this shared
    // perimeter value.
    readonly property real frameRadius: {
        const revision = Config.revision
        return Math.max(0, Math.min(96,
            Number(Config.options?.appearance?.screenEdge?.radius ?? 25)))
    }

    // Connected popup/sidebar/dashboard shoulders are intentionally back on
    // their pre-experiment contract for now. Do not couple these to frameRadius
    // until the connected-surface geometry is revisited explicitly.
    readonly property real smoothUnionRadius: 20
    readonly property real popupRadius: 28
    readonly property real joinFlareRadius: smoothUnionRadius
    readonly property real joinFlareCrossScale: 0.55

    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
