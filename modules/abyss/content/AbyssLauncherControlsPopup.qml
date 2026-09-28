import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import "../looks/AbyssWave.js" as Wave

ColumnLayout {
    id: root
    implicitWidth: 360
    implicitHeight: content.implicitHeight
    spacing: 12

    function applyQuality(value): void {
        Config.setNestedValue("abyss.quality", value)
    }
    function applyWavePreset(value): void {
        const updates = {"abyss.waves.preset": value}
        if (Wave.presets[value]) {
            Object.keys(Wave.presets[value]).forEach(key =>
                updates["abyss.waves." + key] = Wave.presets[value][key])
        }
        Config.setNestedValues(updates)
    }

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 10

        AbyssLabel {
            text: Translation.tr("Surface Performance")
            font.bold: true
            color: AbyssStyle.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    {label:"Performance",value:"performance",icon:"bolt"},
                    {label:"Balanced",value:"balanced",icon:"balance"},
                    {label:"Quality",value:"quality",icon:"auto_awesome"}
                ]
                delegate: SelectionGroupButton {
                    required property var modelData
                    Layout.fillWidth: true
                    buttonText: Translation.tr(modelData.label)
                    buttonIcon: modelData.icon
                    toggled: AbyssStyle.quality === modelData.value
                    onClicked: root.applyQuality(modelData.value)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(AbyssStyle.accent, .16)
        }

        RowLayout {
            Layout.fillWidth: true

            AbyssLabel {
                Layout.fillWidth: true
                text: Translation.tr("Wave Preset")
                font.bold: true
                color: AbyssStyle.textColor
            }
            MaterialSymbol {
                text: "waves"
                color: AbyssStyle.accent
                iconSize: Appearance.font.pixelSize.normal
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: [
                    {label:"Calm",value:"calm",icon:"air"},
                    {label:"Balanced",value:"balanced",icon:"waves"},
                    {label:"Fluid",value:"fluid",icon:"water"},
                    {label:"Deep",value:"deep",icon:"tsunami"}
                ]
                delegate: SelectionGroupButton {
                    required property var modelData
                    Layout.fillWidth: true
                    buttonText: Translation.tr(modelData.label)
                    buttonIcon: modelData.icon
                    toggled: (Config.options?.abyss?.waves?.preset ?? "balanced")
                        === modelData.value
                    onClicked: root.applyWavePreset(modelData.value)
                }
            }
        }
    }
}
