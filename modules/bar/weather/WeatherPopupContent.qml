import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool compact: false
    readonly property real compactBreakpoint: 900
    readonly property real panelHeight: 270
    readonly property real panelWidth: root.compact ? 360 : 430
    readonly property int tabCount: 2
    readonly property int fadeDuration: Appearance.animation.elementMoveFast.duration
    property int currentTab: 0
    property date now: new Date()

    implicitWidth: root.panelWidth
    implicitHeight: root.panelHeight

    function selectTab(index): void {
        root.currentTab = Math.max(0, Math.min(root.tabCount - 1, index))
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Item {
        id: tabViewport
        anchors.fill: parent

    Rectangle {
        id: timeWeatherPanel
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: "transparent"
        opacity: root.currentTab === 0 ? 1 : 0
        visible: opacity > 0.001
        enabled: root.currentTab === 0
        z: root.currentTab === 0 ? 2 : 1

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.fadeDuration
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: orbitalTimeline
            anchors.fill: parent
            anchors.margins: 8
            anchors.topMargin: -12
            anchors.bottomMargin: 0

            // Serpantinum-inspired frontend: the clock is the visual center
            // and Hadalis hourly data is distributed around an ellipse.
            readonly property var hours: (Weather.data?.hourly ?? []).slice(0, 8)
            // Keep the eight cells clear of one another: smaller cards plus
            // a slightly wider orbit preserve the same composition without
            // the near-touching visual density seen in the runtime pass.
            readonly property real radiusX: Math.max(122, (width - 84) / 2)
            readonly property real radiusY: Math.max(82, (height - 104) / 2)
            // Keep card centres on the same ellipse that is actually painted.
            // The old guide subtracted 2 px only while the cards used the
            // larger radii, which was most visible on the four diagonal hours.
            readonly property real orbitRadiusX: Math.max(1, radiusX - 2)
            readonly property real orbitRadiusY: Math.max(1, radiusY - 2)

            // Parameter-angle spacing is not visually even on a wide ellipse:
            // equal 45° steps produce unequal distances along the orbit. Map
            // each hour to equal arc length instead so all eight cells keep
            // the same perimeter rhythm.
            function orbitAngle(index, count): real {
                if (count <= 1)
                    return -Math.PI / 2

                const samples = 160
                const start = -Math.PI / 2
                const step = Math.PI * 2 / samples
                const rx = orbitalTimeline.orbitRadiusX
                const ry = orbitalTimeline.orbitRadiusY
                const lengths = [0]
                let total = 0
                let prevX = Math.cos(start) * rx
                let prevY = Math.sin(start) * ry

                for (let sample = 1; sample <= samples; ++sample) {
                    const angle = start + sample * step
                    const x = Math.cos(angle) * rx
                    const y = Math.sin(angle) * ry
                    const dx = x - prevX
                    const dy = y - prevY
                    total += Math.sqrt(dx * dx + dy * dy)
                    lengths.push(total)
                    prevX = x
                    prevY = y
                }

                const targetLength = total * (index / count)
                let sample = 1
                while (sample < lengths.length
                        && lengths[sample] < targetLength)
                    ++sample

                const previousLength = lengths[Math.max(0, sample - 1)]
                const segmentLength = Math.max(0.0001,
                    lengths[sample] - previousLength)
                const fraction = (targetLength - previousLength) / segmentLength
                return start + (sample - 1 + fraction) * step
            }

            Canvas {
                id: orbitGuide
                anchors.centerIn: parent
                width: Math.max(1, orbitalTimeline.orbitRadiusX * 2 + 4)
                height: Math.max(1, orbitalTimeline.orbitRadiusY * 2 + 4)
                opacity: 0.42

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.beginPath()
                    const rx = orbitalTimeline.orbitRadiusX
                    const ry = orbitalTimeline.orbitRadiusY
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
                anchors.verticalCenterOffset: 0
                spacing: 1
                z: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(root.now, "dddd, MMM d")
                    font {
                        weight: Font.DemiBold
                        pixelSize: Appearance.font.pixelSize.normal
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
                    readonly property real angle:
                        orbitalTimeline.orbitAngle(index, count)
                    readonly property bool highlighted: index === 0

                    width: 52
                    height: 64
                    x: orbitalTimeline.width / 2
                        + Math.cos(angle) * orbitalTimeline.orbitRadiusX - width / 2
                    y: orbitalTimeline.height / 2
                        + Math.sin(angle) * orbitalTimeline.orbitRadiusY - height / 2
                    z: highlighted ? 3 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
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
                anchors.verticalCenterOffset: 72
                visible: orbitalTimeline.hours.length === 0
                text: Translation.tr("Hourly forecast unavailable")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    Rectangle {
        id: detailPanel
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh
        opacity: root.currentTab === 1 ? 1 : 0
        visible: opacity > 0.001
        enabled: root.currentTab === 1
        z: root.currentTab === 1 ? 2 : 1

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.fadeDuration
                easing.type: Easing.OutCubic
            }
        }

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
                rowSpacing: 4
                columnSpacing: 4
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

    Item {
        id: tabIndicator
        width: 14
        height: indicatorDots.implicitHeight
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        z: 20

        Column {
            id: indicatorDots
            anchors.centerIn: parent
            spacing: 7

            Repeater {
                model: root.tabCount

                delegate: Rectangle {
                    id: indicatorDot
                    required property int index
                    width: 7
                    height: 7
                    radius: width / 2
                    color: indicatorDot.index === root.currentTab
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOutlineVariant
                    opacity: indicatorDot.index === root.currentTab ? 1 : 0.55

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectTab(indicatorDot.index)
                    }
                }
            }
        }
    }

    WheelHandler {
        target: root
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            if (event.angleDelta.y < 0)
                root.selectTab(root.currentTab + 1)
            else if (event.angleDelta.y > 0)
                root.selectTab(root.currentTab - 1)
            event.accepted = true
        }
    }
}
