import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

DialogButton {
    id: root
    property string iconName: ""
    property string hint: buttonText
    implicitWidth: Math.max(76, contents.implicitWidth + padding * 2)
    implicitHeight: 36
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    ToolTip.delay: 500

    contentItem: Item {
        Row {
            id: contents
            objectName: "automationButtonContents"
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                visible: root.iconName.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.iconName
                iconSize: 18
                color: root.enabled ? root.colEnabled : root.colDisabled
            }
            StyledText {
                text: root.buttonText
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.enabled ? root.colEnabled : root.colDisabled
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
