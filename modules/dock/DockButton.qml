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

    implicitWidth: vertical ? (implicitHeight - topInset - bottomInset) : (implicitHeight - topInset - bottomInset)
    implicitHeight: 50
    // Panel is the only supported ii Dock renderer. Keep one Material button
    // face instead of dispatching through retired global-style branches.
    cookieMorphing: true
    buttonRadius: Appearance.rounding.normal
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer0Hover
    colRipple: Appearance.colors.colLayer0Active

    background.implicitHeight: 50
    background.implicitWidth: 50
}
