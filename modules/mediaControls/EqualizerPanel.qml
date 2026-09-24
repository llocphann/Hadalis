pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services.deferred

Item {
    id: root

    property bool active: false
    property bool compactLayout: false
    property bool _registered: false
    property int _editingBand: -1

    readonly property color eqAccentColor: Appearance.colors.colPrimary
    implicitHeight: root.compactLayout ? 202 : 226
    clip: root.compactLayout

    function syncRegistration(): void {
        if (root.active && !root._registered) {
            EqualizerService.registerConsumer()
            root._registered = true
        } else if (!root.active && root._registered) {
            EqualizerService.unregisterConsumer()
            root._registered = false
        }
    }

    function statusText(): string {
        if (EqualizerService.busy)
            return "Applying…"
        if (EqualizerService.dspControlAvailable)
            return EqualizerService.dspPresetName || "Custom"
        switch (EqualizerService.error) {
        case "backend-not-running":
            return "EasyEffects stopped"
        case "backend-unavailable":
            return "EasyEffects unavailable"
        case "transport-unavailable":
        case "transport-probe-failed":
            return "EQ transport unavailable"
        case "dsp-unavailable":
            return "10-band DSP unavailable"
        case "dsp-state-read-failed":
        case "malformed-dsp-state":
            return "DSP state unavailable"
        case "dsp-apply-failed":
            return "Apply failed"
        default:
            return EqualizerService.error.length > 0
                ? EqualizerService.error : "Loading…"
        }
    }

    function gainToY(gain, height): real {
        const clamped = Math.max(
            EqualizerService.dspMinimumBandGain,
            Math.min(EqualizerService.dspMaximumBandGain,
                     Number(gain) || 0))
        const range = EqualizerService.dspMaximumBandGain
            - EqualizerService.dspMinimumBandGain
        if (range <= 0)
            return height / 2

        // Match the real Slider handle-center travel, so dB guide lines,
        // fallback curve points and draggable nodes share exactly one y scale.
        const inset = root.compactLayout ? 11.5 : 13.5
        const usableHeight = Math.max(1, height - inset * 2)
        return inset
            + (EqualizerService.dspMaximumBandGain - clamped)
                / range * usableHeight
    }

    function requestGraphPaint(): void {
        analyzerCanvas.requestPaint()
    }

    function applyPreset(name): void {
        if (EqualizerService.applyDspPreset(name))
            analyzerCanvas.requestPaint()
    }

    onActiveChanged: {
        root.syncRegistration()
        if (active)
            analyzerCanvas.requestPaint()
    }

    Connections {
        target: EqualizerService

        function onDspBandsChanged(): void {
            analyzerCanvas.requestPaint()
        }
    }

    Component.onCompleted: {
        root.syncRegistration()
        analyzerCanvas.requestPaint()
    }

    Component.onDestruction: {
        if (root._registered)
            EqualizerService.unregisterConsumer()
    }

    // The DSP surface is also a CAVA consumer. CavaProcess is only a lightweight
    // subscription wrapper; CavaService still owns the single shared process.
    // This lets every EqualizerPanel render the same real audio spectrum without
    // creating a second analyzer subprocess.
    CavaProcess {
        id: eqCava
        active: root.active
        sampleCount: 64
    }

    Connections {
        target: eqCava

        function onPointsChanged(): void {
            analyzerCanvas.requestPaint()
        }

        function onNormalizationCeilingChanged(): void {
            analyzerCanvas.requestPaint()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.compactLayout ? 6 : 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer2
            opacity: 0.45
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compactLayout ? 6 : 8
            Layout.rightMargin: root.compactLayout ? 6 : 8
            spacing: root.compactLayout ? 6 : 8

            StyledText {
                text: "Equalizer"
                font.pixelSize: root.compactLayout
                    ? Appearance.font.pixelSize.small
                    : Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colPrimary
                Layout.fillWidth: true
            }

            RippleButton {
                visible: EqualizerService.error === "backend-not-running"
                implicitWidth: 52
                implicitHeight: 24
                buttonText: "Start"
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: EqualizerService.startBackend()
            }

            Rectangle {
                implicitWidth: Math.max(48, statusLabel.implicitWidth + 14)
                implicitHeight: 24
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer2

                StyledText {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: root.statusText()
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    color: EqualizerService.dspControlAvailable
                        ? Appearance.colors.colSubtext
                        : Appearance.colors.colError
                }
            }
        }

        Rectangle {
            id: graphFrame
            Layout.fillWidth: true
            Layout.preferredHeight: root.compactLayout ? 112 : 132
            Layout.leftMargin: root.compactLayout ? 3 : 4
            Layout.rightMargin: root.compactLayout ? 3 : 4
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer2
            clip: true

            readonly property real leftGutter:
                root.compactLayout ? 32 : 36
            readonly property real rightGutter: 5
            readonly property real topGutter: 6
            readonly property real bottomGutter:
                root.compactLayout ? 17 : 19

            Item {
                id: plotArea
                x: graphFrame.leftGutter
                y: graphFrame.topGutter
                width: Math.max(1, graphFrame.width
                    - graphFrame.leftGutter - graphFrame.rightGutter)
                height: Math.max(1, graphFrame.height
                    - graphFrame.topGutter - graphFrame.bottomGutter)

                Canvas {
                    id: analyzerCanvas
                    anchors.fill: parent
                    z: 0

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (width <= 0 || height <= 0)
                            return

                        const bands = EqualizerService.dspBands ?? []

                        function yForGain(gain) {
                            return root.gainToY(gain, height)
                        }

                        // Real CAVA spectrum. Two restrained passes give each
                        // bar enough presence behind the response curve without
                        // turning the DSP control into a second visualizer card.
                        const spectrum = eqCava.points ?? []
                        const ceiling = Math.max(
                            1, Number(eqCava.normalizationCeiling) || 1)
                        if (spectrum.length > 0) {
                            const slot = width / spectrum.length
                            const haloWidth = Math.max(1, slot * 0.82)
                            const coreWidth = Math.max(1, slot * 0.52)

                            ctx.fillStyle = root.eqAccentColor
                            for (let i = 0; i < spectrum.length; ++i) {
                                const amplitude = Math.max(0, Math.min(1,
                                    (Number(spectrum[i]) || 0) / ceiling))
                                const barHeight = Math.max(
                                    1, amplitude * height * 0.94)
                                const center = (i + 0.5) * slot

                                ctx.globalAlpha = 0.07 + amplitude * 0.10
                                ctx.fillRect(center - haloWidth / 2,
                                    height - barHeight, haloWidth, barHeight)

                                ctx.globalAlpha = 0.18 + amplitude * 0.28
                                ctx.fillRect(center - coreWidth / 2,
                                    height - barHeight, coreWidth, barHeight)
                            }
                        }

                        // Shared dB/frequency grid.
                        ctx.strokeStyle = Appearance.colors.colLayer2
                        ctx.lineWidth = 1
                        ctx.globalAlpha = 0.48
                        const gridGains = [12, 6, 0, -6, -12]
                        for (let i = 0; i < gridGains.length; ++i) {
                            const y = yForGain(gridGains[i])
                            ctx.beginPath()
                            ctx.moveTo(0, y)
                            ctx.lineTo(width, y)
                            ctx.stroke()
                        }
                        for (let i = 0; i < 10; ++i) {
                            const x = (i + 0.5) * width / 10
                            ctx.beginPath()
                            ctx.moveTo(x, 0)
                            ctx.lineTo(x, height)
                            ctx.stroke()
                        }

                        // Read the actual rendered EQ handles so the response
                        // curve and the draggable nodes can never drift apart.
                        const points = []
                        for (let i = 0; i < 10; ++i) {
                            const delegate = bandRepeater.itemAt(i)
                            if (delegate) {
                                const mapped = delegate.curvePoint()
                                points.push({ x: mapped.x, y: mapped.y })
                            } else {
                                const gain = Number(bands[i]?.gain) || 0
                                points.push({
                                    x: (i + 0.5) * width / 10,
                                    y: yForGain(gain)
                                })
                            }
                        }

                        function traceCurve() {
                            if (points.length === 0)
                                return
                            ctx.beginPath()
                            ctx.moveTo(points[0].x, points[0].y)
                            for (let i = 0; i < points.length - 1; ++i) {
                                const p0 = points[Math.max(0, i - 1)]
                                const p1 = points[i]
                                const p2 = points[i + 1]
                                const p3 = points[
                                    Math.min(points.length - 1, i + 2)]
                                ctx.bezierCurveTo(
                                    p1.x + (p2.x - p0.x) / 6,
                                    p1.y + (p2.y - p0.y) / 6,
                                    p2.x - (p3.x - p1.x) / 6,
                                    p2.y - (p3.y - p1.y) / 6,
                                    p2.x, p2.y)
                            }
                            ctx.stroke()
                        }

                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"

                        ctx.strokeStyle = root.eqAccentColor
                        ctx.lineWidth = root.compactLayout ? 5 : 6
                        ctx.globalAlpha = 0.18
                        traceCurve()

                        ctx.strokeStyle = Qt.lighter(root.eqAccentColor, 1.18)
                        ctx.lineWidth = root.compactLayout ? 2.1 : 2.4
                        ctx.globalAlpha = 0.82
                        traceCurve()

                        ctx.strokeStyle = "#ffffff"
                        ctx.lineWidth = 0.8
                        ctx.globalAlpha = 0.72
                        traceCurve()

                        ctx.globalAlpha = 1.0
                    }
                }

                Row {
                    id: bandControlRow
                    anchors.fill: parent
                    spacing: 0
                    z: 2

                    Repeater {
                        id: bandRepeater
                        model: EqualizerService.dspBands

                        delegate: Item {
                            id: bandDelegate
                            required property var modelData
                            required property int index
                            width: parent.width / 10
                            height: parent.height
                            readonly property real backendGain:
                                Number(modelData?.gain) || 0

                            function curvePoint() {
                                const handleItem = bandSlider.handle
                                if (!handleItem) {
                                    return Qt.point(
                                        bandDelegate.width / 2
                                            + bandDelegate.x,
                                        bandDelegate.height / 2)
                                }
                                return handleItem.mapToItem(
                                    analyzerCanvas,
                                    handleItem.width / 2,
                                    handleItem.height / 2)
                            }

                            Rectangle {
                                id: responseStem
                                z: 1
                                width: 1
                                radius: 0.5
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: bandSlider.handle
                                    ? bandSlider.handle.y
                                        + bandSlider.handle.height / 2
                                    : parent.height / 2
                                height: Math.max(0, parent.height - y)
                                color: Appearance.colors.colPrimary
                                opacity: bandSlider.enabled ? 0.24 : 0.10
                            }

                            Slider {
                                id: bandSlider
                                z: 2
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    horizontalCenter: parent.horizontalCenter
                                }
                                width: root.compactLayout ? 20 : 24
                                orientation: Qt.Vertical
                                from: EqualizerService.dspMinimumBandGain
                                to: EqualizerService.dspMaximumBandGain
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                hoverEnabled: true
                                enabled: EqualizerService.dspControlAvailable
                                    && !EqualizerService.busy
                                topPadding: root.compactLayout ? 6 : 7
                                bottomPadding: topPadding
                                leftPadding: 0
                                rightPadding: 0
                                value: bandDelegate.backendGain

                                onPressedChanged: {
                                    if (pressed) {
                                        root._editingBand = bandDelegate.index
                                    } else if (enabled) {
                                        const rounded = Math.round(value)
                                        EqualizerService.setDspBandGain(
                                            bandDelegate.index, rounded)
                                        root._editingBand = -1
                                        analyzerCanvas.requestPaint()
                                    }
                                }

                                onMoved: {
                                    value = Math.round(value)
                                    analyzerCanvas.requestPaint()
                                }

                                Connections {
                                    target: EqualizerService
                                    function onDspBandsChanged(): void {
                                        if (!bandSlider.pressed)
                                            bandSlider.value =
                                                bandDelegate.backendGain
                                        analyzerCanvas.requestPaint()
                                    }
                                }

                                background: Item {}

                                handle: Rectangle {
                                    x: bandSlider.leftPadding
                                        + (bandSlider.availableWidth - width) / 2
                                    y: bandSlider.topPadding
                                        + bandSlider.visualPosition
                                            * (bandSlider.availableHeight - height)
                                    implicitWidth:
                                        root.compactLayout ? 11 : 13
                                    implicitHeight: implicitWidth
                                    radius: width / 2
                                    color: bandSlider.pressed
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colLayer0
                                    border.width: 1
                                    border.color: Appearance.colors.colPrimary
                                    scale: bandSlider.pressed ? 1.16
                                        : (bandSlider.hovered ? 1.08 : 1.0)

                                    HoverHandler {
                                        cursorShape: bandSlider.enabled
                                            ? (bandSlider.pressed
                                                ? Qt.ClosedHandCursor
                                                : Qt.SizeVerCursor)
                                            : Qt.ArrowCursor
                                    }

                                    Behavior on scale {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration:
                                                Appearance.animation
                                                    .elementMoveFast.duration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: [12, 6, 0, -6, -12]

                delegate: StyledText {
                    required property real modelData
                    x: 15
                    y: plotArea.y
                        + root.gainToY(modelData, plotArea.height)
                        - height / 2
                    text: modelData > 0 ? "+" + modelData : String(modelData)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    opacity: 0.78
                }
            }

            StyledText {
                x: 2
                y: plotArea.y + root.gainToY(0, plotArea.height)
                    - height / 2
                text: "dB"
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                opacity: 0.78
            }

            Row {
                x: plotArea.x
                y: plotArea.y + plotArea.height
                width: plotArea.width
                height: graphFrame.bottomGutter
                spacing: 0

                Repeater {
                    model: EqualizerService.dspBands

                    delegate: Item {
                        required property var modelData
                        width: parent.width / 10
                        height: parent.height

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData?.label ?? ""
                            font.pixelSize:
                                Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 6
                    rightMargin: 6
                }
                implicitWidth: root.compactLayout ? 42 : 46
                implicitHeight: 20
                radius: height / 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer2
                z: 5

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.colors.colPrimary
                        opacity: eqCava.audioSignalActive ? 1.0 : 0.35
                    }

                    StyledText {
                        text: "Live"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                        opacity: eqCava.audioSignalActive ? 1.0 : 0.58
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compactLayout ? 4 : 6
            Layout.rightMargin: root.compactLayout ? 4 : 6
            Layout.topMargin: 1
            columns: 4
            uniformCellWidths: true
            columnSpacing: root.compactLayout ? 3 : 4
            rowSpacing: root.compactLayout ? 3 : 4

            Repeater {
                model: ["Flat", "Bass", "Treble", "Vocal",
                        "Pop", "Rock", "Jazz", "Classic"]

                delegate: RippleButton {
                    id: presetButton
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: root.compactLayout ? 22 : 24
                    horizontalPadding: root.compactLayout ? 3 : 4
                    buttonText: modelData
                    buttonRadius: Appearance.rounding.small
                    enabled: EqualizerService.dspControlAvailable
                        && !EqualizerService.busy
                    toggled: EqualizerService.dspPresetName === modelData
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colBackgroundToggled:
                        Appearance.colors.colPrimaryContainer
                    colBackgroundToggledHover:
                        Appearance.colors.colPrimaryContainer
                    onClicked: root.applyPreset(modelData)

                    contentItem: StyledText {
                        text: presetButton.modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: presetButton.toggled
                            ? Font.DemiBold : Font.Normal
                        color: presetButton.toggled
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
