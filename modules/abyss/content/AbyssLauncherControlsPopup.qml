import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import "../looks/AbyssWave.js" as Wave

// Compact control surface for the Launcher hover popup.
//
// The controls intentionally own their icon + text row instead of delegating
// readability to the generic AbyssButton compact heuristics. This popup has a
// fixed readable width in AbyssPopup, so labels remain visible on every row.
ColumnLayout {
    id: root
    implicitWidth: 360
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
        required property string iconName
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: parent.iconName
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

    component PopupChoice: AbstractButton {
        id: choice
        required property string iconName

        hoverEnabled: true
        implicitWidth: 160
        implicitHeight: 40
        leftPadding: 14
        rightPadding: 14
        topPadding: 8
        bottomPadding: 8
        Accessible.name: text
        Accessible.role: Accessible.Button

        background: Rectangle {
            radius: height / 2
            color: Qt.alpha(AbyssStyle.accent,
                choice.down ? .24
                : choice.checked ? .20
                : choice.hovered ? .12 : .05)
            border.width: 1
            border.color: Qt.alpha(AbyssStyle.accent,
                choice.activeFocus ? .80
                : choice.hovered || choice.checked ? .36 : .15)
        }

        contentItem: Item {
            implicitWidth: symbol.implicitWidth + 8 + caption.implicitWidth
            implicitHeight: Math.max(symbol.implicitHeight, caption.implicitHeight)

            MaterialSymbol {
                id: symbol
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: choice.iconName
                iconSize: 20
                color: choice.hovered || choice.checked
                    ? AbyssStyle.accent : AbyssStyle.textColor
            }

            AbyssLabel {
                id: caption
                anchors.left: symbol.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: choice.text
                color: choice.hovered || choice.checked
                    ? AbyssStyle.accent : AbyssStyle.textColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    SectionHeading {
        heading: Translation.tr("Surface Performance")
        iconName: "speed"
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

            delegate: PopupChoice {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                text: Translation.tr(modelData.label)
                iconName: modelData.icon
                checked: AbyssStyle.quality === modelData.value
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
        iconName: "waves"
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

            delegate: PopupChoice {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 150
                text: Translation.tr(modelData.label)
                iconName: modelData.icon
                checked: (Config.options?.abyss?.waves?.preset ?? "balanced")
                    === modelData.value
                onClicked: root.applyWavePreset(modelData.value)
            }
        }
    }
}
