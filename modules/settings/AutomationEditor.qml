import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ScrollView {
    id: root
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias readOnly: field.readOnly
    property alias enableSettingsSearch: field.enableSettingsSearch
    implicitHeight: 210
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AlwaysOn

    MaterialTextArea {
        id: field
        objectName: "automationEditorText"
        width: root.availableWidth
        height: Math.max(implicitHeight, root.availableHeight)
        wrapMode: TextEdit.Wrap
        color: Appearance.colors.colOnSurface
        selectByMouse: true
        topPadding: 12
        bottomPadding: 12
        leftPadding: 14
        rightPadding: 14
    }
}
