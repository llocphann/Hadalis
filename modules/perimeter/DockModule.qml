import qs.modules.common
import qs.modules.dock
import QtQuick
import Quickshell

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string edge: {
        const candidate = String(root.perimeterContext?.edge ?? "bottom")
        return ["top", "right", "bottom", "left"].includes(candidate)
            ? candidate : "bottom"
    }
    readonly property real configuredThickness: Number(
        root.instanceConfig?.thickness ?? Config.options?.dock?.height ?? 70)
    readonly property real thickness: Number.isFinite(root.configuredThickness)
        ? Math.max(40, Math.min(200, root.configuredThickness)) : 70
    readonly property real outerPadding: Appearance.sizes.elevationMargin

    implicitWidth: root.vertical
        ? Math.max(root.thickness,
            dockApps.implicitWidth + root.outerPadding * 2)
        : dockApps.implicitWidth + root.outerPadding * 2
    implicitHeight: root.vertical
        ? dockApps.implicitHeight + root.outerPadding * 2
        : Math.max(root.thickness,
            dockApps.implicitHeight + root.outerPadding * 2)

    DockApps {
        id: dockApps
        anchors.centerIn: parent
        vertical: root.vertical
        dockPosition: root.edge
        parentWindow: root.QsWindow.window
    }
}
