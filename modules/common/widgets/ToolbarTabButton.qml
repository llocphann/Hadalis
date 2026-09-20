import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls

RippleButton {
    id: root
    required property string materialSymbol
    required property bool current
    Accessible.checkable: true
    Accessible.checked: root.current
    property bool showLabel: true
    horizontalPadding: 10

    implicitHeight: 40
    readonly property real _iconOnlyImplicitWidth: icon.implicitWidth + horizontalPadding * 2
    implicitWidth: root.showLabel
        ? implicitContentWidth + horizontalPadding * 2 : root._iconOnlyImplicitWidth
    buttonRadius: height / 2

    colBackground: "transparent"
    colBackgroundHover: current ? "transparent"
        : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)
    colRipple: current ? "transparent"
        : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.showLabel ? 6 : 0

        Behavior on spacing {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
            color: Appearance.colors.colOnSurface
        }

        Item {
            id: labelReveal
            anchors.verticalCenter: parent.verticalCenter
            width: root.showLabel ? labelText.implicitWidth : 0
            implicitWidth: width
            implicitHeight: labelText.implicitHeight
            opacity: root.showLabel ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            StyledText {
                id: labelText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                font.family: Appearance.font.family.main
                font.weight: Font.Normal
                color: Appearance.colors.colOnSurface
            }
        }
    }
}
