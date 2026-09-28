pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

ColumnLayout {
    id: root
    implicitWidth: Math.max(210, menuColumn.implicitWidth)
    implicitHeight: menuColumn.implicitHeight
    spacing: 0

    function invoke(item): void {
        const action = item?.action
        GlobalStates.abyssPopupKind = ""
        GlobalStates.abyssDockMenuModel = []
        GlobalStates.abyssDockMenuOwnerId = ""
        GlobalStates.abyssDockMenuTriggerHovered = false
        if (action)
            Qt.callLater(action)
    }

    ColumnLayout {
        id: menuColumn
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: GlobalStates.abyssDockMenuModel ?? []

            delegate: Loader {
                id: rowLoader
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData?.type === "separator"
                    ? separatorComponent : actionComponent

                Component {
                    id: separatorComponent
                    Rectangle {
                        implicitHeight: 7
                        Layout.fillWidth: true
                        color: "transparent"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: Qt.alpha(AbyssStyle.accent, .18)
                        }
                    }
                }

                Component {
                    id: actionComponent
                    RippleButton {
                        implicitHeight: 38
                        implicitWidth: Math.max(210, actionRow.implicitWidth + 22)
                        buttonRadius: Math.min(16, height / 2)
                        onClicked: root.invoke(rowLoader.modelData)

                        contentItem: RowLayout {
                            id: actionRow
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Loader {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                active: String(rowLoader.modelData?.iconName ?? "").length > 0
                                sourceComponent: rowLoader.modelData?.monochromeIcon === true
                                    ? materialIcon : appIcon

                                Component {
                                    id: materialIcon
                                    MaterialSymbol {
                                        text: rowLoader.modelData?.iconName ?? ""
                                        iconSize: 18
                                        color: AbyssStyle.textColor
                                    }
                                }
                                Component {
                                    id: appIcon
                                    IconImage {
                                        source: Quickshell.iconPath(
                                            rowLoader.modelData?.iconName ?? "",
                                            "application-x-executable")
                                        implicitSize: 18
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: rowLoader.modelData?.text ?? ""
                                color: AbyssStyle.textColor
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
