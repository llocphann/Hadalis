pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property date viewingDate
    required property date today
    property var locale: Qt.locale()
    property var calendarCells: []
    property bool interactiveDays: false
    property bool showEventDots: false

    signal previousMonthRequested()
    signal nextMonthRequested()
    signal todayRequested()
    signal dayActivated(var date)

    readonly property real cellSize: 30
    readonly property real cellSpacing: 4
    readonly property color colText: Appearance.colors.colOnSurface
    readonly property color colMuted: Appearance.colors.colOnSurfaceVariant
    readonly property color colAccent: Appearance.colors.colPrimary
    readonly property color colHover: Appearance.colors.colLayer1Hover

    readonly property var weekDaysModel: {
        const monday = new Date(2024, 0, 1)
        const labels = []
        for (let i = 0; i < 7; ++i) {
            const d = new Date(monday)
            d.setDate(monday.getDate() + i)
            labels.push(root.locale.toString(d, "ddd").toUpperCase())
        }
        return labels
    }

    implicitWidth: calendarGrid.implicitWidth
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        width: root.implicitWidth
        spacing: 10

        RowLayout {
            id: calendarHeader
            Layout.preferredWidth: calendarGrid.implicitWidth
            Layout.alignment: Qt.AlignHCenter
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
                onClicked: root.previousMonthRequested()
            }

            Item {
                id: todayButton
                implicitWidth: 50
                implicitHeight: 28
                opacity: root.viewingDate.getMonth() === root.today.getMonth()
                    && root.viewingDate.getFullYear() === root.today.getFullYear()
                    ? 0.55 : 1
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Today")
                Accessible.focusable: true
                Accessible.onPressAction: root.todayRequested()

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: todayMouse.containsMouse ? root.colHover : "transparent"
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Today").toUpperCase()
                    color: todayButton.opacity < 1 ? root.colMuted : root.colAccent
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.todayRequested()
                }

                Keys.onPressed: event => {
                    if (event.isAutoRepeat
                            || (event.key !== Qt.Key_Return
                                && event.key !== Qt.Key_Enter
                                && event.key !== Qt.Key_Space))
                        return
                    root.todayRequested()
                    event.accepted = true
                }
            }

            NavButton {
                iconName: "chevron_right"
                accessibleName: Translation.tr("Next month")
                onClicked: root.nextMonthRequested()
            }
        }

        GridLayout {
            id: calendarGrid
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: root.cellSpacing
            rowSpacing: 3

            Repeater {
                model: root.weekDaysModel

                delegate: StyledText {
                    required property var modelData
                    Layout.preferredWidth: root.cellSize
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

                    readonly property int eventCount: Number(dayCell.modelData?.eventCount ?? 0)
                    readonly property var eventColors: dayCell.modelData?.eventColors ?? []

                    Layout.preferredWidth: root.cellSize
                    Layout.preferredHeight: root.cellSize
                    radius: Appearance.rounding.small
                    color: dayHover.containsMouse ? root.colHover : "transparent"
                    opacity: dayCell.modelData?.currentMonth === false ? 0.25 : 1

                    StyledText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.showEventDots && dayCell.eventCount > 0 ? -2 : 0
                        text: String(dayCell.modelData?.day ?? "")
                        color: dayCell.modelData?.today ? root.colAccent : root.colText
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: dayCell.modelData?.today ? Font.DemiBold : Font.Normal
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        spacing: 1
                        visible: root.showEventDots && dayCell.eventCount > 0

                        Repeater {
                            model: {
                                if (dayCell.eventColors?.length > 0)
                                    return dayCell.eventColors.slice(0, 3)
                                return [root.colAccent]
                            }

                            delegate: Rectangle {
                                required property var modelData
                                width: 3
                                height: 3
                                radius: 1.5
                                color: modelData
                            }
                        }
                    }

                    MouseArea {
                        id: dayHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: root.interactiveDays ? Qt.LeftButton : Qt.NoButton
                        cursorShape: root.interactiveDays ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (root.interactiveDays && dayCell.modelData?.date)
                                root.dayActivated(dayCell.modelData.date)
                        }
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
