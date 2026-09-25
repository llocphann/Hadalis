import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar

MouseArea {
    id: root
    property bool alwaysShowAllResources: false
    implicitHeight: columnLayout.implicitHeight
    implicitWidth: columnLayout.implicitWidth
    hoverEnabled: true

    property bool _resourceUsageHeld: false
    // The Bar resource readout is itself a persistent telemetry consumer.
    // Hover only controls the popup; it must never decide whether sampling lives.
    readonly property bool _resourceUsageWanted: root.visible && !GameMode.active

    function syncResourceUsageLifecycle(): void {
        if (root._resourceUsageWanted === root._resourceUsageHeld)
            return
        if (root._resourceUsageWanted)
            ResourceUsage.keepAlive()
        else
            ResourceUsage.releaseKeepAlive()
        root._resourceUsageHeld = root._resourceUsageWanted
    }

    Component.onCompleted: root.syncResourceUsageLifecycle()
    Component.onDestruction: {
        if (root._resourceUsageHeld) {
            root._resourceUsageHeld = false
            ResourceUsage.releaseKeepAlive()
        }
    }
    onVisibleChanged: root.syncResourceUsageLifecycle()

    Connections {
        target: GameMode
        function onActiveChanged(): void { root.syncResourceUsageLifecycle() }
    }

    ColumnLayout {
        id: columnLayout
        spacing: 10 * Appearance.sizes.barModuleScale
        anchors.fill: parent

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: Config.options?.bar?.resources?.showMemoryIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.memoryWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: Config.options?.bar?.resources?.showSwapIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.swapWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options?.bar?.resources?.showCpuIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.cpuWarningThreshold ?? 90
        }

        Resource {
            Layout.alignment: Qt.AlignHCenter
            iconName: "memory_alt"
            percentage: ResourceUsage.gpuUsage
            shown: Config.options?.bar?.resources?.showGpuIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.gpuWarningThreshold ?? 90
        }

    }

    Bar.ResourcesPopup {
        hoverTarget: root
    }
}
