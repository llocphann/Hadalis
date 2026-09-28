import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import "../looks/AbyssWave.js" as Wave

// Launcher controls mirror the mature Battery popup structure: direct
// MaterialSymbol + StyledText content inside a source-owned StyledPopup.
ColumnLayout {
    id: root
    implicitWidth: 360
    spacing: 10

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
        required property string label
        required property string symbol
        Layout.fillWidth: true
        spacing: 7

        MaterialSymbol {
            text: parent.symbol
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurfaceVariant
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: Translation.tr(parent.label)
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
        }
    }

    SectionHeading {
        label: "Surface Performance"
        symbol: "speed"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                {label:"Performance", value:"performance", icon:"bolt"},
                {label:"Balanced", value:"balanced", icon:"balance"},
                {label:"Quality", value:"quality", icon:"auto_awesome"}
            ]

            delegate: SelectionGroupButton {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 38
                buttonText: Translation.tr(modelData.label)
                buttonIcon: modelData.icon
                leftAlignContent: true
                maxTextWidth: 260
                toggled: Config.options?.abyss?.quality === modelData.value
                onClicked: root.applyQuality(modelData.value)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.alpha(Appearance.colors.colPrimary, .16)
    }

    SectionHeading {
        label: "Wave Preset"
        symbol: "waves"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: [
                {label:"Calm", value:"calm", icon:"air"},
                {label:"Balanced", value:"balanced", icon:"waves"},
                {label:"Fluid", value:"fluid", icon:"water"},
                {label:"Deep", value:"deep", icon:"tsunami"}
            ]

            delegate: SelectionGroupButton {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 165
                implicitHeight: 38
                buttonText: Translation.tr(modelData.label)
                buttonIcon: modelData.icon
                leftAlignContent: true
                maxTextWidth: 110
                toggled: (Config.options?.abyss?.waves?.preset ?? "balanced")
                    === modelData.value
                onClicked: root.applyWavePreset(modelData.value)
            }
        }
    }
}
