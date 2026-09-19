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
    property real eqLightningProgress: 0.0
    property real eqLightningFade: 1.0
    property var _lightningGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    readonly property color eqAccentColor: Appearance.colors.colPrimary
    implicitHeight: 214

    function triggerEqLightning(): void {
        eqLightningAnim.restart()
    }

    function applyPresetWithLightning(name): void {
        const curve = EqualizerService.dspPresetCurves[name]
        if (!curve)
            return
        if (EqualizerService.applyDspPreset(name)) {
            root._lightningGains = curve.slice()
            root.triggerEqLightning()
        }
    }

    SequentialAnimation {
        id: eqLightningAnim
        running: false
        ScriptAction {
            script: {
                root.eqLightningFade = 0.0
                root.eqLightningProgress = 0.0
            }
        }
        NumberAnimation {
            target: root
            property: "eqLightningProgress"
            from: 0.0
            to: 10.0
            duration: 650
            easing.type: Easing.OutSine
        }
        PauseAnimation { duration: 150 }
        NumberAnimation {
            target: root
            property: "eqLightningFade"
            from: 0.0
            to: 1.0
            duration: 800
            easing.type: Easing.OutQuad
        }
        ScriptAction { script: root.eqLightningProgress = 0.0 }
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
            return "socat unavailable"
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

    onActiveChanged: root.syncRegistration()
    Component.onCompleted: root.syncRegistration()
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
                opacity: 1.0 - root.eqLightningFade
                visible: opacity > 0.001 && root.eqLightningProgress > 0.0

                Timer {
                    interval: 16
                    running: lightningCanvas.visible
                    repeat: true
                    onTriggered: lightningCanvas.requestPaint()
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (root.eqLightningProgress <= 0.0
                            || root.eqLightningFade >= 1.0)
                        return

                    const gains = root._lightningGains ?? []
                    const points = []
                    for (let i = 0; i < 10; ++i) {
                        const gain = Number(gains[i] ?? 0)
                        const normalized = 1.0
                            - ((Math.max(-12, Math.min(12, gain)) + 12) / 24)
                        points.push({
                            x: (i + 0.5) * (width / 10),
                            y: 8 + normalized * Math.max(1, height - 24)
                        })
                    }

                    const now = Date.now() / 1000
                    const maxIndex = root.eqLightningProgress
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"

                    for (let stroke = 0; stroke < 4; ++stroke) {
                        ctx.beginPath()
                        ctx.moveTo(points[0].x, points[0].y)

                        for (let i = 0; i < points.length - 1; ++i) {
                            if (i > maxIndex)
                                break
                            const p1 = points[i]
                            const p2 = points[i + 1]
                            let fraction = 1.0
                            if (maxIndex < i + 1)
                                fraction = Math.max(0, maxIndex - i)
                            const steps = stroke === 3 ? 6 : 8
                            for (let j = 1; j <= steps; ++j) {
                                let t = Math.min(fraction, j / steps)
                                const envelope = Math.sin(t * Math.PI)
                                const x = p1.x + (p2.x - p1.x) * t
                                const y = p1.y + (p2.y - p1.y) * t
                                const noiseX = Math.sin(now * (10 + stroke) + i + j)
                                    * Math.cos(now * 8 - i + j)
                                    * (stroke === 3 ? 1 : (4 - stroke) * 2.6)
                                    * envelope * (1 - root.eqLightningFade)
                                const noiseY = Math.cos(now * (9 - stroke) + i - j)
                                    * Math.sin(now * 7 + i - j)
                                    * (stroke === 3 ? 1 : (4 - stroke) * 3.4)
                                    * envelope * (1 - root.eqLightningFade)
                                ctx.lineTo(x + noiseX, y + noiseY)
                                if (t >= fraction)
                                    break
                            }
                        }

                        if (stroke === 0) {
                            ctx.lineWidth = 14
                            ctx.strokeStyle = root.eqAccentColor
                            ctx.globalAlpha = 0.28
                        } else if (stroke === 1) {
                            ctx.lineWidth = 7
                            ctx.strokeStyle = Qt.lighter(root.eqAccentColor, 1.2)
                            ctx.globalAlpha = 0.58
                        } else if (stroke === 2) {
                            ctx.lineWidth = 3.5
                            ctx.strokeStyle = Qt.lighter(root.eqAccentColor, 1.45)
                            ctx.globalAlpha = 0.88
                        } else {
                            ctx.lineWidth = 1.6
                            ctx.strokeStyle = "#ffffff"
                            ctx.globalAlpha = 1.0
                        }
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1.0
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0
                z: 1

                Repeater {
                    model: EqualizerService.dspBands

                    delegate: Item {
                        id: bandDelegate
                        required property var modelData
                        required property int index
                        width: parent.width / 10
                        height: parent.height
                        readonly property real backendGain: Number(modelData?.gain) || 0
                        readonly property real lightningDistance:
                            root.eqLightningProgress - index
                        readonly property real lightningPulse:
                            lightningDistance >= 0 && lightningDistance < 1
                                ? Math.sin(lightningDistance * Math.PI) : 0

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
                                    if (!pressed && enabled)
                                        EqualizerService.setDspBandGain(
                                            bandDelegate.index, Math.round(value))
                                }
                                onMoved: value = Math.round(value)
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
                                        scale: 1 + bandDelegate.lightningPulse * 0.12
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
                                    scale: (bandSlider.pressed ? 1.15
                                        : (bandSlider.hovered ? 1.06 : 1.0))
                                        + bandDelegate.lightningPulse * 0.18

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
