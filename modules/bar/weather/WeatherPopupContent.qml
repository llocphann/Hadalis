import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: root

    property bool compact: false
    readonly property real compactBreakpoint: 1180
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
            radius: Appearance.rounding.large
            color: "transparent"
            implicitWidth: 430
            implicitHeight: 350
            Layout.fillWidth: root.compact
            Layout.preferredWidth: root.compact ? 360 : implicitWidth
            Layout.alignment: Qt.AlignTop

            Item {
                id: orbitalTimeline
                anchors.fill: parent
                anchors.margins: 8

                // Serpantinum-inspired frontend: the clock is the visual center
                // and Hadalis hourly data is distributed around an ellipse.
                readonly property var hours: (Weather.data?.hourly ?? []).slice(0, 8)
                readonly property real radiusX: Math.max(118, (width - 92) / 2)
                readonly property real radiusY: Math.max(88, (height - 126) / 2)

                Canvas {
                    id: orbitGuide
                    anchors.centerIn: parent
                    width: Math.max(1, orbitalTimeline.radiusX * 2)
                    height: Math.max(1, orbitalTimeline.radiusY * 2)
                    opacity: 0.42

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.beginPath()
                        const rx = Math.max(1, width / 2 - 2)
                        const ry = Math.max(1, height / 2 - 2)
                        for (let angle = 0; angle <= Math.PI * 2 + 0.01; angle += 0.05) {
                            const x = width / 2 + Math.cos(angle) * rx
                            const y = height / 2 + Math.sin(angle) * ry
                            if (angle === 0)
                                ctx.moveTo(x, y)
                            else
                                ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = Appearance.colors.colPrimary
                        ctx.globalAlpha = 0.5
                        ctx.lineWidth = 1.5
                        ctx.setLineDash([4, 9])
                        ctx.stroke()
                        ctx.globalAlpha = 1
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -10
                    spacing: 1
                    z: 2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.timeDisplay
                        font {
                            weight: Font.Black
                            pixelSize: Math.round(Appearance.font.pixelSize.large * 2.6)
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(root.now, "dddd, MMM d")
                        font {
                            weight: Font.DemiBold
                            pixelSize: Appearance.font.pixelSize.small
                        }
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 3
                        spacing: 5

                        MaterialSymbol {
                            text: Icons.getWeatherIcon(
                                Weather.data?.wCode,
                                Weather.isNightNow()) ?? "cloud"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font {
                                weight: Font.DemiBold
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: Weather.data?.description ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }
                    }
                }

                Repeater {
                    id: orbitHours
                    model: orbitalTimeline.hours

                    delegate: Item {
                        id: hourPoint
                        required property int index
                        required property var modelData

                        readonly property int count: Math.max(1, orbitHours.count)
                        readonly property real angle: (-Math.PI / 2)
                            + index * (Math.PI * 2 / count)
                        readonly property bool highlighted: index === 0

                        width: 58
                        height: 72
                        x: orbitalTimeline.width / 2
                            + Math.cos(angle) * orbitalTimeline.radiusX - width / 2
                        y: orbitalTimeline.height / 2
                            + Math.sin(angle) * orbitalTimeline.radiusY - height / 2
                        z: highlighted ? 3 : 1

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.large
                            color: hourPoint.highlighted
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colSurfaceContainerHigh
                            border.width: 1
                            border.color: hourPoint.highlighted
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOutlineVariant

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: hourPoint.modelData?.label ?? ""
                                    font {
                                        weight: Font.DemiBold
                                        pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                    color: hourPoint.highlighted
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurfaceVariant
                                }

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Icons.getWeatherIcon(
                                        hourPoint.modelData?.code,
                                        hourPoint.modelData?.isNight) ?? "cloud"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: hourPoint.highlighted
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurface
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: hourPoint.modelData?.temp ?? ""
                                    font {
                                        weight: Font.DemiBold
                                        pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                    color: hourPoint.highlighted
                                        ? Appearance.colors.colOnPrimaryContainer
                                        : Appearance.colors.colOnSurface
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 82
                    visible: orbitalTimeline.hours.length === 0
                    text: Translation.tr("Hourly forecast unavailable")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
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

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.smaller
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }
    }
}
