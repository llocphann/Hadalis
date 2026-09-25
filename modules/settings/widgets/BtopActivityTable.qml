import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Workflow lifecycle evidence is intentionally separate from Linux resource
// attribution. QML components share the Hadalis process, so the kernel cannot
// provide trustworthy per-component CPU/RAM. Rows below rank recent lifecycle
// churn from CodeWorkflowRuntime timestamps plus resident/visible instances.
Item {
    id: root
    property var targets: []
    property var records: []
    property var events: []
    property int maxRows: 5
    property bool localScroll: false
    readonly property int activityWindowMs: 60000
    readonly property double activityClockMs: {
        // Reuse the Diagnostics session heartbeat so lifecycle rates age only
        // while the page is current; reopening also refreshes the clock
        // immediately without adding a second polling timer.
        RuntimeDiagnosticsSession.pageCurrent
        RuntimeDiagnosticsSession.heartbeatTick
        return Date.now()
    }
    readonly property var activityRows: root.buildActivityRows()
    readonly property var visibleRows:
        root.activityRows.slice(0, Math.max(0, root.maxRows))
    readonly property var renderedRows:
        root.localScroll ? root.activityRows : root.visibleRows
    readonly property int peakActivityPerMinute:
        root.renderedRows.reduce((peak, row) =>
            Math.max(peak, Number(row?.eventsPerMinute ?? 0)), 0)

    function buildActivityRows(): var {
        const labels = ({})
        for (const target of Array.isArray(root.targets) ? root.targets : []) {
            const id = String(target?.targetId ?? "")
            if (id.length > 0)
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
                    recentEvents: 0,
                    eventsPerMinute: 0
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
        const windowStart = root.activityClockMs - root.activityWindowMs
        for (const event of Array.isArray(root.events) ? root.events : []) {
            const row = ensure(event?.targetId)
            if (!row)
                continue
            const atMs = Number(event?.atMs)
            if (!Number.isFinite(atMs)
                    || atMs < windowStart
                    || atMs > root.activityClockMs + 1000)
                continue
            row.recentEvents += 1
        }
        for (const key of Object.keys(byTarget)) {
            const row = byTarget[key]
            row.eventsPerMinute = Math.round(
                row.recentEvents * 60000 / root.activityWindowMs)
        }
        return Object.keys(byTarget)
            .map(key => byTarget[key])
            .filter(row => row.resident > 0
                || row.visible > 0 || row.recentEvents > 0)
            .sort((left, right) =>
                right.eventsPerMinute - left.eventsPerMinute
                || right.visible - left.visible
                || right.resident - left.resident
                || String(left.label).localeCompare(String(right.label)))
    }

    implicitHeight: root.localScroll
        ? 260 : activityColumn.implicitHeight + 16

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
            id: activityColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: Translation.tr("Component hotspots")
                color: Appearance.colors.colOnLayer1
                font.weight: Font.DemiBold
            }
            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.bottomMargin: 5
                text: Translation.tr("Lifecycle activity — not CPU/RAM attribution")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                elide: Text.ElideRight
            }

            StyledListView {
                id: activityList
                Layout.fillWidth: true
                Layout.fillHeight: root.localScroll
                Layout.minimumHeight: root.localScroll ? 0
                    : root.renderedRows.length * 38
                Layout.preferredHeight: root.localScroll ? 0
                    : root.renderedRows.length * 38
                model: root.renderedRows
                clip: true
                spacing: 0
                interactive: root.localScroll && contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                animateAppearance: false
                animateMovement: false

                delegate: Item {
                    id: activityRow
                    width: ListView.view?.width ?? 0
                    height: 38
                    required property var modelData
                    required property int index
                    readonly property real activityFraction:
                        root.peakActivityPerMinute > 0
                            ? Math.min(1, Number(
                                activityRow.modelData?.eventsPerMinute ?? 0)
                                / root.peakActivityPerMinute) : 0

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            rightMargin: root.localScroll
                                && activityList.contentHeight > activityList.height
                                ? 6 : 0
                        }
                        height: 32
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Appearance.colors.colLayer1
                            StyledText {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: String(activityRow.index + 1)
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
                                text: String(activityRow.modelData?.label
                                    ?? activityRow.modelData?.targetId ?? "—")
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: String(
                                    activityRow.modelData?.targetId ?? "")
                                color: Appearance.colors.colSubtext
                                opacity: 0.78
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                elide: Text.ElideMiddle
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 96
                            spacing: -2
                            StyledText {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: String(
                                    activityRow.modelData
                                        ?.eventsPerMinute ?? 0)
                                    + " " + Translation.tr("changes/min")
                                color: Number(
                                    activityRow.modelData
                                        ?.eventsPerMinute ?? 0) > 0
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colSubtext
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
                                text: String(
                                    activityRow.modelData?.resident ?? 0)
                                    + " " + Translation.tr("live") + " · "
                                    + String(
                                        activityRow.modelData?.visible ?? 0)
                                    + " " + Translation.tr("visible")
                                color: Appearance.colors.colSubtext
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
                            rightMargin: root.localScroll
                                && activityList.contentHeight > activityList.height
                                ? 8 : 2
                        }
                        height: 3
                        radius: 2
                        color: Appearance.colors.colLayer1
                        Rectangle {
                            width: parent.width * activityRow.activityFraction
                            height: parent.height
                            radius: parent.radius
                            color: Appearance.colors.colPrimary
                            opacity: 0.82
                        }
                    }
                }
            }

            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: root.activityRows.length === 0
                Layout.topMargin: 8
                text: Translation.tr("No active QML targets")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
            StyledText {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: !root.localScroll
                    && root.activityRows.length > root.visibleRows.length
                Layout.topMargin: 3
                text: "+" + String(root.activityRows.length - root.visibleRows.length)
                    + " " + Translation.tr("more components")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
    }
}
