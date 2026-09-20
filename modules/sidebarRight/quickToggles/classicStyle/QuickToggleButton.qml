import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    property string accessibleName: ""
    Accessible.name: button.accessibleName.length > 0
        ? button.accessibleName
        : button.buttonIcon.replace(/_/g, " ")
    Accessible.checkable: true
    Accessible.checked: button.toggled
    baseWidth: 40
    baseHeight: 40
    clickedWidth: baseWidth + 20
    toggled: false
    buttonRadius: (altAction && toggled)
        ? Appearance.rounding.normal : Math.min(baseHeight, baseWidth) / 2
    buttonRadiusPressed: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colBackgroundToggled: Appearance.colors.colPrimary
    colBackgroundToggledHover: Appearance.colors.colPrimaryHover

    contentItem: Item {
        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 20
            fill: button.toggled ? 1 : 0
            animateFill: true
            color: button.toggled
                ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.buttonIcon

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
