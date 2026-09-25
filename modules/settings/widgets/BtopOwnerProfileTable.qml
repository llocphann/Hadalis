import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Aggregated Qt QML Profiler evidence. This deliberately reports QML/JS work
// time and QV4 allocation activity instead of inventing per-owner CPU/RSS/GPU
// percentages for objects that share one Quickshell process and scene graph.
Item {
    id: root

    property var profile: null
    readonly property var rows: root.buildRows()
    readonly property double traceSeconds:
        Math.max(0, Number(root.profile?.trace?.durationNs ?? 0))
            / 1000000000

    function buildRows(): var {
        const result = []
        function appendGroup(label, kind, sourceRows) {
            if (!Array.isArray(sourceRows) || sourceRows.length === 0)
                return
            result.push({
                section: true,
                label: label,
                kind: kind
            })
            for (const row of sourceRows) {
                result.push(Object.assign({}, row, {
                    section: false,
                    kind: kind
                }))
            }
        }
        appendGroup(Translation.tr("Modules"), "module",
            root.profile?.modules ?? [])
        appendGroup(Translation.tr("Services"), "service",
            root.profile?.services ?? [])
        appendGroup(Translation.tr("Components"), "component",
            root.profile?.components ?? [])
        return result
    }

    function formatWork(value): string {
        const number = Number(value)
        return Number.isFinite(number) && number >= 0
            ? number.toFixed(number >= 10 ? 1 : 2) + " ms/s" : "—"
    }

    function formatRate(value): string {
        const bytes = Number(value)
        if (!Number.isFinite(bytes) || bytes < 0)
            return "—"
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB/s"
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(1) + " KiB/s"
        return bytes.toFixed(0) + " B/s"
    }

    function allocationRate(row): string {
        if (root.traceSeconds <= 0)
            return "—"
        return root.formatRate(
            Number(row?.allocations?.allocatedBytes ?? 0)
                / root.traceSeconds)
    }

    implicitHeight: 260

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colPrimary.r,
            Appearance.colors.colPrimary.g,
            Appearance.colors.colPrimary.b, 0.16)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: Translation.tr("Deep QML owners")
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.DemiBold
                }

                StyledText {
                    textFormat: Text.PlainText
                    text: root.profile?.capture?.durationSeconds
                        ? Number(root.profile.capture.durationSeconds)
                            .toFixed(0) + "s"
                        : "trace"
                    color: Appearance.colors.colPrimary
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.bottomMargin: 5
                text: Translation.tr(
                    "QML work · QV4 allocation — not CPU/RSS/GPU attribution")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }

            StyledListView {
                id: ownerList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                model: root.rows
                clip: true
                spacing: 0
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                animateAppearance: false
                animateMovement: false

                delegate: Item {
                    id: ownerRow
                    width: ListView.view ? ListView.view.width : 0
                    height: modelData?.section === true ? 28 : 44
                    required property var modelData
                    required property int index

                    StyledText {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 2
                        }
                        visible: ownerRow.modelData?.section === true
                        textFormat: Text.PlainText
                        text: String(ownerRow.modelData?.label ?? "")
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            rightMargin: ownerList.contentHeight > ownerList.height
                                ? 6 : 0
                        }
                        height: 38
                        spacing: 7
                        visible: ownerRow.modelData?.section !== true

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Appearance.colors.colLayer1

                            StyledText {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: ownerRow.modelData?.kind === "module"
                                    ? "M"
                                    : ownerRow.modelData?.kind === "service"
                                        ? "S" : "C"
                                color: Appearance.colors.colPrimary
                                font.family: Appearance.font.family.monospace
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(ownerRow.modelData?.label
                                    ?? ownerRow.modelData?.id ?? "—")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(ownerRow.modelData?.id ?? "")
                                color: Appearance.colors.colSubtext
                                opacity: 0.78
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                elide: Text.ElideMiddle
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 126
                            spacing: -2

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: "QML "
                                    + root.formatWork(
                                        ownerRow.modelData
                                            ?.qmlWorkMsPerSecond)
                                color: Appearance.colors.colPrimary
                                font.family:
                                    Appearance.font.family.monospace
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: "Alloc "
                                    + root.allocationRate(
                                        ownerRow.modelData)
                                    + " · GPU —"
                                color: Appearance.colors.colSubtext
                                font.family:
                                    Appearance.font.family.monospace
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 31
                            rightMargin: 4
                        }
                        visible: ownerRow.modelData?.section !== true
                        height: 1
                        color: Appearance.colors.colOutline
                        opacity: 0.18
                    }
                }
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.rows.length === 0
                Layout.topMargin: 8
                text: Translation.tr("No deep QML profile captured")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }
}
