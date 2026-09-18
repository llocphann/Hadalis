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
    implicitHeight: 236

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
            Layout.preferredHeight: 132
            Layout.leftMargin: 4
            Layout.rightMargin: 4

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: EqualizerService.dspBands

                    delegate: Item {
                        id: bandDelegate
                        required property var modelData
                        required property int index
                        width: parent.width / 10
                        height: parent.height
                        readonly property real backendGain: Number(modelData?.gain) || 0

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
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            columns: 4
            columnSpacing: 6
            rowSpacing: 5

            Repeater {
                model: ["Flat", "Bass", "Treble", "Vocal",
                        "Pop", "Rock", "Jazz", "Classic"]

                delegate: RippleButton {
                    required property string modelData
                    Layout.fillWidth: true
                    implicitHeight: 25
                    buttonText: modelData
                    buttonRadius: Appearance.rounding.small
                    enabled: EqualizerService.dspControlAvailable
                        && !EqualizerService.busy
                    toggled: EqualizerService.dspPresetName === modelData
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colBackgroundToggled: Appearance.colors.colPrimary
                    colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                    onClicked: EqualizerService.applyDspPreset(modelData)
                }
            }
        }
    }
}
