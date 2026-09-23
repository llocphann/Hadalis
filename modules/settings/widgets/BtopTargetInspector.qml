import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var descriptor: null
    property var records: []
    property var events: []
    property string selectedInstanceId: ""
    signal instanceActivated(string instanceId)

    readonly property string targetId:
        String(root.descriptor?.targetId ?? "")
    readonly property var targetRecords:
        (Array.isArray(root.records) ? root.records : [])
            .filter(record =>
                String(record?.targetId ?? "") === root.targetId)
    readonly property var residentRecords:
        root.targetRecords.filter(record =>
            String(record?.state ?? "") === "resident")
    readonly property var targetEvents: {
        const matches = (Array.isArray(root.events) ? root.events : [])
            .filter(event =>
                String(event?.targetId ?? "") === root.targetId)
        return matches.slice(Math.max(0, matches.length - 8)).reverse()
    }

    function lifecycleFor(record): string {
        return String(record?.lifecycle
            ?? record?.state ?? "unloaded")
    }

    function eventTime(atMs): string {
        const value = Number(atMs)
        if (!Number.isFinite(value) || value <= 0)
            return "—"
        return Qt.formatTime(new Date(value), "HH:mm:ss")
    }

    implicitHeight: inspectorColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutline

        ColumnLayout {
            id: inspectorColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: root.descriptor
                            ? String(root.descriptor?.label
                                ?? root.targetId)
                            : "Select a target"
                        color: Appearance.colors.colOnLayer1
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.descriptor ? root.targetId : "—"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    visible: root.descriptor !== null
                    text: String(root.residentRecords.length)
                        + " resident"
                    color: Appearance.colors.colPrimary
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }
            }

            GridLayout {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                columns: width >= 620 ? 3 : 1
                columnSpacing: 12
                rowSpacing: 6

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: "KIND"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.descriptor?.kind ?? "—")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: "FAMILY"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.descriptor?.family ?? "—")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: "SOURCE"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.descriptor?.sourcePath ?? "—")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideMiddle
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.55
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                text: "Instances"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Repeater {
                model: root.targetRecords

                Rectangle {
                    id: instanceRow
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Appearance.rounding.small
                    color: String(modelData?.instanceId ?? "")
                            === root.selectedInstanceId
                        ? Appearance.colors.colLayer2 : "transparent"

                    readonly property string instanceId:
                        String(modelData?.instanceId ?? "")
                    readonly property bool selectable:
                        instanceId.length > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1.8
                            text: instanceRow.instanceId.length > 0
                                ? instanceRow.instanceId : "declaration"
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideMiddle
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: root.lifecycleFor(modelData)
                            color: root.lifecycleFor(modelData) === "visible"
                                || root.lifecycleFor(modelData) === "resident"
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: String(modelData?.output ?? "") || "—"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: instanceRow.selectable
                        cursorShape: enabled
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked:
                            root.instanceActivated(instanceRow.instanceId)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                    && root.targetRecords.length === 0
                text: "No runtime instances"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.55
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                text: "Recent lifecycle"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Repeater {
                model: root.targetEvents

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        Layout.preferredWidth: 64
                        text: root.eventTime(modelData?.atMs)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: String(modelData?.kind ?? "event")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: String(modelData?.instanceId ?? "")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideMiddle
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.descriptor !== null
                    && root.targetEvents.length === 0
                text: "No recent lifecycle events"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
