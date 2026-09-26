pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.modules.abyss.looks

Item {
    id: root
    required property string outputName
    property bool vertical: false
    readonly property var workspaces: CompositorService.isNiri
        ? NiriService.allWorkspaces.filter(w => w.output === root.outputName)
        : Hyprland.workspaces.values.filter(w => w.monitor?.name === root.outputName)
    Repeater {
        model: root.workspaces
        AbyssButton {
            required property var modelData
            required property int index
            x: root.vertical ? 0 : index * width
            y: root.vertical ? index * height : 0
            width: root.vertical ? root.width : Math.min(36, root.width / Math.max(1,root.workspaces.length))
            height: root.vertical ? Math.min(36,root.height/Math.max(1,root.workspaces.length)) : root.height
            text: String(modelData.name || modelData.idx || modelData.id)
            description: "Workspace " + text
            checked: CompositorService.isNiri ? modelData.is_active : Hyprland.focusedWorkspace?.id === modelData.id
            onClicked: {
                if (CompositorService.isNiri) NiriService.switchToWorkspaceById(modelData.id)
                else Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
