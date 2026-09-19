pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    required property string hostId
    required property bool settingsLoaded
    required property int currentPage

    function report(): void {
        CodeWorkflowPicker.reportSettingsHost(
            root.hostId, root.settingsLoaded, root.currentPage)
    }

    onSettingsLoadedChanged: root.report()
    onCurrentPageChanged: root.report()

    Component.onCompleted: root.report()
    Component.onDestruction: CodeWorkflowPicker.removeSettingsHost(root.hostId)

    Timer {
        interval: 16
        repeat: true
        running: CodeWorkflowPicker.phase === "preparing"
            || CodeWorkflowPicker.phase === "restoring"
        onTriggered: CodeWorkflowPicker.advance()
    }

    Variants {
        model: CodeWorkflowPicker.phase === "picking"
            ? Quickshell.screens
            : []

        PanelWindow {
            id: overlay

            required property ShellScreen modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell:code-workflow-picker"

            property string hovered: ""

            Component.onCompleted: CodeWorkflowPicker.overlayMounted()
            Component.onDestruction: CodeWorkflowPicker.overlayUnmounted()

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor

                onPositionChanged: event => {
                    overlay.hovered = CodeWorkflowRuntime.hit(
                        overlay.modelData.name, event.x, event.y)
                }
                onExited: overlay.hovered = ""
                onClicked: event => {
                    event.accepted = true
                    const hit = CodeWorkflowRuntime.hit(
                        overlay.modelData.name, event.x, event.y)
                    CodeWorkflowPicker.recordClick(
                        overlay.modelData.name, event.x, event.y, hit)

                    if (event.button === Qt.RightButton) {
                        CodeWorkflowPicker.finish("cancelled", "")
                    } else if (hit.length > 0) {
                        CodeWorkflowPicker.finish("selected", hit)
                    }
                }
            }

            Rectangle {
                readonly property var target:
                    CodeWorkflowRuntime.entries[overlay.hovered]
                readonly property rect bounds:
                    target?.geometry ?? Qt.rect(0, 0, 0, 0)

                x: bounds.x
                y: bounds.y
                width: bounds.width
                height: bounds.height
                visible: overlay.hovered.length > 0
                color: "transparent"
                border.color: Appearance.colors.colPrimary
                border.width: 2
                radius: Appearance.rounding.small
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 64
                implicitWidth: instruction.implicitWidth + 28
                implicitHeight: instruction.implicitHeight + 14
                radius: implicitHeight / 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                StyledText {
                    id: instruction
                    anchors.centerIn: parent
                    text: "Pick a live ii Bar component · right-click to cancel"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
