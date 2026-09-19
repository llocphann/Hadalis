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
    readonly property int slideDuration: Appearance.animation.elementMove.duration
    property int currentTab: 0
    property date now: new Date()
    readonly property real sunProgress: {
        const sunrise = root.timeToMinutes(Weather.data?.sunrise)
        const sunset = root.timeToMinutes(Weather.data?.sunset)
        const current = root.now.getHours() * 60 + root.now.getMinutes()
        if (sunrise < 0 || sunset <= sunrise)
            return 0.5
        return Math.max(0, Math.min(1, (current - sunrise) / (sunset - sunrise)))
    }

    implicitWidth: root.panelWidth
    implicitHeight: root.panelHeight

    function selectTab(index): void {
        root.currentTab = Math.max(0, Math.min(root.tabCount - 1, index))
    }

    function timeToMinutes(value): int {
        const match = String(value ?? "").trim()
            .match(/^(\d{1,2}):(\d{2})(?:\s*([AP]M))?/i)
        if (!match)
            return -1

        let hour = parseInt(match[1], 10)
        const minute = parseInt(match[2], 10)
        const suffix = String(match[3] ?? "").toUpperCase()
        if (suffix === "AM")
            hour = hour === 12 ? 0 : hour
        else if (suffix === "PM")
            hour = hour === 12 ? 12 : hour + 12
        if (isNaN(hour) || isNaN(minute))
            return -1
        return hour * 60 + minute
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
        clip: true

    Rectangle {
        id: timeWeatherPanel
        x: 0
        width: tabViewport.width
        height: tabViewport.height
        radius: Appearance.rounding.large
        color: "transparent"
        y: (0 - root.currentTab) * tabViewport.height
        enabled: root.currentTab === 0

        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.slideDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
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

            // Preserve the real clock anchors while equalizing visual
            // spacing on the ellipse. 06/12/18/00 stay at the four cardinal
            // points. Intermediate times are placed by arc length within each
            // six-hour quadrant, not by raw 45° parameter angles.
            function hourFromLabel(label): real {
                const match = String(label ?? "").match(/^(\d{1,2})(?::(\d{2}))?/)
                if (!match)
                    return 0
                const hour = parseInt(match[1], 10)
                const minute = parseInt(match[2] ?? "0", 10)
                if (isNaN(hour) || isNaN(minute))
                    return 0
                return (((hour % 24) + 24) % 24) + minute / 60
            }

            function arcAngle(startAngle, endAngle, fraction): real {
                if (fraction <= 0)
                    return startAngle
                if (fraction >= 1)
                    return endAngle

                const samples = 72
                const rx = orbitalTimeline.orbitRadiusX
                const ry = orbitalTimeline.orbitRadiusY
                const lengths = [0]
                let total = 0
                let prevX = Math.cos(startAngle) * rx
                let prevY = Math.sin(startAngle) * ry

                for (let sample = 1; sample <= samples; ++sample) {
                    const t = sample / samples
                    const angle = startAngle + (endAngle - startAngle) * t
                    const x = Math.cos(angle) * rx
                    const y = Math.sin(angle) * ry
                    const dx = x - prevX
                    const dy = y - prevY
                    total += Math.sqrt(dx * dx + dy * dy)
                    lengths.push(total)
                    prevX = x
                    prevY = y
                }

                const target = total * fraction
                let sample = 1
                while (sample < lengths.length && lengths[sample] < target)
                    ++sample

                const before = lengths[Math.max(0, sample - 1)]
                const span = Math.max(0.0001, lengths[sample] - before)
                const local = (target - before) / span
                const t = (sample - 1 + local) / samples
                return startAngle + (endAngle - startAngle) * t
            }

            function orbitAngleForHour(label): real {
                const hour = orbitalTimeline.hourFromLabel(label)
                const shiftedHour = (hour - 6 + 24) % 24
                const quadrant = Math.floor(shiftedHour / 6)
                const fraction = (shiftedHour - quadrant * 6) / 6
                const start = -Math.PI / 2 + quadrant * Math.PI / 2
                const end = start + Math.PI / 2
                return orbitalTimeline.arcAngle(start, end, fraction)
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

                    readonly property real angle:
                        orbitalTimeline.orbitAngleForHour(modelData?.label)
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
        x: 0
        width: tabViewport.width
        height: tabViewport.height
        radius: Appearance.rounding.small
        color: "transparent"
        y: (1 - root.currentTab) * tabViewport.height
        enabled: root.currentTab === 1

        Behavior on y {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: root.slideDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        ColumnLayout {
            id: detailColumn
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 24
                topMargin: 12
                bottomMargin: 12
            }
            spacing: 8

            RowLayout {
                id: detailSummary
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: 10

                MaterialSymbol {
                    text: Icons.getWeatherIcon(
                        Weather.data?.wCode,
                        Weather.isNightNow()) ?? "cloud"
                    iconSize: 30
                    color: Appearance.colors.colPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: -1

                    StyledText {
                        text: Weather.data?.temp ?? "--°"
                        color: Appearance.colors.colOnSurface
                        font {
                            pixelSize: 25
                            weight: Font.Medium
                        }
                    }

                    StyledText {
                        text: Translation.tr("Feels like %1")
                            .arg(Weather.data?.tempFeelsLike ?? "--°")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 1

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: Weather.data?.description ?? ""
                        color: Appearance.colors.colOnSurface
                        font {
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.DemiBold
                        }
                        elide: Text.ElideRight
                        Layout.maximumWidth: 150
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: Weather.showVisibleCity
                            ? Weather.visibleCity
                            : Translation.tr("Last refresh: %1")
                                .arg(Weather.data?.lastRefresh ?? "--:--")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                        Layout.maximumWidth: 150
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        visible: Weather.showVisibleCity
                        text: Translation.tr("Last refresh: %1")
                            .arg(Weather.data?.lastRefresh ?? "--:--")
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }
            }

            GridLayout {
                id: primaryMetrics
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 6
                rowSpacing: 0
                uniformCellWidths: true

                PrimaryMetric {
                    title: Translation.tr("Humidity")
                    symbol: "humidity_low"
                    value: Weather.data?.humidity ?? "--"
                }
                PrimaryMetric {
                    title: Translation.tr("Wind")
                    symbol: "air"
                    value: ((Weather.data?.windDir ?? "") + " "
                        + (Weather.data?.wind ?? "--")).trim()
                }
                PrimaryMetric {
                    title: Translation.tr("Precipitation")
                    symbol: "rainy_light"
                    value: Weather.data?.precip ?? "--"
                }
                PrimaryMetric {
                    title: Translation.tr("UV Index")
                    symbol: "wb_sunny"
                    value: Weather.data?.uv ?? "--"
                }
            }

            Rectangle {
                id: secondaryStrip
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    SecondaryMetric {
                        Layout.fillWidth: true
                        title: Translation.tr("Visibility")
                        symbol: "visibility"
                        value: Weather.data?.visib ?? "--"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 18
                        color: Appearance.colors.colOutlineVariant
                    }

                    SecondaryMetric {
                        Layout.fillWidth: true
                        title: Translation.tr("Pressure")
                        symbol: "readiness_score"
                        value: Weather.data?.press ?? "--"
                    }
                }
            }

            Rectangle {
                id: sunTimeline
                Layout.fillWidth: true
                implicitHeight: 62
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh

                MaterialSymbol {
                    id: sunriseIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: "wb_twilight"
                    iconSize: 16
                    color: Appearance.colors.colPrimary
                }

                MaterialSymbol {
                    id: sunsetIcon
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: "bedtime"
                    iconSize: 16
                    color: Appearance.colors.colPrimary
                }

                Rectangle {
                    id: sunTrack
                    anchors.left: sunriseIcon.right
                    anchors.right: sunsetIcon.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: sunriseIcon.verticalCenter
                    height: 2
                    radius: 1
                    color: Appearance.colors.colOutlineVariant

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        x: Math.max(0, Math.min(parent.width - width,
                            root.sunProgress * parent.width - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        color: Appearance.colors.colPrimary
                        border.width: 1
                        border.color: Appearance.colors.colSurface
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: Weather.data?.sunrise ?? "--:--"
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: Translation.tr("Sun")
                    color: Appearance.colors.colOnSurfaceVariant
                    font {
                        pixelSize: Appearance.font.pixelSize.smallest
                        weight: Font.DemiBold
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: Weather.data?.sunset ?? "--:--"
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }
    }
    }

    component PrimaryMetric: Rectangle {
        id: primaryMetric
        required property string title
        required property string symbol
        required property string value

        Layout.fillWidth: true
        implicitHeight: 58
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                MaterialSymbol {
                    text: primaryMetric.symbol
                    iconSize: 15
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    text: primaryMetric.title.toUpperCase()
                    color: Appearance.colors.colOnSurfaceVariant
                    font {
                        pixelSize: Appearance.font.pixelSize.smallest
                        weight: Font.DemiBold
                        letterSpacing: 0.5
                    }
                    elide: Text.ElideRight
                    Layout.maximumWidth: 70
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: primaryMetric.value
                color: Appearance.colors.colOnSurface
                font {
                    pixelSize: Appearance.font.pixelSize.small
                    weight: Font.DemiBold
                }
                elide: Text.ElideRight
                Layout.maximumWidth: 82
            }
        }
    }

    component SecondaryMetric: RowLayout {
        id: secondaryMetric
        required property string title
        required property string symbol
        required property string value
        spacing: 5

        MaterialSymbol {
            text: secondaryMetric.symbol
            iconSize: 15
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            text: secondaryMetric.title
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smallest
        }

        Item { Layout.fillWidth: true }

        StyledText {
            text: secondaryMetric.value
            color: Appearance.colors.colOnSurface
            font {
                pixelSize: Appearance.font.pixelSize.smaller
                weight: Font.DemiBold
            }
        }
    }

    Item {
        id: tabIndicator
        width: 14
        height: indicatorDots.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: 4
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
