import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool shown: true
    property string icon: ""
    property string text: ""
    property string explanation: ""
    property int shape: MaterialShape.Shape.Clover4Leaf
    property Action helpfulAction
    property real maximumWidth: 340
    property string actionIcon: ""
    property string actionText: helpfulAction?.text ?? ""
    property int textHorizontalAlignment: Text.AlignHCenter
    property bool compact: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    implicitWidth: placeholderColumn.implicitWidth
    implicitHeight: placeholderColumn.implicitHeight
    y: shown ? 0 : 10

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    ColumnLayout {
        id: placeholderColumn
        anchors.centerIn: parent
        width: Math.min(root.maximumWidth, parent ? parent.width - 24 : root.maximumWidth)
        spacing: root.compact ? 6 : 10

        Item {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: materialShape.implicitWidth
            implicitHeight: materialShape.implicitHeight

            MaterialShapeWrappedMaterialSymbol {
                id: materialShape
                anchors.centerIn: parent
                text: root.icon
                shape: root.shape
                padding: 12
                iconSize: 56
            }
        }

        StyledText {
            visible: root.text !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.text
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: root.compact ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurface
        }

        StyledText {
            visible: root.explanation !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.explanation
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.helpfulAction !== null
            mainText: root.actionText
            materialIcon: root.actionIcon
            onClicked: root.helpfulAction.trigger()
        }
    }
}
