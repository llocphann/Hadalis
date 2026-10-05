import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland

WindowDialog {
    id: root
    property var screen: root.QsWindow.window?.screen
    // Brightness monitor may be unavailable on some outputs; guard access.
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null
    backgroundHeight: Math.max(360, Math.min(860, (root.screen?.height ?? 1080) - 96))

    component EmbeddedSliderRow: RowLayout {
        id: inlineSlider

        property string label: ""
        property string valueText: ""
        property alias from: embeddedSliderControl.from
        property alias to: embeddedSliderControl.to
        property alias stepSize: embeddedSliderControl.stepSize
        property alias value: embeddedSliderControl.value
        property alias stopIndicatorValues: embeddedSliderControl.stopIndicatorValues
        property alias tooltipContent: embeddedSliderControl.tooltipContent
        signal moved()

        spacing: 8

        StyledText {
            Layout.preferredWidth: 190
            Layout.maximumWidth: 190
            text: inlineSlider.label
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        StyledSlider {
            id: embeddedSliderControl
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            enableSettingsSearch: false
            configuration: StyledSlider.Configuration.S
            Accessible.name: inlineSlider.label
            onMoved: inlineSlider.moved()
        }

        StyledText {
            id: embeddedSliderValue
            Layout.preferredWidth: 68
            text: inlineSlider.valueText
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    WindowDialogTitle {
        visible: !root.embeddedPresentation
        text: Translation.tr("Eye protection")
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: protectionContent.implicitHeight
        ColumnLayout {
            id: protectionContent
            width: parent.width
            spacing: 16
            WindowDialogSectionHeader {
                text: Translation.tr("Night Light")
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
                Layout.leftMargin: 0
                Layout.rightMargin: 0
            }

            Column {
                id: nightLightColumn
                Layout.topMargin: -16
                Layout.fillWidth: true

                GridLayout {
                    id: nightLightPrimaryToggles
                    width: parent.width
                    columns: root.embeddedPresentation ? 2 : 1
                    columnSpacing: root.embeddedPresentation ? 8 : 0
                    rowSpacing: 0

                    ConfigSwitch {
                        Layout.fillWidth: true
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "lightbulb"
                        text: root.embeddedPresentation
                            ? Translation.tr("Enable")
                            : Translation.tr("Enable now")
                        autoToggle: false
                        checked: Hyprsunset.active
                        onToggledByUser: checked => Hyprsunset.toggle(checked)
                    }

                    ConfigSwitch {
                        Layout.fillWidth: true
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "night_sight_auto"
                        text: Translation.tr("Automatic")
                        autoToggle: false
                        checked: Config.options?.light?.night?.automatic ?? false
                        onToggledByUser: checked => Config.setNestedValue("light.night.automatic", checked)
                    }
                }

                // Schedule settings (only visible when automatic is enabled)
                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    visible: Config.options?.light?.night?.automatic ?? false
                    opacity: visible ? 1 : 0
                    spacing: 4

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    ConfigTimeInput {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        icon: "wb_twilight"
                        text: Translation.tr("Turn on at")
                        value: Config.options?.light?.night?.from ?? "19:00"
                        onTimeChanged: (newTime) => {
                            Config.setNestedValue("light.night.from", newTime);
                        }
                    }

                    ConfigTimeInput {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        icon: "wb_sunny"
                        text: Translation.tr("Turn off at")
                        value: Config.options?.light?.night?.to ?? "06:30"
                        onTimeChanged: (newTime) => {
                            Config.setNestedValue("light.night.to", newTime);
                        }
                    }
                }

                WindowDialogSlider {
                    visible: !root.embeddedPresentation
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 4
                        rightMargin: 4
                    }
                    text: Translation.tr("Intensity")
                    from: 6500
                    to: 1200
                    stopIndicatorValues: [5000, to]
                    value: Config.options?.light?.night?.colorTemperature ?? 4500
                    onMoved: Config.setNestedValue("light.night.colorTemperature", value)
                    valueText: `${Math.round(value)} K`
                    tooltipContent: valueText
                }

                EmbeddedSliderRow {
                    visible: root.embeddedPresentation
                    width: parent.width
                    label: Translation.tr("Intensity")
                    from: 6500
                    to: 1200
                    stopIndicatorValues: [5000, to]
                    value: Config.options?.light?.night?.colorTemperature ?? 4500
                    valueText: `${Math.round(value)} K`
                    tooltipContent: valueText
                    onMoved: Config.setNestedValue("light.night.colorTemperature", value)
                }
            }

            WindowDialogSectionHeader {
                text: Translation.tr("Anti-flashbang")
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
                Layout.leftMargin: 0
                Layout.rightMargin: 0
            }

            Column {
                id: antiFlashbangColumn
                Layout.topMargin: -16
                Layout.fillWidth: true

                ConfigSwitch {
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    iconSize: Appearance.font.pixelSize.larger
                    buttonIcon: "flash_off"
                    text: Translation.tr("Enable")
                    autoToggle: false
                    checked: Config.options?.light?.antiFlashbang?.enable ?? false
                    onToggledByUser: checked => Config.setNestedValue("light.antiFlashbang.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Dim bright content automatically while preserving your selected brightness")
                    }
                }
                Column {
                    width: parent.width
                    visible: Config.options?.light?.antiFlashbang?.enable ?? false
                    spacing: 8
                    ConfigSwitch {
                        width: parent.width
                        text: Translation.tr("Only in dark mode")
                        autoToggle: false
                        checked: Config.options?.light?.antiFlashbang?.darkOnly ?? true
                        onToggledByUser: checked => Config.setNestedValue("light.antiFlashbang.darkOnly", checked)
                    }
                    Repeater {
                        model: [
                            {label:"Bright content threshold",key:"threshold",fallback:.30,from:0,to:.95,unit:"%",scale:100},
                            {label:"Dimming strength",key:"strength",fallback:.90,from:0,to:1,unit:"%",scale:100},
                            {label:"Minimum brightness multiplier",key:"minMultiplier",fallback:.12,from:.05,to:1,unit:"%",scale:100},
                            {label:"Sampling interval",key:"sampleInterval",fallback:500,from:250,to:3000,unit:"ms",scale:1},
                            {label:"Response duration",key:"responseMs",fallback:80,from:40,to:500,unit:"ms",scale:1},
                            {label:"Capture scale",key:"sampleScale",fallback:.10,from:.05,to:.50,unit:"%",scale:100}
                        ]
                        delegate: Column {
                            required property var modelData
                            width: parent.width

                            WindowDialogSlider {
                                visible: !root.embeddedPresentation
                                width: parent.width
                                text: Translation.tr(parent.modelData.label)
                                from: parent.modelData.from
                                to: parent.modelData.to
                                stepSize: parent.modelData.scale === 100 ? .01 : 10
                                value: Config.options?.light?.antiFlashbang?.[parent.modelData.key]
                                    ?? parent.modelData.fallback
                                valueText: Math.round(value * parent.modelData.scale)
                                    + " " + parent.modelData.unit
                                tooltipContent: valueText
                                onMoved: Config.setNestedValue(
                                    "light.antiFlashbang." + parent.modelData.key, value)
                            }

                            EmbeddedSliderRow {
                                visible: root.embeddedPresentation
                                width: parent.width
                                label: Translation.tr(parent.modelData.label)
                                from: parent.modelData.from
                                to: parent.modelData.to
                                stepSize: parent.modelData.scale === 100 ? .01 : 10
                                value: Config.options?.light?.antiFlashbang?.[parent.modelData.key]
                                    ?? parent.modelData.fallback
                                valueText: Math.round(value * parent.modelData.scale)
                                    + " " + parent.modelData.unit
                                tooltipContent: valueText
                                onMoved: Config.setNestedValue(
                                    "light.antiFlashbang." + parent.modelData.key, value)
                            }
                        }
                    }
                }
            }

            WindowDialogSectionHeader {
                visible: !root.embeddedPresentation
                text: Translation.tr("Brightness")
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
                Layout.leftMargin: 0
                Layout.rightMargin: 0
            }

            Column {
                id: brightnessColumn
                Layout.topMargin: root.embeddedPresentation ? -4 : -16
                Layout.fillWidth: true
                visible: !!root.brightnessMonitor

                WindowDialogSlider {
                    visible: !root.embeddedPresentation
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 4
                        rightMargin: 4
                    }
                    text: Translation.tr("Brightness")
                    valueText: `${Math.round(value*100)} %`
                    value: root.brightnessMonitor?.brightness ?? 0
                    onMoved: root.brightnessMonitor?.setBrightness(value)
                }

                EmbeddedSliderRow {
                    visible: root.embeddedPresentation
                    width: parent.width
                    label: Translation.tr("Brightness")
                    value: root.brightnessMonitor?.brightness ?? 0
                    valueText: `${Math.round(value * 100)} %`
                    tooltipContent: valueText
                    onMoved: root.brightnessMonitor?.setBrightness(value)
                }
            }

        }
    }

    WindowDialogButtonRow {
        visible: !root.embeddedPresentation
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
