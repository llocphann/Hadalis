import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitHeight: clockColumn.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: DateTime.timeDisplay.split(/[: ]/)
            delegate: StyledText {
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: modelData.match(/am|pm/i) ? 
                    Appearance.font.pixelSize.smaller // Smaller "am"/"pm" text
                    : Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                text: modelData.padStart(2, "0")
            }
        }
    }

}
