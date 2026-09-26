pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.abyss.looks

ColumnLayout {
    id: root
    property int monthOffset: 0
    readonly property var month: new Date(DateTime.clock.date.getFullYear(),DateTime.clock.date.getMonth()+monthOffset,1)
    spacing: 8
    RowLayout {
        AbyssButton { glyph: "chevron_left"; description: "Previous month"; onClicked: root.monthOffset-- }
        AbyssLabel { text: Qt.formatDate(root.month,"MMMM yyyy"); Layout.fillWidth: true }
        AbyssButton { glyph: "chevron_right"; description: "Next month"; onClicked: root.monthOffset++ }
    }
    GridLayout {
        columns: 7; columnSpacing: 2; rowSpacing: 2
        Layout.fillWidth: true
        Repeater {
            model: 42
            AbyssLabel {
                required property int index
                readonly property var date: new Date(root.month.getFullYear(),root.month.getMonth(),index-root.month.getDay()+1)
                text: String(date.getDate())
                color: date.getMonth() === root.month.getMonth() ? AbyssStyle.textColor : AbyssStyle.textColorMuted
                font.bold: date.toDateString() === DateTime.clock.date.toDateString()
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: 28
            }
        }
    }
}
