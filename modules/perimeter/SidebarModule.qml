import qs
import qs.modules.common
import qs.modules.sidebarLeft
import qs.modules.sidebarRight
import QtQuick
import Quickshell

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property string moduleId: String(root.perimeterContext?.moduleId ?? "")
    readonly property bool featureRole: root.moduleId === "left-sidebar"
    readonly property bool systemRole: root.moduleId === "right-sidebar"
    readonly property string outputName: String(root.perimeterContext?.outputName ?? "")
    readonly property var targetScreen: Quickshell.screens.find(screen =>
        String(screen?.name ?? "") === root.outputName) ?? null
    readonly property var roleConfig: root.featureRole
        ? Config.options?.sidebar?.shellLayout?.feature
        : Config.options?.sidebar?.shellLayout?.system
    readonly property bool compactSystem: root.systemRole
        && (Config.options?.sidebar?.layout ?? "default") === "compact"

    function bounded(value, fallback, minimum, maximum) {
        const number = Number(value)
        const resolved = Number.isFinite(number) ? number : fallback
        return Math.max(minimum, Math.min(maximum, resolved))
    }

    readonly property real availableHeight: Math.max(0,
        (root.targetScreen?.height ?? 0) - Appearance.sizes.hyprlandGapsOut * 2)
    readonly property real requestedWidth: root.bounded(
        root.instanceConfig?.width ?? root.roleConfig?.width,
        Appearance.sizes.sidebarWidth, 320,
        Math.max(320, (root.targetScreen?.width ?? 900)
            - Appearance.sizes.hyprlandGapsOut * 2))
    readonly property real minimumContentHeight: Math.min(root.availableHeight,
        Math.max(0, Number(contentLoader.item?.minimumUsefulHeight ?? 320)))
    readonly property real preferredContentHeight:
        Number(contentLoader.item?.preferredContentHeight ?? -1)
    readonly property bool customHeightRequested:
        String(root.instanceConfig?.sizeMode ?? root.roleConfig?.sizeMode ?? "fit") === "custom"
    readonly property real requestedHeight: root.customHeightRequested
        ? root.bounded(root.instanceConfig?.height
            ?? root.instanceConfig?.customHeight
            ?? root.roleConfig?.customHeight,
            720, root.minimumContentHeight, root.availableHeight)
        : root.preferredContentHeight > 0
            ? root.preferredContentHeight : root.minimumContentHeight
    readonly property real resolvedHeight: root.availableHeight > 0
        ? Math.max(root.minimumContentHeight,
            Math.min(root.availableHeight, root.requestedHeight)) : 0

    implicitWidth: root.targetScreen !== null ? root.requestedWidth : 0
    implicitHeight: root.targetScreen !== null ? root.resolvedHeight : 0
    visible: root.targetScreen !== null && (root.featureRole || root.systemRole)

    Loader {
        id: contentLoader
        active: root.visible
        width: root.width
        height: root.height
        sourceComponent: root.featureRole
            ? featureContent
            : root.compactSystem ? compactSystemContent : systemContent
    }

    Component {
        id: featureContent

        SidebarLeftContent {
            width: root.width
            height: root.height
            sidebarWidth: Math.round(root.width)
            screenWidth: root.targetScreen?.width ?? 1920
            screenHeight: root.targetScreen?.height ?? 1080
            panelScreen: root.targetScreen
            panelVisible: root.visible
            outerSizeMode: "fit"
        }
    }

    Component {
        id: systemContent

        SidebarRightContent {
            width: root.width
            height: root.height
            sidebarWidth: Math.round(root.width)
            screenWidth: root.targetScreen?.width ?? 1920
            screenHeight: root.targetScreen?.height ?? 1080
            panelScreen: root.targetScreen
            panelVisible: root.visible
        }
    }

    Component {
        id: compactSystemContent

        CompactSidebarRightContent {
            width: root.width
            height: root.height
            sidebarWidth: Math.round(root.width)
            screenWidth: root.targetScreen?.width ?? 1920
            screenHeight: root.targetScreen?.height ?? 1080
            panelScreen: root.targetScreen
            panelVisible: root.visible
        }
    }
}
