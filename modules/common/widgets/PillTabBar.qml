pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Compact tab control shared by corner popups. Its moving primary pill follows
// the Dashboard To-do tabs while the hit areas stay fixed during animation.
Item {
    id: root

    property var tabs: []
    property int currentIndex: 0
    property int pillHeight: 36
    signal tabSelected(int index)

    implicitHeight: root.pillHeight

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colors.colLayer1
    }

    Rectangle {
        width: root.tabs.length > 0 ? root.width / root.tabs.length : 0
        height: parent.height
        x: width * Math.max(0, Math.min(root.currentIndex, root.tabs.length - 1))
        radius: height / 2
        color: Appearance.colors.colPrimaryContainer

        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.tabs

            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool selected: root.currentIndex === index
                width: root.tabs.length > 0 ? root.width / root.tabs.length : 0
                height: root.height

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    spacing: 4

                    MaterialSymbol {
                        visible: String(tab.modelData.icon ?? "").length > 0
                        text: tab.modelData.icon ?? ""
                        iconSize: 17
                        color: tab.selected
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: tab.modelData.label ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: tab.selected ? Font.DemiBold : Font.Normal
                        color: tab.selected
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                    }

                    Rectangle {
                        visible: tab.modelData.count !== undefined
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: height / 2
                        color: tab.selected
                            ? Appearance.colors.colPrimary
                            : Appearance.colors.colLayer2

                        StyledText {
                            anchors.centerIn: parent
                            text: String(tab.modelData.count ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: tab.selected
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colSubtext
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabSelected(tab.index)
                }
            }
        }
    }
}
