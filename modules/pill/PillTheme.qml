pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Theme-only compatibility contract retained by the dock after the retired
// Pill runtime was removed. Keep this surface deliberately narrow: the dock
// still consumes these Ricelin tokens, but no Pill runtime components live in
// this module anymore.
Singleton {
    readonly property color cream: Appearance.colors.colOnLayer0
    readonly property color vermLit: Appearance.colors.colPrimary
    readonly property color frameBg: Qt.alpha(cream, 0.055)
}
