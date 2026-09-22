import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root

    CodeWorkflowRuntimeTarget {
        runtimeObject: root
        targetId: "bar/resources"
        label: "Bar · Resources"
        icon: "memory"
        kind: "component"
        family: "ii"
        panelId: "iiBar"
        parentId: "bar"
        depth: 1
        sourcePath: "modules/bar/Resources.qml"
    }

    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    activeFocusOnTab: true

    Accessible.role: Accessible.StaticText
    Accessible.name: Translation.tr("System resources")
    Accessible.focusable: true

    property bool _resourceUsageHeld: false
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

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: Config.options?.bar?.resources?.showMemoryIndicator ?? true
            warningThreshold: Config.options?.bar?.resources?.memoryWarningThreshold ?? 90
        }

        Resource {
            iconName: "thermostat"
            percentage: ResourceUsage.tempPercentage
            shown: (Config.options?.bar?.resources?.showTempIndicator ?? true) &&
                ((Config.options?.bar?.resources?.alwaysShowTemp ?? true) ||
                    !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                    root.alwaysShowAllResources)
            Layout.leftMargin: shown ? 6 : 0
            cautionThreshold: Config.options?.bar?.resources?.tempCautionThreshold ?? 65
            warningThreshold: Config.options?.bar?.resources?.tempWarningThreshold ?? 80
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: (Config.options?.bar?.resources?.showCpuIndicator ?? true) &&
                ((Config.options?.bar?.resources?.alwaysShowCpu ?? true) ||
                    !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                    root.alwaysShowAllResources)
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options?.bar?.resources?.cpuWarningThreshold ?? 90
        }

        Resource {
            iconName: "memory_alt"
            percentage: ResourceUsage.gpuUsage
            shown: (Config.options?.bar?.resources?.showGpuIndicator ?? true) &&
                ((Config.options?.bar?.resources?.alwaysShowGpu ?? true) ||
                    !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                    root.alwaysShowAllResources)
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options?.bar?.resources?.gpuWarningThreshold ?? 90
        }

    }

    KeyboardFocusRing {
        anchors.fill: parent
        focusVisible: root.activeFocus
    }

    ResourcesPopup {
        hoverTarget: root
        alternativeVisibleCondition: root.activeFocus
    }
}
