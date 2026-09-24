pragma ComponentBehavior: Bound

import qs.modules.common.widgets
import qs.modules.sidebarRight.events
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal eventEditorRequested(var event)

    property int monthShift: 0
    readonly property date today: DateTime.clock.date
    readonly property var locale: Qt.locale()
    readonly property date viewingDate: new Date(
        root.today.getFullYear(),
        root.today.getMonth() + root.monthShift,
        1
    )

    readonly property var calendarCells: {
        const year = root.viewingDate.getFullYear()
        const month = root.viewingDate.getMonth()
        const first = new Date(year, month, 1)
        const mondayOffset = (first.getDay() + 6) % 7
        const start = new Date(year, month, 1 - mondayOffset)
        const cells = []

        for (let i = 0; i < 42; ++i) {
            const d = new Date(start)
            d.setDate(start.getDate() + i)
            cells.push({
                date: d,
                day: d.getDate(),
                currentMonth: d.getMonth() === month && d.getFullYear() === year,
                today: root.sameDay(d, root.today),
            })
        }
        return cells
    }

    implicitWidth: Math.max(246, monthView.implicitWidth) + 345
    implicitHeight: monthView.implicitHeight

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        EventsWidget {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            // Calendar popup-specific FAB treatment: smaller and tucked into
            // the popup's bottom-left corner. Other EventsWidget owners keep
            // the shared bottom-right default.
            fabSize: 36
            fabMargins: 10
            fabLeftAligned: true
            onOpenEventsDialog: (event) => root.eventEditorRequested(event)
        }

        Rectangle {
            // A shorter centered hairline keeps the two panes visually related
            // without cutting the popup in half. Use the active theme accent
            // instead of a high-contrast white/outline line.
            Layout.preferredWidth: 1
            Layout.preferredHeight: Math.max(120, root.height - 64)
            Layout.maximumHeight: Math.max(120, root.height - 40)
            Layout.alignment: Qt.AlignVCenter
            color: Appearance.colors.colPrimary
            opacity: 0.28
        }

        Item {
            Layout.preferredWidth: Math.max(246, monthView.implicitWidth)
            Layout.fillHeight: true

            ObsidianMonthCalendar {
                id: monthView
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                viewingDate: root.viewingDate
                today: root.today
                locale: root.locale
                calendarCells: root.calendarCells
                onPreviousMonthRequested: root.monthShift--
                onNextMonthRequested: root.monthShift++
                onTodayRequested: root.monthShift = 0
            }
        }
    }
}
