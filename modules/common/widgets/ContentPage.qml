import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property bool embedded: false
    property real bottomContentPadding: embedded ? 0 : 48
    // Metadatos opcionales para páginas de Settings
    property int settingsPageIndex: -1
    property string settingsPageName: ""

    default property alias contentData: contentColumn.data

    clip: !embedded
    interactive: !embedded
    implicitHeight: embedded ? contentHeight + 1 : 0
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding
    implicitWidth: contentColumn.implicitWidth

    // Fill the available width up to a generous cap so normal-sized hosts
    // (overlay card, focus panel, settings window) don't leave dead side
    // margins; beyond the cap, center instead of stretching indefinitely.
    readonly property real maxContentWidth: Math.min(1200, Math.max(880, root.width - 64))
    readonly property real _horizontalMargin: {
        if (root.embedded) return 0
        const w = root.width
        if (w > maxContentWidth + 64) return (w - maxContentWidth) / 2
        if (w > 900) return 32
        if (w > 600) return 24
        return 16
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.embedded ? 0 : 16
            bottomMargin: 16
            leftMargin: root._horizontalMargin
            rightMargin: root._horizontalMargin
        }
        spacing: SettingsMaterialPreset.pageSpacing
    }
}
