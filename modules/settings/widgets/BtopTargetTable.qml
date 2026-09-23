import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var targets: []
    property var records: []
    property int maxRows: 18
    property string selectedTargetId: ""
    signal targetActivated(string targetId, string instanceId)

    readonly property var visibleTargets:
        Array.isArray(root.targets)
            ? root.targets.slice(0, Math.max(0, root.maxRows))
            : []

    function recordsFor(targetId) {
        const id = String(targetId ?? "")
        return (Array.isArray(root.records) ? root.records : [])
            .filter(record => String(record?.targetId ?? "") === id)
    }

    function residentRecords(targetId) {
        return root.recordsFor(targetId)
            .filter(record => String(record?.state ?? "") === "resident")
    }

    function stateFor(target) {
        const targetId = String(target?.targetId ?? "")
        const resident = root.residentRecords(targetId)
        if (resident.length > 0) {
            const visible = resident.find(record =>
                String(record?.lifecycle ?? "") === "visible")
            return visible ? "visible" : "resident"
        }

        const records = root.recordsFor(targetId)
        if (records.length > 0)
            return String(records[0]?.lifecycle
                ?? records[0]?.state ?? "unloaded")
        return String(target?.lifecycle ?? target?.state ?? "unloaded")
    }

    function outputsFor(targetId) {
        const outputs = []
        for (const record of root.residentRecords(targetId)) {
            const output = String(record?.output ?? "")
            if (output.length > 0 && !outputs.includes(output))
                outputs.push(output)
        }
        return outputs.join(", ")
    }

    implicitHeight: tableColumn.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutline

        ColumnLayout {
            id: tableColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8

                StyledText {
                    Layout.fillWidth: true
                    text: "Runtime targets"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: String(root.targets.length)
                    color: Appearance.colors.colPrimary
                    font.weight: Font.DemiBold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2.4
                    text: "TARGET"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: "STATE"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignRight
                    text: "INST"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1.2
                    text: "OUTPUT"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.65
            }

            Repeater {
                model: root.visibleTargets

                Item {
                    id: targetRow
                    Layout.fillWidth: true
                    implicitHeight: 44

                    readonly property var target: modelData
                    readonly property string targetId:
                        String(target?.targetId ?? "")
                    readonly property var residents:
                        root.residentRecords(targetId)
                    readonly property string state:
                        root.stateFor(target)
                    readonly property bool selected:
                        targetId === root.selectedTargetId

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: targetRow.selected
                            ? Appearance.colors.colLayer2
                            : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 2.4
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: String(targetRow.target?.label
                                    ?? targetRow.targetId)
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: targetRow.targetId
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: targetRow.state
                            color: targetRow.state === "visible"
                                || targetRow.state === "resident"
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.preferredWidth: 64
                            horizontalAlignment: Text.AlignRight
                            text: String(targetRow.residents.length)
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1.2
                            text: root.outputsFor(targetRow.targetId) || "—"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const instanceId = targetRow.residents.length > 0
                                ? String(
                                    targetRow.residents[0]?.instanceId ?? "")
                                : ""
                            root.targetActivated(
                                targetRow.targetId, instanceId)
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Appearance.colors.colOutline
                        opacity: 0.35
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.targets.length > root.visibleTargets.length
                Layout.topMargin: 8
                text: "+" + String(
                    root.targets.length - root.visibleTargets.length)
                    + " more targets"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
