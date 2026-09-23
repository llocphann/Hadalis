pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property date now: new Date()
    property bool showUnavailableMessage: true
    // Popup opts into liquid mode explicitly. Dashboard keeps the existing
    // lightweight orbital cards unless a future design intentionally changes it.
    property bool liquidMode: false
    property bool liquidAnimationActive: false
    readonly property var hours: (Weather.data?.hourly ?? []).slice(0, 8)

    readonly property real pointWidth: Math.max(42,
        Math.min(54, width * 0.13))
    readonly property real pointHeight: Math.max(52,
        Math.min(66, height * 0.25))
    readonly property real orbitRadiusX: Math.max(1,
        (width - pointWidth - 18) / 2)
    readonly property real orbitRadiusY: Math.max(1,
        (height - pointHeight - 22) / 2)
    readonly property var hourAngles: {
        const result = []
        for (let i = 0; i < root.hours.length; ++i)
            result.push(root.orbitAngleForHour(root.hours[i]?.label))
        return result
    }
    readonly property bool liquidFallback:
        root.liquidMode && !liquidField.shaderCompiled

    implicitWidth: 360
    implicitHeight: 230

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
        const rx = root.orbitRadiusX
        const ry = root.orbitRadiusY
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
        const hour = root.hourFromLabel(label)
        const shiftedHour = (hour - 6 + 24) % 24
        const quadrant = Math.floor(shiftedHour / 6)
        const fraction = (shiftedHour - quadrant * 6) / 6
        const start = -Math.PI / 2 + quadrant * Math.PI / 2
        const end = start + Math.PI / 2
        return root.arcAngle(start, end, fraction)
    }

    LiquidOrbitalField {
        id: liquidField
        anchors.fill: parent
        z: 0
        visible: root.liquidMode && root.hours.length > 0
        hourAngles: root.hourAngles
        orbitRadiusX: root.orbitRadiusX
        orbitRadiusY: root.orbitRadiusY
        nodeWidth: root.pointWidth
        nodeHeight: root.pointHeight
        activeIndex: 0
        animate: root.liquidAnimationActive
    }

    // Proven lightweight fallback for a software scene graph or a shader
    // compile failure. Normal popup rendering never paints this guide.
    Canvas {
        id: orbitGuide
        anchors.centerIn: parent
        width: Math.max(1, root.orbitRadiusX * 2 + 4)
        height: Math.max(1, root.orbitRadiusY * 2 + 4)
        opacity: 0.42
        visible: !root.liquidMode || root.liquidFallback

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 0 || height <= 0)
                return

            ctx.beginPath()
            for (let angle = 0; angle <= Math.PI * 2 + 0.01; angle += 0.05) {
                const x = width / 2 + Math.cos(angle) * root.orbitRadiusX
                const y = height / 2 + Math.sin(angle) * root.orbitRadiusY
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
        spacing: root.liquidMode ? 2 : 1
        z: 3
        width: Math.min(root.liquidMode ? 190 : 180, root.width * 0.50)

        MaterialSymbol {
            visible: root.liquidMode
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 1
            text: Icons.getWeatherIcon(
                Weather.data?.wCode,
                Weather.isNightNow()) ?? "cloud"
            iconSize: Math.max(24, Appearance.font.pixelSize.larger)
            color: Appearance.colors.colPrimary
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.width >= 380
                ? Qt.formatDate(root.now, "dddd, MMM d")
                : Qt.formatDate(root.now, "ddd, MMM d")
            font.weight: root.liquidMode ? Font.Medium : Font.DemiBold
            font.pixelSize: root.liquidMode
                ? Appearance.font.pixelSize.small
                : Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: root.liquidMode ? 0 : 2
            spacing: 4

            MaterialSymbol {
                visible: !root.liquidMode
                text: Icons.getWeatherIcon(
                    Weather.data?.wCode,
                    Weather.isNightNow()) ?? "cloud"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: Weather.data?.temp ?? "--°"
                font.weight: root.liquidMode ? Font.Medium : Font.DemiBold
                font.pixelSize: root.liquidMode
                    ? Math.max(25, Appearance.font.pixelSize.larger)
                    : Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Weather.data?.description
                ?? Weather.describeWeather(Weather.data?.wCode ?? "113")
            font.pixelSize: root.liquidMode
                ? Appearance.font.pixelSize.smaller
                : Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
        }
    }

    Repeater {
        id: orbitHours
        model: root.hours

        delegate: Item {
            id: hourPoint
            required property int index
            required property var modelData

            readonly property real angle: root.hourAngles[index]
                ?? root.orbitAngleForHour(modelData?.label)
            readonly property bool highlighted: index === 0

            width: root.pointWidth
            height: root.pointHeight
            x: root.width / 2
                + Math.cos(angle) * root.orbitRadiusX - width / 2
            y: root.height / 2
                + Math.sin(angle) * root.orbitRadiusY - height / 2
            z: 4

            Rectangle {
                anchors.fill: parent
                visible: !root.liquidMode || root.liquidFallback
                radius: Appearance.rounding.normal
                color: hourPoint.highlighted
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colSurfaceContainerHigh
                border.width: 1
                border.color: hourPoint.highlighted
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOutlineVariant
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: root.liquidMode ? 2 : 1

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: hourPoint.modelData?.label ?? ""
                    font.weight: hourPoint.highlighted
                        ? Font.DemiBold : Font.Medium
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.liquidMode
                        ? Appearance.colors.colOnSurface
                        : hourPoint.highlighted
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.getWeatherIcon(
                        hourPoint.modelData?.code,
                        hourPoint.modelData?.isNight ?? false) ?? "cloud"
                    iconSize: Math.max(15,
                        Math.min(root.liquidMode ? 21 : 20,
                            hourPoint.width * 0.40))
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: hourPoint.modelData?.temp ?? "--°"
                    font.weight: hourPoint.highlighted
                        ? Font.DemiBold : Font.Medium
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.liquidMode
                        ? Appearance.colors.colOnSurface
                        : hourPoint.highlighted
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnSurface
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 58
        z: 5
        visible: root.showUnavailableMessage && root.hours.length === 0
        text: Translation.tr("Hourly forecast unavailable")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnSurfaceVariant
    }
}
