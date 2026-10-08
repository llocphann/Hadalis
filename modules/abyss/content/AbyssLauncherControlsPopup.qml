import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import "../looks/AbyssWave.js" as Wave

// Compact Launcher controls use the existing SelectionGroupButton reveal
// contract: every option always keeps its icon, while only the selected
// mode/preset exposes its label.
Item {
    id: root
    implicitWidth: Math.ceil(contentColumn.implicitWidth)
    implicitHeight: contentColumn.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    function applyQuality(value): void {
        Config.setNestedValues({"abyss.quality":value,"abyss.autoQuality":false})
    }

    function applyWavePreset(value): void {
        const updates = {"abyss.waves.preset": value}
        if (Wave.presets[value]) {
            Object.keys(Wave.presets[value]).forEach(key =>
                updates["abyss.waves." + key] = Wave.presets[value][key])
        }
        Config.setNestedValues(updates)
    }

    component CompactChoice: SelectionGroupButton {
        id: choice
        required property string labelText
        required property string iconName
        required property bool selected

        text: labelText
        buttonIcon: iconName
        buttonText: selected ? labelText : ""
        toggled: selected
        implicitHeight: 34
        horizontalPadding: 9
        verticalPadding: 5
        maxTextWidth: 110
    }

    ColumnLayout {
        id: contentColumn
        spacing: 6

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignLeft

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "speed"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Surface Performance")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.small
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 5

            Repeater {
                model: [
                    {label:"Performance", value:"performance", icon:"bolt"},
                    {label:"Balanced", value:"balanced", icon:"balance"},
                    {label:"Quality", value:"quality", icon:"auto_awesome"}
                ]

                delegate: CompactChoice {
                    required property var modelData
                    labelText: Translation.tr(modelData.label)
                    iconName: modelData.icon
                    selected: AbyssRenderPolicy.abyssQuality === modelData.value
                    onClicked: root.applyQuality(modelData.value)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
            opacity: 0.65
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignLeft

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "waves"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Wave Preset")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.small
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 5

            Repeater {
                model: [
                    {label:"Calm", value:"calm", icon:"air"},
                    {label:"Balanced", value:"balanced", icon:"waves"},
                    {label:"Fluid", value:"fluid", icon:"water"},
                    {label:"Deep", value:"deep", icon:"tsunami"}
                ]

                delegate: CompactChoice {
                    required property var modelData
                    labelText: Translation.tr(modelData.label)
                    iconName: modelData.icon
                    selected: (Config.options?.abyss?.waves?.preset ?? "balanced")
                        === modelData.value
                    onClicked: root.applyWavePreset(modelData.value)
                }
            }
        }
    }
}
