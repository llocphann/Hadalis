import qs.modules.bar
import qs.services
import QtQuick

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"

    implicitWidth: monitorLoader.item?.implicitWidth ?? 0
    implicitHeight: monitorLoader.item?.implicitHeight ?? 0

    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

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
                iconName: "memory"
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: 90
            }
            Resource {
                iconName: "thermostat"
                percentage: ResourceUsage.tempPercentage
                cautionThreshold: 65
                warningThreshold: 80
            }
            Resource {
                iconName: "planner_review"
                percentage: ResourceUsage.cpuUsage
                warningThreshold: 90
            }
            Resource {
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
                iconName: "memory"
                percentage: ResourceUsage.memoryUsedPercentage
                warningThreshold: 90
            }
            Resource {
                iconName: "thermostat"
                percentage: ResourceUsage.tempPercentage
                cautionThreshold: 65
                warningThreshold: 80
            }
            Resource {
                iconName: "planner_review"
                percentage: ResourceUsage.cpuUsage
                warningThreshold: 90
            }
            Resource {
                iconName: "memory_alt"
                percentage: ResourceUsage.gpuUsage
                warningThreshold: 90
            }
        }
    }
}
