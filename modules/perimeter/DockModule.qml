import qs.modules.common
import qs.modules.dock
import QtQuick
import Quickshell

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool enabledByConfig: Config.options?.dock?.enable ?? true
    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string edge: {
        const candidate = String(root.perimeterContext?.edge ?? "bottom")
        return ["top", "right", "bottom", "left"].includes(candidate)
            ? candidate : "bottom"
    }
    readonly property string outputName: String(root.perimeterContext?.outputName ?? "")
    readonly property bool presented: root.enabledByConfig
        && PerimeterPresentationPolicy.dockPresentedForOutput(
            root.outputName, root.edge)
    readonly property real configuredThickness: Number(
        root.instanceConfig?.thickness ?? Config.options?.dock?.height ?? 70)
    readonly property real thickness: Number.isFinite(root.configuredThickness)
        ? Math.max(40, Math.min(200, root.configuredThickness)) : 70
    readonly property real outerPadding: Appearance.sizes.elevationMargin
    readonly property real naturalWidth: root.vertical
        ? Math.max(root.thickness,
            dockApps.implicitWidth + root.outerPadding * 2)
        : dockApps.implicitWidth + root.outerPadding * 2
    readonly property real naturalHeight: root.vertical
        ? dockApps.implicitHeight + root.outerPadding * 2
        : Math.max(root.thickness,
            dockApps.implicitHeight + root.outerPadding * 2)

    implicitWidth: root.presented ? root.naturalWidth : 0
    implicitHeight: root.presented ? root.naturalHeight : 0
    visible: root.presented
    enabled: root.presented

    DockApps {
        id: dockApps
        anchors.centerIn: parent
        visible: root.presented
        vertical: root.vertical
        dockPosition: root.edge
        parentWindow: root.QsWindow.window
    }
}
