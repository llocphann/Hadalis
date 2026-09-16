import qs.modules.bar
import qs.services
import QtQuick

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property string outputName: String(root.perimeterContext?.outputName ?? "")
    readonly property bool presented:
        PerimeterPresentationPolicy.barPresentedForOutput(root.outputName)
    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    property bool _resourceUsageHeld: false

    implicitWidth: root.presented ? (monitorLoader.item?.implicitWidth ?? 0) : 0
    implicitHeight: root.presented ? (monitorLoader.item?.implicitHeight ?? 0) : 0
    visible: root.presented
    enabled: root.presented

    function syncResourceUsageLifecycle(): void {
        if (root.presented === root._resourceUsageHeld)
            return
        if (root.presented)
            ResourceUsage.keepAlive()
        else
            ResourceUsage.releaseKeepAlive()
        root._resourceUsageHeld = root.presented
    }

    Component.onCompleted: root.syncResourceUsageLifecycle()
    onPresentedChanged: root.syncResourceUsageLifecycle()
    Component.onDestruction: {
        if (root._resourceUsageHeld)
            ResourceUsage.releaseKeepAlive()
        root._resourceUsageHeld = false
    }

    Loader {
        id: monitorLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? verticalMonitor : horizontalMonitor
    }

    Component {
        id: horizontalMonitor

        Row {
            spacing: 6

            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "memory"
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: 90
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "thermostat"
                percentage: ResourceUsage.tempPercentage
                cautionThreshold: 65
                warningThreshold: 80
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "planner_review"
                percentage: ResourceUsage.cpuUsage
                warningThreshold: 90
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "memory_alt"
                percentage: ResourceUsage.gpuUsage
                warningThreshold: 90
            }
        }
    }

    Component {
        id: verticalMonitor

        Column {
            spacing: 2

            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "memory"
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: 90
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "thermostat"
                percentage: ResourceUsage.tempPercentage
                cautionThreshold: 65
                warningThreshold: 80
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "planner_review"
                percentage: ResourceUsage.cpuUsage
                warningThreshold: 90
            }
            Resource {
                width: implicitWidth
                height: implicitHeight
                iconName: "memory_alt"
                percentage: ResourceUsage.gpuUsage
                warningThreshold: 90
            }
        }
    }
}
