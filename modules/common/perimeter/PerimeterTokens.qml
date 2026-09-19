pragma Singleton
import QtQuick
import qs.modules.common

QtObject {
    readonly property real outerRadius: 22
    readonly property real neckRadius: 14

    // BAR-SCREEN-EDGE-CORNER-LOCK: this is the only user-adjustable
    // corner parameter for the physical Screen Edge + normal ii Bar perimeter.
    // The default remains Caelestia border.rounding=25. Do not create a second
    // Bar endpoint radius or orientation-specific corner token.
    readonly property real frameRadius: {
        const revision = Config.revision
        return Math.max(0, Math.min(96,
            Number(Config.options?.appearance?.screenEdge?.radius ?? 25)))
    }

    // CONNECTED-SURFACE-OUTWARD-FLARE-LOCK:
    // Joined popup/sidebar/dashboard body corners stay SQUARE. Contact rounding
    // is drawn only by the outward concave shoulder outside the body, never by
    // rounding the body inward. Caelestia's BlobGroup uses a circular smooth-min
    // (default smoothing 20) independently of border rounding (default 25).
    // Hadalis has no cross-window SDF field, so the local reconstructed contact
    // uses the shared user-controlled frame radius as k instead of introducing a
    // second visual tuning knob. Changing Border Radius therefore changes both
    // physical endpoint curvature and the connected-surface contact silhouette.
    readonly property real smoothUnionRadius: 20
    readonly property real popupRadius: 28
    readonly property real joinFlareRadius: frameRadius

    readonly property real revealSlideDistance: 18
    readonly property real connectorWidth: 40
    readonly property real connectorLength: 8
    readonly property real seamOverlap: 2
    readonly property real borderWidth: 1
    readonly property real blurExpansion: 24
    readonly property real screenMargin: 4
}
