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
    property real horizontalContentPadding: 10
    property real iconTextSpacing: 5
    property int hoveredIndex: -1
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
        color: root.hoveredIndex === root.currentIndex
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colPrimaryContainer

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
            }
        }

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
                readonly property bool hasIcon:
                    String(tab.modelData.icon ?? "").length > 0
                readonly property bool hasBadge:
                    tab.modelData.count !== undefined
                width: root.tabs.length > 0 ? root.width / root.tabs.length : 0
                height: root.height
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    visible: !tab.selected
                    color: root.hoveredIndex === tab.index
                        ? Appearance.colors.colLayer1Hover
                        : "transparent"

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }
                }

                // Center icon + label as one visual unit. Optional badges are
                // anchored independently so their width can never push the tab
                // title off-center.
                Row {
                    id: centeredTabLabel
                    anchors.centerIn: parent
                    spacing: root.iconTextSpacing

                    MaterialSymbol {
                        visible: tab.hasIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.icon ?? ""
                        iconSize: 17
                        color: tab.selected
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        // Bound the label to its own slot. This keeps long timer
                        // labels from crossing into the adjacent active pill
                        // while preserving the centered icon+text unit.
                        width: Math.min(implicitWidth, Math.max(0,
                            tab.width
                                - root.horizontalContentPadding * 2
                                - (tab.hasIcon ? 22 : 0)
                                - (tab.hasBadge ? 24 : 0)))
                        text: tab.modelData.label ?? ""
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: tab.selected ? Font.DemiBold : Font.Normal
                        color: tab.selected
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                    }
                }

                Rectangle {
                    visible: tab.hasBadge
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
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

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredIndex = tab.index
                    onExited: {
                        if (root.hoveredIndex === tab.index)
                            root.hoveredIndex = -1
                    }
                    onClicked: root.tabSelected(tab.index)
                }
            }
        }
    }
}
