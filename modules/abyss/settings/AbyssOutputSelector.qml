pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    required property string configPath
    readonly property var connected: Quickshell.screens.map(screen => screen.name)
    readonly property var effective: selected.some(name => connected.includes(name)) ? selected.filter(name => connected.includes(name)) : connected
    readonly property var selected: Config.getNestedValue(configPath, []) ?? []
    property string title: "Outputs"

    ContentSubsectionLabel {
        text: root.title
    }
    ConfigSwitch {
        autoToggle: false
        buttonIcon: "desktop_windows"
        checked: root.selected.length === 0
        text: "All connected displays"

        onToggledByUser: checked => Config.setNestedValue(root.configPath, checked ? [] : root.connected)
    }
    Repeater {
        model: root.connected

        ConfigSwitch {
            required property string modelData

            autoToggle: false
            buttonIcon: "monitor"
            checked: root.effective.includes(modelData)
            enabled: !checked || root.effective.length > 1
            text: modelData
            visible: root.selected.length > 0

            onToggledByUser: checked => Config.setNestedValue(root.configPath, checked ? root.effective.concat([modelData]) : root.effective.filter(name => name !== modelData))
        }
    }
}
