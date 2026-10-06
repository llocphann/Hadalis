import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

AbstractButton {
    id: root
    property string glyph: ""
    property bool compact: false
    property string description: text
    readonly property color baseInk: Appearance.m3colors.darkmode
        ? AbyssStyle.textColor : "#000000"
    readonly property color activeInk: Appearance.m3colors.darkmode
        ? AbyssStyle.accent
        : ColorUtils.ensureReadable(Appearance.colors.colPrimary,
            Appearance.colors.colLayer1Base, 4.5)
    hoverEnabled: true
    implicitHeight: 36
    implicitWidth: Math.max(36, contentItem.implicitWidth + 24)
    Accessible.name: description
    Accessible.role: Accessible.Button
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        radius: height/2
        color: Qt.alpha(AbyssStyle.accent,root.down ? .24 : root.checked ? .2 : root.hovered ? .12 : .05)
        border.width: 1
        border.color: Qt.alpha(AbyssStyle.accent,root.activeFocus ? .8 : root.hovered || root.checked ? .35 : .15)
        Behavior on color { enabled: AbyssStyle.motionEnabled; ColorAnimation { duration: AbyssStyle.motionFast } }
        Behavior on border.color { enabled: AbyssStyle.motionEnabled; ColorAnimation { duration: AbyssStyle.motionFast } }
    }
    opacity: enabled ? (down ? 0.70 : 1) : 0.4
    contentItem: RowLayout {
        spacing: 6
        MaterialSymbol {
            visible: root.glyph.length > 0
            text: root.glyph
            iconSize: 20
            color: root.hovered || root.checked ? root.activeInk : root.baseInk
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            visible: !root.compact && root.text.length > 0
            text: root.text
            color: root.hovered || root.checked ? root.activeInk : root.baseInk
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
