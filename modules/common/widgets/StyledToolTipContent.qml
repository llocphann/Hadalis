import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property string text
    readonly property bool abyss:Config.options?.panelFamily === "abyss"
    property bool shown: false
    property string position: "bottom" // "bottom", "top", "left", "right"
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipTextObject.font
    implicitWidth: tooltipTextObject.implicitWidth + 2 * root.horizontalPadding
    implicitHeight: tooltipTextObject.implicitHeight + 2 * root.verticalPadding

    property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle
        objectName:"styledToolTipSurface"
        // Grow from the edge nearest to the anchor
        x: root.position === "left" ? root.implicitWidth - implicitWidth
         : root.position === "right" ? 0
         : (root.implicitWidth - implicitWidth) / 2
        y: root.position === "top" ? root.implicitHeight - implicitHeight
         : root.position === "bottom" ? 0
         : (root.implicitHeight - implicitHeight) / 2
        color: root.abyss ? AbyssStyle.surface : Appearance.colors.colLayer3
        radius: root.abyss ? Math.min(18,implicitHeight/2) : Appearance.rounding.verysmall
        border.width: 1
        border.color: root.abyss ? Qt.alpha(AbyssStyle.accent,.28) : Appearance.colors.colLayer3Hover
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        transformOrigin: root.position === "top" ? Item.Bottom
                       : root.position === "left" ? Item.Right
                       : root.position === "right" ? Item.Left
                       : Item.Top
        implicitWidth: shown ? (tooltipTextObject.implicitWidth + 2 * root.horizontalPadding) : 0
        implicitHeight: shown ? (tooltipTextObject.implicitHeight + 2 * root.verticalPadding) : 0
        clip: true

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        StyledText {
            id: tooltipTextObject
            anchors.centerIn: parent
            text: root.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.hintingPreference: Font.PreferNoHinting // Prevent shaky text
            color: root.abyss ? (Appearance.m3colors.darkmode ? AbyssStyle.textColor : "#000000") : Appearance.colors.colOnLayer3
            wrapMode: Text.Wrap
        }
    }   
}
