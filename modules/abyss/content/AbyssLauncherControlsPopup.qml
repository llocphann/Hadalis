import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import "../looks/AbyssWave.js" as Wave

ColumnLayout {
    id: root
    implicitWidth: 330
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

    component SectionHeading: RowLayout {
        required property string heading
        required property string icon
        Layout.fillWidth: true
        spacing: 7

        MaterialSymbol {
            text: parent.icon
            iconSize: 18
            color: AbyssStyle.accent
            Layout.alignment: Qt.AlignVCenter
        }
        AbyssLabel {
            Layout.fillWidth: true
            text: parent.heading
            font.bold: true
            color: AbyssStyle.textColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 10

        SectionHeading {
            heading: Translation.tr("Wave Mode")
            icon: "tune"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    {label:"Performance",value:"performance",icon:"bolt"},
                    {label:"Balanced",value:"balanced",icon:"balance"},
                    {label:"Quality",value:"quality",icon:"auto_awesome"}
                ]
                delegate: AbyssButton {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 180
                    implicitHeight: 38
                    compact: false
                    checked: AbyssStyle.quality === modelData.value
                    text: Translation.tr(modelData.label)
                    glyph: modelData.icon
                    description: text
                    onClicked: root.applyQuality(modelData.value)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(AbyssStyle.accent, .16)
        }

        SectionHeading {
            heading: Translation.tr("Wave Preset")
            icon: "waves"
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
                delegate: AbyssButton {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 110
                    implicitHeight: 38
                    compact: false
                    checked: (Config.options?.abyss?.waves?.preset ?? "balanced")
                        === modelData.value
                    text: Translation.tr(modelData.label)
                    glyph: modelData.icon
                    description: text
                    onClicked: root.applyWavePreset(modelData.value)
                }
            }
        }
    }
}
