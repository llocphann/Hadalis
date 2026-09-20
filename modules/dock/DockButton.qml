import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property bool vertical: false
    property string dockPosition: "bottom"
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    // Keep the default 50px Panel control, but shrink when a thin Dock cannot
    // contain it and grow only when a larger requested icon needs the room.
    // This makes the full Settings range (height 40..100, icon 20..60) safe.
    readonly property real dockThickness:
        Math.max(40, Number(Config.options?.dock?.height ?? 60))
    readonly property real requestedIconSize:
        Math.max(20, Number(Config.options?.dock?.iconSize ?? 35))
    readonly property real controlSize: Math.max(30, Math.min(
        dockThickness - 10, Math.max(50, requestedIconSize + 10)))

    implicitWidth: controlSize
    implicitHeight: controlSize
    // Panel is the only supported ii Dock renderer. Keep one Material button
    // face instead of dispatching through retired global-style branches.
    cookieMorphing: true
    buttonRadius: Appearance.rounding.normal
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer0Hover
    colRipple: Appearance.colors.colLayer0Active

    background.implicitHeight: controlSize
    background.implicitWidth: controlSize
}
