import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Compact system monitor: glanceable load cards with short history graphs,
 * thermal/storage status and ThinkFan control in one visual hierarchy.
 * ResourceUsage polling is held only while this Dashboard module is visible.
 */
DashCard {
    id: root
    title: Translation.tr("System")
    icon: "monitor_heart"

    readonly property bool thinkFanManaged:
        ThinkFanService.stateKnown && ThinkFanService.profile === "managed"
    readonly property bool thinkFanCanApply:
        ThinkFanService.stateKnown
        && ThinkFanService.serviceInstalled
        && !ThinkFanService.busy
        && (root.thinkFanManaged || ThinkFanService.available)

    readonly property color cpuColor:
        ResourceUsage.cpuUsage > 0.85 ? Appearance.colors.colError
        : ResourceUsage.cpuUsage > 0.65 ? Appearance.colors.colTertiary
        : Appearance.colors.colPrimary
    readonly property color memoryColor:
        ResourceUsage.memoryUsedPercentage > 0.9 ? Appearance.colors.colError
        : ResourceUsage.memoryUsedPercentage > 0.75 ? Appearance.colors.colTertiary
        : Appearance.colors.colSecondary
    readonly property color gpuColor:
        ResourceUsage.gpuUsage > 0.9 ? Appearance.colors.colError
        : ResourceUsage.gpuUsage > 0.7 ? Appearance.colors.colTertiary
        : Appearance.colors.colPrimary

    property QtObject resourceMonitor: ResourceUsageMonitor {
        network: false
        target: root
    }
    onVisibleChanged: {
        if (root.visible)
            ThinkFanService.refresh()
    }
    Component.onCompleted: {
        if (root.visible)
            ThinkFanService.refresh()
    }

    component UsageRow: ColumnLayout {
        id: usageRow
        property string label: ""
        property real value: 0
        Layout.fillWidth: true
        visible: root.zzzEverywhere
        spacing: 4

        ZzzStatBar {
            label: usageRow.label
            value: usageRow.value
            fillColor: usageRow.label === Translation.tr("Memory") ? Appearance.zzz.secondary
                : usageRow.label === Translation.tr("GPU") ? Appearance.zzz.tertiary
                : Appearance.zzz.accent
            textColor: root.colText
            labelColor: root.colSubtext
        }
    }

    component MetricTile: Rectangle {
        id: metric
        required property string label
        required property string iconName
        required property real value
        required property var history
        required property color accent

        Layout.fillWidth: true
        Layout.preferredHeight: root.compact ? 70 : 82
        radius: Appearance.rounding.small
        color: ColorUtils.applyAlpha(metric.accent, 0.08)
        border.width: 1
        border.color: ColorUtils.applyAlpha(metric.accent, 0.14)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? 7 : 9
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialSymbol {
                    text: metric.iconName
                    iconSize: Appearance.font.pixelSize.small
                    color: metric.accent
                }

                StyledText {
                    Layout.fillWidth: true
                    text: metric.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                    elide: Text.ElideRight
                }

                StyledText {
                    text: Math.round(metric.value * 100) + "%"
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                        family: Appearance.font.family.numbers
                        weight: Font.DemiBold
                    }
                    color: metric.accent
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: ColorUtils.applyAlpha(metric.accent, 0.12)
                }

                Graph {
                    anchors.fill: parent
                    values: metric.history
                    points: Math.min(metric.history.length, 24)
                    color: metric.accent
                    fillOpacity: 0.12
                    lineWidth: 1.4
                    alignment: Graph.Alignment.Right
                }
            }
        }
    }

    component StatusChip: Rectangle {
        id: chip
        required property string iconName
        required property string label
        required property string valueText
        property color accent: root.colAccent

        Layout.fillWidth: true
        implicitHeight: root.compact ? 30 : 34
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainer
        border.width: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 7
            spacing: 4

            MaterialSymbol {
                text: chip.iconName
                iconSize: Appearance.font.pixelSize.small
                color: chip.accent
            }
            StyledText {
                Layout.fillWidth: true
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colSubtext
                elide: Text.ElideRight
            }
            StyledText {
                text: chip.valueText
                font {
                    pixelSize: Appearance.font.pixelSize.smallest
                    family: Appearance.font.family.numbers
                    weight: Font.Medium
                }
                color: chip.accent
            }
        }
    }

    UsageRow {
        label: Translation.tr("CPU")
        value: ResourceUsage.cpuUsage
    }
    UsageRow {
        label: Translation.tr("Memory")
        value: ResourceUsage.memoryUsedPercentage
    }
    UsageRow {
        visible: root.zzzEverywhere && ResourceUsage.gpuUsage > 0
        label: Translation.tr("GPU")
        value: ResourceUsage.gpuUsage
    }

    GridLayout {
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        columns: 3
        columnSpacing: root.compact ? 5 : 7
        rowSpacing: 0

        MetricTile {
            label: Translation.tr("CPU")
            iconName: "memory"
            value: ResourceUsage.cpuUsage
            history: ResourceUsage.cpuUsageHistory
            accent: root.cpuColor
        }
        MetricTile {
            label: Translation.tr("RAM")
            iconName: "memory_alt"
            value: ResourceUsage.memoryUsedPercentage
            history: ResourceUsage.memoryUsageHistory
            accent: root.memoryColor
        }
        MetricTile {
            label: Translation.tr("GPU")
            iconName: "videogame_asset"
            value: ResourceUsage.gpuUsage
            history: ResourceUsage.gpuUsageHistory
            accent: root.gpuColor
        }
    }

    RowLayout {
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        spacing: root.compact ? 5 : 7

        StatusChip {
            iconName: "thermostat"
            label: Translation.tr("CPU")
            valueText: ResourceUsage.cpuTemp > 0
                ? ResourceUsage.cpuTemp + "°" : "—"
            accent: ResourceUsage.cpuTemp >= ResourceUsage.tempWarningThreshold
                ? Appearance.colors.colError : root.colAccent
        }
        StatusChip {
            iconName: "device_thermostat"
            label: Translation.tr("GPU")
            valueText: ResourceUsage.gpuTemp > 0
                ? ResourceUsage.gpuTemp + "°" : "—"
            accent: ResourceUsage.gpuTemp >= ResourceUsage.tempWarningThreshold
                ? Appearance.colors.colError : root.gpuColor
        }
        StatusChip {
            iconName: "hard_drive"
            label: Translation.tr("Disk")
            valueText: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
            accent: ResourceUsage.diskUsedPercentage > 0.9
                ? Appearance.colors.colError : root.colAccent
        }
    }

    Rectangle {
        id: fanPanel
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        implicitHeight: root.compact ? 42 : 48
        radius: Appearance.rounding.small
        color: root.thinkFanManaged
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.09)
            : Appearance.colors.colSurfaceContainer
        border.width: 1
        border.color: root.thinkFanManaged
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.18)
            : ColorUtils.applyAlpha(root.colSubtext, 0.08)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 7

            MaterialSymbol {
                text: "mode_fan"
                fill: root.thinkFanManaged ? 1 : 0
                iconSize: Appearance.font.pixelSize.normal
                color: root.thinkFanManaged
                    ? Appearance.colors.colPrimary : root.colSubtext
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Fan control")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: root.colText
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.thinkFanManaged
                        ? Translation.tr("ThinkFan managed")
                        : Translation.tr("Firmware")
                    font.pixelSize: Math.max(9, Appearance.font.pixelSize.smallest - 1)
                    color: root.colSubtext
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 2
                StyledText {
                    text: Translation.tr("RPM:")
                    font.pixelSize: Math.max(9, Appearance.font.pixelSize.smallest - 1)
                    color: root.colSubtext
                }
                StyledText {
                    text: ThinkFanService.fanRpm >= 0
                        ? String(ThinkFanService.fanRpm) : "—"
                    font {
                        pixelSize: Appearance.font.pixelSize.smallest
                        family: Appearance.font.family.numbers
                        weight: Font.DemiBold
                    }
                    color: root.colText
                }
            }

            Rectangle {
                implicitWidth: levelText.implicitWidth + 10
                implicitHeight: 24
                radius: 12
                color: ColorUtils.applyAlpha(root.colSubtext, 0.09)

                StyledText {
                    id: levelText
                    anchors.centerIn: parent
                    text: ThinkFanService.fanLevel.length > 0
                        ? Translation.tr("L%1").arg(ThinkFanService.fanLevel)
                        : "L—"
                    font {
                        pixelSize: Appearance.font.pixelSize.smallest
                        family: Appearance.font.family.numbers
                        weight: Font.Medium
                    }
                    color: root.colText
                }
            }

            StyledSwitch {
                checked: root.thinkFanManaged
                enabled: root.thinkFanCanApply
                activeFocusOnTab: true
                Accessible.name:
                    Translation.tr("Use ThinkFan managed fan control")
                onToggled: {
                    ThinkFanService.applyProfile(
                        checked ? "managed" : "firmware")
                    checked = Qt.binding(() => root.thinkFanManaged)
                }
            }
        }
    }
}
