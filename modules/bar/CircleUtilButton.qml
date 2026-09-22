import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

RippleButton {
    id: button

    required default property Item content

    implicitHeight: Math.max(content.implicitHeight, 26 * Appearance.sizes.barModuleScale)
    implicitWidth: implicitHeight
    // Square and standalone, so the face stays organic in cookie mode.
    cookieMorphing: true
    contentItem: content
    buttonRadius: Appearance.rounding.full
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active

}
