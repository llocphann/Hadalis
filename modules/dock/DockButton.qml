import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property bool vertical: false
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    // Shell-layout resize previews are authoritative while a gesture is active;
    // normal runtime falls back to the persisted Dock height. Keeping this input
    // on the shared button makes icons, separators and the Overview button resize
    // in the same frame as the iRiS body instead of snapping after commit.
    property real dockThicknessOverride: -1
    readonly property real dockThickness: Math.max(40, Number(
        root.dockThicknessOverride > 0
            ? root.dockThicknessOverride
            : (Config.options?.dock?.height ?? 60)))
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
