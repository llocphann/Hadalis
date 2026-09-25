import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool compact: false
    readonly property real compactBreakpoint: 900
    readonly property real panelHeight: root.compact ? 270 : 300
    // Keep one stable connected-surface width for both tabs. Detailed Weather
    // reflows at narrow widths instead of forcing the whole popup to stay wide.
    readonly property real panelWidth: root.compact ? 360 : 390
    // Let the liquid orbit consume the popup body instead of inheriting the
    // detail-page inset. Keep only a small safety gutter, with extra room on
    // the right for the persistent tab indicator rail.
    readonly property real orbitalInset: root.compact ? 6 : 8
    readonly property real orbitalRightInset: root.orbitalInset
    readonly property int tabCount: 2
    readonly property int slideDuration: Appearance.animation.elementMove.duration
    property int currentTab: 0
    // StyledPopup keeps this content item instantiated even while its lazy
    // presentation window is unloaded. Standalone callers keep the historical
    // always-active behavior unless a host supplies a presentation lifecycle.
    property bool presentationActive: true
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
        running: root.presentationActive
        triggeredOnStart: true
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

        OrbitalWeather {
            id: orbitalTimeline
            anchors {
                fill: parent
                leftMargin: root.orbitalInset
                rightMargin: root.orbitalRightInset
                topMargin: root.orbitalInset
                bottomMargin: root.orbitalInset
            }
            now: root.now
            liquidMode: true
            // Keep the field alive while its page is still visibly sliding out;
            // stop it only after the clipped page has fully left the viewport.
            liquidAnimationActive: root.currentTab === 0
                || timeWeatherPanel.y > -timeWeatherPanel.height + 1
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
                leftMargin: root.compact ? 10 : 12
                rightMargin: root.compact ? 22 : 24
                topMargin: root.compact ? 10 : 12
                bottomMargin: root.compact ? 10 : 12
            }
            spacing: root.compact ? 6 : 7

            RowLayout {
                id: detailSummary
                Layout.fillWidth: true
                Layout.preferredHeight: root.compact ? 44 : 46
                spacing: root.compact ? 8 : 10

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
                        Layout.maximumWidth: root.compact ? 118 : 130
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
                        Layout.maximumWidth: root.compact ? 118 : 130
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
                columns: 2
                columnSpacing: 6
                rowSpacing: root.compact ? 4 : 6
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
                implicitHeight: root.compact ? 32 : 34
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
                implicitHeight: root.compact ? 52 : 56
                radius: Appearance.rounding.small
                color: Appearance.colors.colSurfaceContainerHigh

                MaterialSymbol {
                    id: sunriseIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: root.compact ? 7 : 8
                    text: "wb_twilight"
                    iconSize: 16
                    color: Appearance.colors.colPrimary
                }

                MaterialSymbol {
                    id: sunsetIcon
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: root.compact ? 7 : 8
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
                        border.color: Appearance.colors.colLayer2
                    }
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.compact ? 6 : 7
                    text: Weather.data?.sunrise ?? "--:--"
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.compact ? 6 : 7
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
                    anchors.bottomMargin: root.compact ? 6 : 7
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
        implicitHeight: root.compact ? 36 : 42
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 9
                rightMargin: 9
            }
            spacing: 7

            MaterialSymbol {
                text: primaryMetric.symbol
                iconSize: 15
                color: Appearance.colors.colOnSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: -1

                StyledText {
                    Layout.fillWidth: true
                    text: primaryMetric.title.toUpperCase()
                    color: Appearance.colors.colOnSurfaceVariant
                    font {
                        pixelSize: Appearance.font.pixelSize.smallest
                        weight: Font.DemiBold
                        letterSpacing: 0.4
                    }
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: primaryMetric.value
                    color: Appearance.colors.colOnSurface
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        weight: Font.DemiBold
                    }
                    elide: Text.ElideRight
                }
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
