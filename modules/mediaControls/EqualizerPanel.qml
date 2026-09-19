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
    property bool _registered: false
    // The DSP curve always carries a compact electric trace. Interaction only
    // raises luminance/contrast; stroke widths and jitter amplitude never grow.
    property real eqLightningHighlight: 0.0
    property real eqPresetSweepProgress: -0.12
    property int _editingBand: -1
    property var _lightningGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    readonly property color eqAccentColor: Appearance.colors.colPrimary
    implicitHeight: 214

    function syncLightningGains(): void {
        const source = EqualizerService.dspBands ?? []
        const gains = []
        for (let i = 0; i < 10; ++i)
            gains.push(Number(source[i]?.gain) || 0)
        root._lightningGains = gains
        lightningCanvas.requestPaint()
    }

    function setLightningGain(index, gain): void {
        const gains = (root._lightningGains ?? []).slice()
        while (gains.length < 10)
            gains.push(0)
        gains[index] = Math.round(Number(gain) || 0)
        root._lightningGains = gains
        lightningCanvas.requestPaint()
    }

    function triggerEqLightning(): void {
        eqLightningAnim.restart()
    }

    function triggerPresetSweep(): void {
        presetSweepAnim.restart()
    }

    function beginBandLightning(index, gain): void {
        eqLightningAnim.stop()
        root._editingBand = index
        root.eqLightningHighlight = 1.0
        root.setLightningGain(index, gain)
    }

    function previewBandLightning(index, gain): void {
        root.eqLightningHighlight = 1.0
        root.setLightningGain(index, gain)
    }

    function endBandLightning(index, gain): void {
        root.setLightningGain(index, gain)
        root._editingBand = -1
        root.triggerEqLightning()
    }

    function applyPresetWithLightning(name): void {
        const curve = EqualizerService.dspPresetCurves[name]
        if (!curve)
            return
        if (EqualizerService.applyDspPreset(name)) {
            root._lightningGains = curve.slice()
            lightningCanvas.requestPaint()
            root.triggerPresetSweep()
        }
    }

    SequentialAnimation {
        id: presetSweepAnim
        running: false

        ScriptAction {
            script: root.eqPresetSweepProgress = -0.12
        }

        NumberAnimation {
            target: root
            property: "eqPresetSweepProgress"
            from: -0.12
            to: 1.16
            duration: Appearance.animationsEnabled ? 860 : 1
            easing.type: Easing.InOutCubic
        }

        ScriptAction {
            script: root.eqPresetSweepProgress = -0.12
        }
    }

    SequentialAnimation {
        id: eqLightningAnim
        running: false
        ScriptAction {
            script: root.eqLightningHighlight = 1.0
        }
        PauseAnimation { duration: 120 }
        NumberAnimation {
            target: root
            property: "eqLightningHighlight"
            from: 1.0
            to: 0.0
            duration: Appearance.animationsEnabled ? 720 : 1
            easing.type: Easing.OutCubic
        }
    }

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
            return EqualizerService.error.length > 0 ? EqualizerService.error : "Loading…"
        }
    }

    onActiveChanged: {
        root.syncRegistration()
        if (active) {
            root.syncLightningGains()
            lightningCanvas.requestPaint()
        }
    }

    Connections {
        target: EqualizerService

        function onDspBandsChanged(): void {
            if (root._editingBand < 0)
                root.syncLightningGains()
        }
    }

    Component.onCompleted: {
        root.syncRegistration()
        root.syncLightningGains()
    }
    Component.onDestruction: {
        if (root._registered)
            EqualizerService.unregisterConsumer()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer2
            opacity: 0.45
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8

            StyledText {
                text: "Equalizer"
                font.pixelSize: Appearance.font.pixelSize.normal
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

            StyledText {
                text: root.statusText()
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: EqualizerService.dspControlAvailable
                    ? Appearance.colors.colSubtext
                    : Appearance.colors.colError
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            Layout.leftMargin: 4
            Layout.rightMargin: 4

            Canvas {
                id: lightningCanvas
                anchors.fill: parent
                z: 0
                opacity: 1.0
                visible: true

                Timer {
                    interval: 33
                    running: root.active && lightningCanvas.visible
                    repeat: true
                    onTriggered: lightningCanvas.requestPaint()
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (width <= 0 || height <= 0)
                        return

                    const gains = root._lightningGains ?? []
                    const points = []
                    for (let i = 0; i < 10; ++i) {
                        const delegate = bandRepeater.itemAt(i)
                        if (delegate) {
                            const mapped = delegate.lightningPoint()
                            points.push({ x: mapped.x, y: mapped.y })
                            continue
                        }

                        // Construction-time fallback only. Once delegates exist,
                        // the trace is mapped from the real handle centers below.
                        const gain = Number(gains[i] ?? 0)
                        const normalized = 1.0
                            - ((Math.max(-12, Math.min(12, gain)) + 12) / 24)
                        points.push({
                            x: (i + 0.5) * (width / 10),
                            y: 8 + normalized * Math.max(1, height - 24)
                        })
                    }

                    const highlight = Math.max(0,
                        Math.min(1, root.eqLightningHighlight))
                    const sweep = root.eqPresetSweepProgress
                    const now = Date.now() / 1000
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"

                    function sampledTrace(stroke) {
                        const samples = [{ x: points[0].x, y: points[0].y }]
                        for (let i = 0; i < points.length - 1; ++i) {
                            const p1 = points[i]
                            const p2 = points[i + 1]
                            const steps = stroke === 2 ? 6 : 8
                            for (let j = 1; j <= steps; ++j) {
                                const t = j / steps
                                const envelope = Math.sin(t * Math.PI)
                                const x = p1.x + (p2.x - p1.x) * t
                                const y = p1.y + (p2.y - p1.y) * t
                                const amplitudeX = stroke === 0 ? 2.2
                                    : (stroke === 1 ? 1.2 : 0.55)
                                const amplitudeY = stroke === 0 ? 2.8
                                    : (stroke === 1 ? 1.55 : 0.7)
                                const noiseX = Math.sin(now * (6.5 + stroke) + i + j)
                                    * Math.cos(now * 5.2 - i + j)
                                    * amplitudeX * envelope
                                const noiseY = Math.cos(now * (6.1 - stroke * 0.4) + i - j)
                                    * Math.sin(now * 4.8 + i - j)
                                    * amplitudeY * envelope
                                samples.push({ x: x + noiseX, y: y + noiseY })
                            }
                        }
                        return samples
                    }

                    function strokeTrace(samples) {
                        ctx.beginPath()
                        ctx.moveTo(samples[0].x, samples[0].y)
                        for (let i = 1; i < samples.length; ++i)
                            ctx.lineTo(samples[i].x, samples[i].y)
                        ctx.stroke()
                    }

                    // Three compact strokes form the always-on current. Direct
                    // band edits raise global luminance only; geometry is fixed.
                    const traces = []
                    for (let stroke = 0; stroke < 3; ++stroke) {
                        const samples = sampledTrace(stroke)
                        traces.push(samples)

                        if (stroke === 0) {
                            ctx.lineWidth = 5.5
                            ctx.strokeStyle = root.eqAccentColor
                            ctx.globalAlpha = 0.16 + highlight * 0.14
                        } else if (stroke === 1) {
                            ctx.lineWidth = 2.4
                            ctx.strokeStyle = Qt.lighter(root.eqAccentColor,
                                1.12 + highlight * 0.28)
                            ctx.globalAlpha = 0.40 + highlight * 0.34
                        } else {
                            ctx.lineWidth = 1.0
                            ctx.strokeStyle = "#ffffff"
                            ctx.globalAlpha = 0.55 + highlight * 0.45
                        }
                        strokeTrace(samples)
                    }

                    // Presets get a distinct charge sweep. The moving head has
                    // a short luminous tail and redraws the exact same sampled
                    // geometry at the exact same widths, so it never grows the
                    // current — it only brightens successive sections left→right.
                    if (sweep >= -0.12 && sweep <= 1.16) {
                        const sweepTail = 0.22
                        const sweepLead = 0.035

                        for (let stroke = 0; stroke < traces.length; ++stroke) {
                            const samples = traces[stroke]
                            ctx.lineWidth = stroke === 0 ? 5.5
                                : (stroke === 1 ? 2.4 : 1.0)
                            ctx.strokeStyle = stroke === 2
                                ? "#ffffff"
                                : Qt.lighter(root.eqAccentColor,
                                    stroke === 0 ? 1.28 : 1.55)

                            for (let i = 1; i < samples.length; ++i) {
                                const p1 = samples[i - 1]
                                const p2 = samples[i]
                                const segmentPosition = ((p1.x + p2.x) * 0.5)
                                    / Math.max(1, width)
                                const distance = sweep - segmentPosition
                                let pulse = 0

                                if (distance >= -sweepLead
                                        && distance <= sweepTail) {
                                    if (distance < 0)
                                        pulse = 1 - (-distance / sweepLead)
                                    else
                                        pulse = Math.pow(
                                            1 - distance / sweepTail, 1.6)
                                }

                                if (pulse <= 0)
                                    continue

                                ctx.beginPath()
                                ctx.moveTo(p1.x, p1.y)
                                ctx.lineTo(p2.x, p2.y)
                                ctx.globalAlpha = pulse
                                    * (stroke === 0 ? 0.38
                                        : (stroke === 1 ? 0.78 : 0.95))
                                ctx.stroke()
                            }
                        }
                    }

                    ctx.globalAlpha = 1.0
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0
                z: 1

                Repeater {
                    id: bandRepeater
                    model: EqualizerService.dspBands

                    delegate: Item {
                        id: bandDelegate
                        required property var modelData
                        required property int index
                        width: parent.width / 10
                        height: parent.height
                        readonly property real backendGain: Number(modelData?.gain) || 0

                        function lightningPoint() {
                            const handleItem = bandSlider.handle
                            if (!handleItem) {
                                return Qt.point(
                                    (bandDelegate.index + 0.5)
                                        * (lightningCanvas.width / 10),
                                    lightningCanvas.height / 2)
                            }
                            return handleItem.mapToItem(
                                lightningCanvas,
                                handleItem.width / 2,
                                handleItem.height / 2)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2

                            Slider {
                                id: bandSlider
                                Layout.fillHeight: true
                                Layout.alignment: Qt.AlignHCenter
                                orientation: Qt.Vertical
                                from: EqualizerService.dspMinimumBandGain
                                to: EqualizerService.dspMaximumBandGain
                                stepSize: 1
                                snapMode: Slider.SnapAlways
                                hoverEnabled: true
                                enabled: EqualizerService.dspControlAvailable && !EqualizerService.busy
                                implicitWidth: 26
                                value: bandDelegate.backendGain

                                onPressedChanged: {
                                    if (pressed) {
                                        root.beginBandLightning(
                                            bandDelegate.index, value)
                                    } else if (enabled) {
                                        const rounded = Math.round(value)
                                        EqualizerService.setDspBandGain(
                                            bandDelegate.index, rounded)
                                        root.endBandLightning(
                                            bandDelegate.index, rounded)
                                    }
                                }
                                onMoved: {
                                    value = Math.round(value)
                                    root.previewBandLightning(
                                        bandDelegate.index, value)
                                }
                                Connections {
                                    target: EqualizerService
                                    function onDspBandsChanged(): void {
                                        if (!bandSlider.pressed)
                                            bandSlider.value = bandDelegate.backendGain
                                    }
                                }

                                background: Rectangle {
                                    x: bandSlider.leftPadding
                                        + (bandSlider.availableWidth - width) / 2
                                    y: bandSlider.topPadding
                                    width: 7
                                    height: bandSlider.availableHeight
                                    radius: width / 2
                                    color: Appearance.colors.colLayer2

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: Math.max(parent.width,
                                            (1 - bandSlider.visualPosition) * parent.height)
                                        radius: parent.radius
                                        color: Appearance.colors.colPrimary
                                        opacity: bandSlider.enabled ? 0.9 : 0.35
                                    }
                                }

                                handle: Rectangle {
                                    x: bandSlider.leftPadding
                                        + (bandSlider.availableWidth - width) / 2
                                    y: bandSlider.topPadding
                                        + bandSlider.visualPosition
                                            * (bandSlider.availableHeight - height)
                                    implicitWidth: 13
                                    implicitHeight: 13
                                    radius: width / 2
                                    color: bandSlider.pressed
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colOnPrimary
                                    border.width: 1
                                    border.color: Appearance.colors.colPrimary
                                    scale: bandSlider.pressed ? 1.15
                                        : (bandSlider.hovered ? 1.06 : 1.0)

                                    // Signal that the EQ dot is draggable while
                                    // leaving the Slider in charge of the drag.
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
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData?.label ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.topMargin: 1
            columns: 4
            uniformCellWidths: true
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: ["Flat", "Bass", "Treble", "Vocal",
                        "Pop", "Rock", "Jazz", "Classic"]

                delegate: RippleButton {
                    id: presetButton
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 24
                    horizontalPadding: 4
                    buttonText: modelData
                    buttonRadius: Appearance.rounding.small
                    enabled: EqualizerService.dspControlAvailable
                        && !EqualizerService.busy
                    toggled: EqualizerService.dspPresetName === modelData
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colBackgroundToggled: Appearance.colors.colPrimaryContainer
                    colBackgroundToggledHover: Appearance.colors.colPrimaryContainer
                    onClicked: root.applyPresetWithLightning(modelData)

                    contentItem: StyledText {
                        text: presetButton.modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: presetButton.toggled ? Font.DemiBold : Font.Normal
                        color: presetButton.toggled
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
