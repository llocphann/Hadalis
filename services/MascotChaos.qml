pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell

// Compatibility bus for background widgets that still carry the former mascot
// impact hooks. The mascot runtime is retired, so this service intentionally
// never enables chaos and performs no state mutation.
Singleton {
    id: root

    readonly property bool enabled: false
    readonly property bool allowRearrange: false
    property var geometry: ({})
    property var originals: ({})

    signal impact(string widgetKey, real vx, real vy, string mode)
    signal panelShake(real intensity)
    signal tidied()

    function report(key: string, x: real, y: real, w: real, h: real): void {}
    function unreport(key: string): void {}
    function rememberOriginal(key: string, x: real, y: real): void {}
    function targets(): var { return [] }
    function tidy(): void { root.tidied() }
}
