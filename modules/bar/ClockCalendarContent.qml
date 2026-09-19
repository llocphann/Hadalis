pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int monthShift: 0
    readonly property date today: DateTime.clock.date
    readonly property var locale: Qt.locale()
    readonly property date viewingDate: new Date(
        root.today.getFullYear(),
        root.today.getMonth() + root.monthShift,
        1
    )

    readonly property var weekDaysModel: {
        // 2024-01-01 is a Monday. Keep this popup Monday-first to match the
        // requested Obsidian Calendar reference and the previous Weather grid.
        const monday = new Date(2024, 0, 1)
        const labels = []
        for (let i = 0; i < 7; ++i) {
            const d = new Date(monday)
            d.setDate(monday.getDate() + i)
            labels.push(root.locale.toString(d, "ddd").toUpperCase())
        }
        return labels
    }

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

    readonly property color colText: Appearance.colors.colOnSurface
    readonly property color colMuted: Appearance.colors.colOnSurfaceVariant
    readonly property color colAccent: Appearance.colors.colPrimary
    readonly property color colHover: Appearance.colors.colLayer1Hover

    implicitWidth: Math.max(246, calendarGrid.implicitWidth)
    implicitHeight: contentColumn.implicitHeight

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function previousMonth(): void { root.monthShift-- }
    function nextMonth(): void { root.monthShift++ }
    function resetToToday(): void { root.monthShift = 0 }

    ColumnLayout {
        id: contentColumn
        width: root.implicitWidth
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 5

            RowLayout {
                spacing: 5

                StyledText {
                    text: root.locale.toString(root.viewingDate, "MMM")
                    color: root.colText
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * 1.35)
                    font.weight: Font.Medium
                }

                StyledText {
                    text: root.locale.toString(root.viewingDate, "yyyy")
                    color: root.colAccent
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * 1.35)
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            NavButton {
                iconName: "chevron_left"
                accessibleName: Translation.tr("Previous month")
                onClicked: root.previousMonth()
            }

            Item {
                id: todayButton
                implicitWidth: 50
                implicitHeight: 28
                opacity: root.monthShift === 0 ? 0.55 : 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Today")
                Accessible.focusable: true
                Accessible.onPressAction: root.resetToToday()

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: todayMouse.containsMouse ? root.colHover : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Today").toUpperCase()
                    color: root.monthShift === 0 ? root.colMuted : root.colAccent
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetToToday()
                }

                Keys.onPressed: event => {
                    if (event.isAutoRepeat
                            || (event.key !== Qt.Key_Return
                                && event.key !== Qt.Key_Enter
                                && event.key !== Qt.Key_Space))
                        return
                    root.resetToToday()
                    event.accepted = true
                }
            }

            NavButton {
                iconName: "chevron_right"
                accessibleName: Translation.tr("Next month")
                onClicked: root.nextMonth()
            }
        }

        GridLayout {
            id: calendarGrid
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 4
            rowSpacing: 3

            Repeater {
                model: root.weekDaysModel

                delegate: StyledText {
                    required property var modelData
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: String(modelData)
                    color: root.colMuted
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }
            }

            Repeater {
                model: root.calendarCells

                delegate: Rectangle {
                    id: dayCell
                    required property var modelData

                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: Appearance.rounding.small
                    color: dayHover.containsMouse ? root.colHover : "transparent"
                    opacity: dayCell.modelData.currentMonth ? 1 : 0.25

                    StyledText {
                        anchors.centerIn: parent
                        text: String(dayCell.modelData.day)
                        color: dayCell.modelData.today ? root.colAccent : root.colText
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: dayCell.modelData.today ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: dayHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }

    component NavButton: Item {
        id: navButton
        required property string iconName
        required property string accessibleName
        signal clicked()

        implicitWidth: 24
        implicitHeight: 28
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: navButton.accessibleName
        Accessible.focusable: true
        Accessible.onPressAction: navButton.clicked()

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: navMouse.containsMouse ? root.colHover : "transparent"
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: navButton.iconName
            iconSize: 16
            color: root.colMuted
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navButton.clicked()
        }

        Keys.onPressed: event => {
            if (event.isAutoRepeat
                    || (event.key !== Qt.Key_Return
                        && event.key !== Qt.Key_Enter
                        && event.key !== Qt.Key_Space))
                return
            navButton.clicked()
            event.accepted = true
        }
    }
}
