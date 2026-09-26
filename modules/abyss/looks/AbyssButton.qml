import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

AbstractButton {
    id: root
    property string glyph: ""
    property bool compact: false
    property string description: text
    hoverEnabled: true
    implicitHeight: 36
    implicitWidth: Math.max(28, contentItem.implicitWidth + 12)
    Accessible.name: description
    Accessible.role: Accessible.Button
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    leftPadding: 6
    rightPadding: 6
    background: null
    opacity: enabled ? (down ? 0.70 : 1) : 0.4
    contentItem: RowLayout {
        spacing: 6
        MaterialSymbol {
            visible: root.glyph.length > 0
            text: root.glyph
            iconSize: 20
            color: root.hovered || root.checked ? AbyssStyle.accent : AbyssStyle.textColor
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            visible: !root.compact && root.text.length > 0
            text: root.text
            color: root.hovered || root.checked ? AbyssStyle.accent : AbyssStyle.textColor
            font: root.font
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
    ToolTip.visible: hovered && description.length > 0 && (compact || text.length === 0)
    ToolTip.text: description
    ToolTip.delay: 700
}
