import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: root

    property bool compact: false
    readonly property real compactBreakpoint: 900
    property date now: new Date()

    spacing: 10
    implicitWidth: composition.implicitWidth

    function firstDayOffset(): int {
        const first = new Date(root.now.getFullYear(), root.now.getMonth(), 1)
        return (first.getDay() + 6) % 7
    }

    function daysInMonth(): int {
        return new Date(root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate()
    }

    function calendarDay(index): int {
        const day = index - root.firstDayOffset() + 1
        return day >= 1 && day <= root.daysInMonth() ? day : 0
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    GridLayout {
        id: composition
        columns: root.compact ? 1 : 3
        columnSpacing: 10
        rowSpacing: 10
        Layout.alignment: Qt.AlignHCenter

        Rectangle {
            id: calendarPanel
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh
            implicitWidth: 250
            implicitHeight: calendarColumn.implicitHeight + 28
            Layout.fillWidth: root.compact
            Layout.preferredWidth: root.compact ? 360 : implicitWidth
            Layout.alignment: Qt.AlignTop

            ColumnLayout {
                id: calendarColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                spacing: 8

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(root.now, "MMMM yyyy")
                    font {
                        weight: Font.DemiBold
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurface
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    rowSpacing: 3
                    columnSpacing: 3

                    Repeater {
                        model: 7

                        delegate: StyledText {
                            required property int index
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDate(new Date(2024, 0, 1 + index), "ddd")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    Repeater {
                        model: 42

                        delegate: Rectangle {
                            id: dayCell
                            required property int index
                            readonly property int dayNumber: root.calendarDay(index)
                            readonly property bool isToday: dayNumber === root.now.getDate()
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: isToday ? Appearance.colors.colPrimary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: dayCell.dayNumber > 0 ? String(dayCell.dayNumber) : ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: dayCell.isToday
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnSurface
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: timeWeatherPanel
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh
            implicitWidth: 330
            implicitHeight: centerColumn.implicitHeight + 28
            Layout.fillWidth: root.compact
            Layout.preferredWidth: root.compact ? 360 : implicitWidth
            Layout.alignment: Qt.AlignTop

            ColumnLayout {
                id: centerColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                spacing: 4

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: DateTime.timeDisplay
                    font {
                        weight: Font.DemiBold
                        pixelSize: Math.round(Appearance.font.pixelSize.large * 2.4)
                    }
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: DateTime.date
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 7

                    MaterialSymbol {
                        text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Weather.data.temp
                        font {
                            weight: Font.Medium
                            pixelSize: Appearance.font.pixelSize.large
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        text: Weather.data.description
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                Item {
                    id: hourlyTimeline
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    Layout.topMargin: 8

                    readonly property var hours: Weather.data.hourly.slice(0, 5)

                    Shape {
                        anchors.fill: parent

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Appearance.colors.colPrimary
                            strokeWidth: 2
                            capStyle: ShapePath.RoundCap
                            startX: 24
                            startY: 88

                            PathQuad {
                                x: Math.max(24, hourlyTimeline.width - 24)
                                y: 88
                                controlX: hourlyTimeline.width / 2
                                controlY: 24
                            }
                        }
                    }

                    Repeater {
                        model: hourlyTimeline.hours

                        delegate: Item {
                            id: hourPoint
                            required property int index
                            required property var modelData
                            readonly property int count: Math.max(1, hourlyTimeline.hours.length)
                            readonly property real centerIndex: (count - 1) / 2
                            readonly property real normalized: centerIndex > 0
                                ? (index - centerIndex) / centerIndex : 0
                            width: 52
                            height: 92
                            x: count <= 1
                                ? (hourlyTimeline.width - width) / 2
                                : 24 + index * ((hourlyTimeline.width - 48) / (count - 1)) - width / 2
                            y: 20 + 56 * normalized * normalized

                            Rectangle {
                                id: hourDot
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 34
                                width: 9
                                height: 9
                                radius: width / 2
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    bottom: hourDot.top
                                    bottomMargin: 3
                                }
                                text: hourPoint.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            MaterialSymbol {
                                id: hourIcon
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    top: hourDot.bottom
                                    topMargin: 4
                                }
                                text: Icons.getWeatherIcon(
                                    hourPoint.modelData.code,
                                    hourPoint.modelData.isNight) ?? "cloud"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                            }

                            StyledText {
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    top: hourIcon.bottom
                                    topMargin: 1
                                }
                                text: hourPoint.modelData.temp
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: hourlyTimeline.hours.length === 0
                        text: "—"
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }

        Rectangle {
            id: detailPanel
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh
            implicitWidth: 360
            implicitHeight: detailColumn.implicitHeight + 28
            Layout.fillWidth: root.compact
            Layout.preferredWidth: root.compact ? 360 : implicitWidth
            Layout.alignment: Qt.AlignTop

            ColumnLayout {
                id: detailColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 14
                }
                spacing: 8

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    RowLayout {
                        visible: Weather.showVisibleCity
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        MaterialSymbol {
                            fill: 0
                            font.weight: Font.Medium
                            text: "place"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        StyledText {
                            text: Weather.visibleCity
                            font {
                                weight: Font.Medium
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                        text: Weather.data.temp + " • "
                            + Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                    }
                }

                GridLayout {
                    columns: 2
                    rowSpacing: 5
                    columnSpacing: 5
                    uniformCellWidths: true
                    Layout.fillWidth: true

                    WeatherCard {
                        title: Translation.tr("UV Index")
                        symbol: "wb_sunny"
                        value: Weather.data.uv
                    }
                    WeatherCard {
                        title: Translation.tr("Wind")
                        symbol: "air"
                        value: `(${Weather.data.windDir}) ${Weather.data.wind}`
                    }
                    WeatherCard {
                        title: Translation.tr("Precipitation")
                        symbol: "rainy_light"
                        value: Weather.data.precip
                    }
                    WeatherCard {
                        title: Translation.tr("Humidity")
                        symbol: "humidity_low"
                        value: Weather.data.humidity
                    }
                    WeatherCard {
                        title: Translation.tr("Visibility")
                        symbol: "visibility"
                        value: Weather.data.visib
                    }
                    WeatherCard {
                        title: Translation.tr("Pressure")
                        symbol: "readiness_score"
                        value: Weather.data.press
                    }
                    WeatherCard {
                        title: Translation.tr("Sunrise")
                        symbol: "wb_twilight"
                        value: Weather.data.sunrise
                    }
                    WeatherCard {
                        title: Translation.tr("Sunset")
                        symbol: "bedtime"
                        value: Weather.data.sunset
                    }
                }
            }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)
        font {
            weight: Font.Medium
            pixelSize: Appearance.font.pixelSize.smaller
        }
        color: Appearance.colors.colOnSurfaceVariant
    }
}
