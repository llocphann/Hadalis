import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 8
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false)
        && (Config.options?.sidebar?.cardStyle ?? false)
        && (Config.options?.bar?.cornerStyle === 3)
    property bool bare: false
    property bool clipContent: false
    readonly property bool zzzPlate: false
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth
        : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2)
        : Appearance.sizes.baseBarHeight
    readonly property real contentWidth: gridLayout.implicitWidth + padding * 2
    readonly property bool empty: gridLayout.implicitWidth < 1
    default property alias items: gridLayout.children

    PanelSurface {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        visible: !root.bare
        cardStyle: root.cardStyleEverywhere
        borderless: Config.options?.bar?.borderless ?? false
        radiusOverride: -1
        elevation: 1
        zzzChamfer: false
    }

    Item {
        anchors.fill: parent
        clip: root.clipContent

        GridLayout {
            id: gridLayout
            columns: root.vertical ? 1 : -1
            anchors {
                verticalCenter: root.vertical ? undefined : parent.verticalCenter
                horizontalCenter: parent.horizontalCenter
                top: root.vertical ? parent.top : undefined
                bottom: root.vertical ? parent.bottom : undefined
                margins: root.padding
            }
            columnSpacing: 4
            rowSpacing: 12
        }
    }
}
