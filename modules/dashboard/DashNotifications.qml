import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight.notifications

/**
 * Dashboard Notifications + Uptime card.
 *
 * Notifications keep the shared notification surface. Uptime intentionally
 * stays non-scrollable: it compresses the historical ScreenTime data into a
 * responsive summary + fixed app/window grid sized from the card's current
 * geometry.
 */
DashCard {
    id: root

    title: ""
    icon: ""
    Layout.fillHeight: true
    focus: true

    property int currentTab: 0
    property int _screenTimeRevision: 0

    readonly property bool narrowLayout: root.width > 0 && root.width < 300
    readonly property bool shallowLayout: root.height > 0 && root.height < 245
    readonly property bool veryShallowLayout: root.height > 0 && root.height < 175
    readonly property int tabControlHeight:
        root.veryShallowLayout ? 32 : (root.narrowLayout ? 36 : 38)
    readonly property int summaryHeight:
        root.veryShallowLayout ? 32 : (root.shallowLayout ? 36 : 42)
    readonly property int appRowHeight:
        root.veryShallowLayout ? 27 : (root.shallowLayout ? 30 : 34)
    readonly property int appIconSize: root.veryShallowLayout ? 18 : 20
    readonly property int appColumns: root.narrowLayout ? 1 : 2
    readonly property int appHeaderHeight: root.veryShallowLayout ? 0 : 18
    readonly property int contentSpacing:
        root.veryShallowLayout ? 4 : (root.shallowLayout ? 5 : 6)

    readonly property var todayData: {
        const revision = root._screenTimeRevision
        return ScreenTime.getToday()
    }
    readonly property var todayApps: {
        const revision = root._screenTimeRevision
        return ScreenTime.getAppList(1)
    }
    readonly property real maxAppSeconds: {
        let maximum = 1
        const apps = root.todayApps
        for (let i = 0; i < apps.length; ++i)
            maximum = Math.max(maximum, Number(apps[i]?.seconds ?? 0))
        return maximum
    }

    // Budget rows from the actual card height rather than introducing a
    // Flickable. The grid simply shows more entries when the user resizes the
    // Dashboard card taller.
    readonly property int availableAppRows: {
        const innerHeight = Math.max(0, root.height - root.pad * 2)
        const fixed = root.tabControlHeight
            + root.summaryHeight
            + root.appHeaderHeight
            + root.contentSpacing * (root.veryShallowLayout ? 2 : 3)
        return Math.max(1, Math.floor(
            Math.max(0, innerHeight - fixed)
                / Math.max(1, root.appRowHeight + root.contentSpacing)))
    }
    readonly property int visibleAppLimit:
        Math.max(root.appColumns,
            Math.min(8, root.availableAppRows * root.appColumns))
    readonly property var visibleApps:
        root.todayApps.slice(0, root.visibleAppLimit)
    readonly property int hiddenAppCount:
        Math.max(0, root.todayApps.length - root.visibleApps.length)

    function boundedBadge(value): string {
        return String(Math.min(99, Math.max(0, Number(value) || 0)))
    }

    function isCurrentApp(app): bool {
        const current = String(ScreenTime.currentAppId ?? "").toLowerCase()
        const original = String(app?.originalId ?? "").toLowerCase()
        const id = String(app?.id ?? "").toLowerCase()
        return current.length > 0
            && (current === original || current === id)
    }

    Connections {
        target: ScreenTime

        function onDataChanged(): void {
            root._screenTimeRevision++
        }

        function onReadyChanged(): void {
            root._screenTimeRevision++
        }

        function onEnabledChanged(): void {
            root._screenTimeRevision++
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_PageDown) {
            root.currentTab = Math.min(1, root.currentTab + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            root.currentTab = Math.max(0, root.currentTab - 1)
            event.accepted = true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: root.contentSpacing

        DashPillTabBar {
            Layout.fillWidth: true
            currentIndex: root.currentTab
            controlHeight: root.tabControlHeight
            narrow: root.narrowLayout
            leftLabel: Translation.tr("Notifications")
            rightLabel: Translation.tr("Uptime")
            leftIcon: "notifications"
            rightIcon: "avg_pace"
            leftBadgeText: root.boundedBadge(Notifications.list.length)
            rightBadgeText: root.boundedBadge(root.todayApps.length)
            leftBadgeVisible: true
            rightBadgeVisible: root.todayApps.length > 0
            inactiveTextColor: root.colSubtext
            onTabRequested: index => root.currentTab = index
        }

        Item {
            id: tabContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 1
            clip: true

            NotificationList {
                anchors.fill: parent
                visible: root.currentTab === 0
            }

            Item {
                id: uptimePage
                anchors.fill: parent
                visible: root.currentTab === 1
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: root.contentSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.summaryHeight
                        spacing: root.contentSpacing

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: height / 2
                            color: Appearance.colors.colLayer2
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.veryShallowLayout ? 7 : 9
                                anchors.rightMargin: root.veryShallowLayout ? 7 : 9
                                spacing: 6

                                MaterialSymbol {
                                    text: "avg_pace"
                                    iconSize: root.veryShallowLayout ? 15 : 17
                                    color: root.colAccent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("System uptime")
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        color: root.colSubtext
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: DateTime.uptime
                                        font.pixelSize:
                                            Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: root.colText
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: height / 2
                            color: Appearance.colors.colLayer2
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: root.veryShallowLayout ? 7 : 9
                                anchors.rightMargin: root.veryShallowLayout ? 7 : 9
                                spacing: 6

                                MaterialSymbol {
                                    text: "schedule"
                                    iconSize: root.veryShallowLayout ? 15 : 17
                                    color: root.colAccent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Today")
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        color: root.colSubtext
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: ScreenTime.formatDuration(
                                            Number(root.todayData?.totalSeconds ?? 0))
                                        font.pixelSize:
                                            Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: root.colText
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: !root.veryShallowLayout
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.appHeaderHeight
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Most used")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: root.colSubtext
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: root.hiddenAppCount > 0
                            text: "+" + root.hiddenAppCount
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colSubtext
                        }
                    }

                    GridLayout {
                        id: appGrid
                        visible: root.visibleApps.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: root.appColumns
                        uniformCellWidths: true
                        columnSpacing: root.contentSpacing
                        rowSpacing: root.contentSpacing

                        Repeater {
                            model: root.visibleApps

                            delegate: Rectangle {
                                id: appUsageCell
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: root.appRowHeight
                                radius: height / 2
                                clip: true

                                readonly property bool active:
                                    root.isCurrentApp(modelData)
                                color: active
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.colors.colLayer2

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    height: 2
                                    width: parent.width
                                        * Math.max(0, Math.min(1,
                                            Number(appUsageCell.modelData?.seconds ?? 0)
                                                / root.maxAppSeconds))
                                    color: appUsageCell.active
                                        ? Appearance.colors.colPrimary
                                        : root.colAccent
                                    opacity: appUsageCell.active ? 0.7 : 0.28
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin:
                                        root.veryShallowLayout ? 6 : 8
                                    anchors.rightMargin:
                                        root.veryShallowLayout ? 6 : 8
                                    spacing: root.veryShallowLayout ? 4 : 6

                                    SmartAppIcon {
                                        Layout.preferredWidth: root.appIconSize
                                        Layout.preferredHeight: root.appIconSize
                                        iconSize: root.appIconSize
                                        icon: AppSearch.guessIcon(
                                            String(appUsageCell.modelData?.name ?? "")
                                                .toLowerCase()
                                            || String(
                                                appUsageCell.modelData?.originalId
                                                    ?? appUsageCell.modelData?.id
                                                    ?? ""))
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: appUsageCell.modelData?.name
                                            || appUsageCell.modelData?.id || ""
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        font.weight: appUsageCell.active
                                            ? Font.DemiBold : Font.Medium
                                        color: appUsageCell.active
                                            ? Appearance.colors
                                                .colOnPrimaryContainer
                                            : root.colText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    StyledText {
                                        text: ScreenTime.formatDuration(
                                            Number(appUsageCell
                                                .modelData?.seconds ?? 0))
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: appUsageCell.active
                                            ? Appearance.colors
                                                .colOnPrimaryContainer
                                            : root.colSubtext
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.visibleApps.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 8, 240)
                            spacing: 7

                            MaterialSymbol {
                                text: "av_timer"
                                iconSize: 20
                                color: root.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: ScreenTime.enabled
                                    ? Translation.tr("No screen time data yet")
                                    : Translation.tr(
                                        "Screen Time is starting…")
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                color: root.colSubtext
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
