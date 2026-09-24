pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property date now: new Date()
    property bool showUnavailableMessage: true
    property bool liquidMode: false
    property bool liquidAnimationActive: false
    property int activeIndex: 0
    readonly property var hours: (Weather.data?.hourly ?? []).slice(0, 8)
    readonly property real orbitStageHeight: Math.max(1, height)

    // Measured from the supplied concept: the node-centre ellipse is only
    // ~1.168x wider than tall. Do not stretch the orbit to the full popup width.
    readonly property real conceptOrbitAspect: 1.168
    // The measured concept ratios are more important than filling the popup:
    // centres sit at ~24.5% of the reference width and inactive pods are only
    // ~8.6% of that width. Keeping those ratios preserves the large calm hole
    // in the middle instead of crowding the weather summary.
    readonly property real pointSize: Math.max(38,
        Math.min(132, width * 0.086, root.orbitStageHeight * 0.15))
    readonly property real pointWidth: root.liquidMode
        ? pointSize
        : Math.max(42, Math.min(54, width * 0.13))
    readonly property real pointHeight: root.liquidMode
        ? pointSize
        : Math.max(52, Math.min(66, height * 0.25))
    readonly property real activePointSize: pointSize * 1.28
    readonly property real desiredOrbitRadiusX: width * 0.245
    readonly property real desiredOrbitRadiusY:
        desiredOrbitRadiusX / conceptOrbitAspect
    readonly property real liquidOrbitRadiusY: Math.max(1,
        Math.min(desiredOrbitRadiusY,
            (orbitStageHeight - activePointSize - 10) / 2))
    readonly property real orbitRadiusY: root.liquidMode
        ? liquidOrbitRadiusY
        : Math.max(1, (height - pointHeight - 22) / 2)
    readonly property real orbitRadiusX: root.liquidMode
        ? liquidOrbitRadiusY * conceptOrbitAspect
        : Math.max(1, (width - pointWidth - 18) / 2)
    readonly property var hourAngles: {
        const result = []
        for (let i = 0; i < root.hours.length; ++i)
            result.push(root.orbitAngleForHour(root.hours[i]?.label))
        return result
    }

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
        // The reference places the 3-hour buckets on exact 45° parametric
        // positions. Keep Dashboard's older equal-arc placement, but use the
        // reference geometry in popup liquid mode.
        if (root.liquidMode)
            return -Math.PI / 2 + shiftedHour * Math.PI / 12
        const start = -Math.PI / 2 + quadrant * Math.PI / 2
        const end = start + Math.PI / 2
        return root.arcAngle(start, end, fraction)
    }

    LiquidOrbitalField {
        id: liquidField
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: root.orbitStageHeight
        z: 0
        visible: root.liquidMode && root.hours.length > 0
        hourAngles: root.hourAngles
        orbitRadiusX: root.orbitRadiusX
        orbitRadiusY: root.orbitRadiusY
        nodeWidth: root.pointSize
        nodeHeight: root.pointSize
        activeIndex: root.activeIndex
        animate: root.liquidAnimationActive
    }

    Canvas {
        id: orbitGuide
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.orbitStageHeight / 2 - height / 2
        width: Math.max(1, root.orbitRadiusX * 2 + 4)
        height: Math.max(1, root.orbitRadiusY * 2 + 4)
        opacity: 0.42
        visible: !root.liquidMode

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
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.orbitStageHeight / 2 - height / 2
        spacing: root.liquidMode ? Math.max(2, width * 0.006) : 1
        z: 3
        width: Math.min(root.liquidMode ? 560 : 180, root.width * 0.54)

        MaterialSymbol {
            visible: root.liquidMode
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 1
            text: Icons.getWeatherIcon(
                Weather.data?.wCode,
                Weather.isNightNow()) ?? "cloud"
            iconSize: Math.max(30, Math.min(96,
                root.width * 0.07, root.orbitStageHeight * 0.11))
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
                ? Math.max(Appearance.font.pixelSize.small,
                    Math.min(31, root.width * 0.022,
                        root.orbitStageHeight * 0.038))
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
                    ? Math.max(30, Math.min(68, root.width * 0.048,
                        root.orbitStageHeight * 0.075))
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
                ? Math.max(Appearance.font.pixelSize.smaller,
                    Math.min(29, root.width * 0.021,
                        root.orbitStageHeight * 0.035))
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
            readonly property bool highlighted: index === root.activeIndex
            readonly property real bubbleSize: highlighted && root.liquidMode
                ? root.activePointSize : root.pointSize

            width: root.liquidMode ? bubbleSize : root.pointWidth
            height: root.liquidMode ? bubbleSize : root.pointHeight
            x: root.width / 2 + Math.cos(angle) * root.orbitRadiusX - width / 2
            y: root.orbitStageHeight / 2
                + Math.sin(angle) * root.orbitRadiusY - height / 2
            z: highlighted ? 6 : 4

            Rectangle {
                anchors.fill: parent
                visible: !root.liquidMode
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
                spacing: root.liquidMode ? Math.max(1, root.pointSize * 0.035) : 1

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: hourPoint.modelData?.label ?? ""
                    font.weight: hourPoint.highlighted
                        ? Font.DemiBold : Font.Medium
                    font.pixelSize: root.liquidMode
                        ? Math.max(Appearance.font.pixelSize.smallest + 1,
                            Math.min(23, root.pointSize * 0.18))
                        : Appearance.font.pixelSize.smallest
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
                        Math.min(root.liquidMode ? 46 : 20,
                            hourPoint.width * 0.38))
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: hourPoint.modelData?.temp ?? "--°"
                    font.weight: hourPoint.highlighted
                        ? Font.DemiBold : Font.Medium
                    font.pixelSize: root.liquidMode
                        ? Math.max(Appearance.font.pixelSize.smallest + 1,
                            Math.min(24, root.pointSize * 0.19))
                        : Appearance.font.pixelSize.smallest
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
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.orbitStageHeight / 2 + 58 - height / 2
        z: 5
        visible: root.showUnavailableMessage && root.hours.length === 0
        text: Translation.tr("Hourly forecast unavailable")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnSurfaceVariant
    }
}
