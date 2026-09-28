import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import "../looks/AbyssWave.js" as Wave

// Launcher follows the same visible-content primitives already proven by
// BatteryPopup and the embedded Wi-Fi/Bluetooth dialogs:
//   header: MaterialSymbol + StyledText
//   selectable row: DialogListItem + direct MaterialSymbol/StyledText content
//
// Keep a visual wrapper around the layout, matching other mature StyledPopup
// consumers that report stable implicit geometry before Abyss rehosts them.
Item {
    id: root
    implicitWidth: 360
    implicitHeight: contentColumn.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

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

    component ChoiceRow: DialogListItem {
        id: choice
        required property string iconName
        required property bool selected

        Layout.fillWidth: true
        active: selected
        pointingHandCursor: true
        implicitHeight: Math.max(44, contentItem.implicitHeight + verticalPadding * 2)

        contentItem: RowLayout {
            spacing: 10

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: choice.iconName
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: choice.buttonText
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: choice.selected
                text: "check"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        width: parent.width
        spacing: 8

        Row {
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "speed"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Surface Performance")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.normal
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    {label:"Performance", value:"performance", icon:"bolt"},
                    {label:"Balanced", value:"balanced", icon:"balance"},
                    {label:"Quality", value:"quality", icon:"auto_awesome"}
                ]

                delegate: ChoiceRow {
                    required property var modelData
                    buttonText: Translation.tr(modelData.label)
                    iconName: modelData.icon
                    selected: Config.options?.abyss?.quality === modelData.value
                    onClicked: root.applyQuality(modelData.value)
                }
            }
        }

        WindowDialogSeparator {
            Layout.fillWidth: true
        }

        Row {
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "waves"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Wave Preset")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.normal
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    {label:"Calm", value:"calm", icon:"air"},
                    {label:"Balanced", value:"balanced", icon:"waves"},
                    {label:"Fluid", value:"fluid", icon:"water"},
                    {label:"Deep", value:"deep", icon:"tsunami"}
                ]

                delegate: ChoiceRow {
                    required property var modelData
                    buttonText: Translation.tr(modelData.label)
                    iconName: modelData.icon
                    selected: (Config.options?.abyss?.waves?.preset ?? "balanced")
                        === modelData.value
                    onClicked: root.applyWavePreset(modelData.value)
                }
            }
        }
    }
}
