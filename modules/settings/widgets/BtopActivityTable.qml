import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Runtime target activity is intentionally not resource attribution. Quickshell
// QML components share the shell process, so Linux cannot provide trustworthy
// per-component CPU/RAM. This table exposes only real Workflow evidence:
// resident instances, visible instances and lifecycle events already recorded
// by CodeWorkflowRuntime.
Item {
    id: root

    property var targets: []
    property var records: []
    property var events: []
    property int maxRows: 4

    readonly property var activityRows: root.buildActivityRows()
    readonly property var visibleRows:
        root.activityRows.slice(0, Math.max(0, root.maxRows))

    function buildActivityRows(): var {
        const labels = ({})
        for (const target of Array.isArray(root.targets) ? root.targets : []) {
            const id = String(target?.targetId ?? "")
            if (id.length === 0)
                continue
            labels[id] = String(target?.label ?? id)
        }

        const byTarget = ({})
        function ensure(targetId) {
            const id = String(targetId ?? "")
            if (id.length === 0)
                return null
            if (!byTarget[id]) {
                byTarget[id] = {
                    targetId: id,
                    label: labels[id] ?? id,
                    resident: 0,
                    visible: 0,
                    events: 0
                }
            }
            return byTarget[id]
        }

        for (const record of Array.isArray(root.records) ? root.records : []) {
            const row = ensure(record?.targetId)
            if (!row || String(record?.state ?? "") !== "resident")
                continue
            row.resident += 1
            if (String(record?.lifecycle ?? "") === "visible")
                row.visible += 1
        }

        // CodeWorkflowRuntime keeps a bounded recent lifecycle event buffer.
        // Counting those events gives real churn evidence without pretending it
        // represents CPU time or memory ownership.
        for (const event of Array.isArray(root.events) ? root.events : []) {
            const row = ensure(event?.targetId)
            if (row)
                row.events += 1
        }

        return Object.keys(byTarget)
            .map(key => byTarget[key])
            .filter(row => row.resident > 0
                || row.visible > 0 || row.events > 0)
            .sort((left, right) =>
                right.events - left.events
                || right.visible - left.visible
                || right.resident - left.resident
                || String(left.label).localeCompare(String(right.label)))
    }

    implicitHeight: activityColumn.implicitHeight + 16

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b,
            0.34)

        ColumnLayout {
            id: activityColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 3

                StyledText {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: Translation.tr("QML activity")
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiBold
                }

                StyledText {
                    textFormat: Text.PlainText
                    text: Translation.tr("lifecycle · not CPU/RAM")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 8

                StyledText {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: Translation.tr("COMPONENT")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                    text: Translation.tr("LIVE")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                    text: Translation.tr("VIS")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }

                StyledText {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 46
                    horizontalAlignment: Text.AlignRight
                    text: Translation.tr("EVT")
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutline
                opacity: 0.55
            }

            Repeater {
                model: root.visibleRows

                delegate: Item {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    required property var modelData

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(modelData?.label
                                    ?? modelData?.targetId ?? "—")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(modelData?.targetId ?? "")
                                color: Appearance.colors.colSubtext
                                opacity: 0.82
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: String(modelData?.resident ?? 0)
                            color: Appearance.colors.colOnLayer1
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            text: String(modelData?.visible ?? 0)
                            color: Number(modelData?.visible ?? 0) > 0
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSubtext
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        StyledText {
                            textFormat: Text.PlainText
                            Layout.preferredWidth: 46
                            horizontalAlignment: Text.AlignRight
                            text: String(modelData?.events ?? 0)
                            color: Number(modelData?.events ?? 0) > 0
                                ? Appearance.colors.colSecondary
                                : Appearance.colors.colSubtext
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 1
                        color: Appearance.colors.colOutline
                        opacity: 0.24
                    }
                }
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.visibleRows.length === 0
                Layout.topMargin: 8
                text: Translation.tr("No active QML targets")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.activityRows.length > root.visibleRows.length
                Layout.topMargin: 3
                text: "+" + String(
                    root.activityRows.length - root.visibleRows.length)
                    + " " + Translation.tr("more components")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
    }
}
