import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: popup

    readonly property bool thinkFanManaged:
        ThinkFanService.stateKnown && ThinkFanService.profile === "managed"
    readonly property bool thinkFanCanApply:
        ThinkFanService.stateKnown
        && ThinkFanService.serviceInstalled
        && !ThinkFanService.busy
        && (popup.thinkFanManaged || ThinkFanService.available)
    readonly property string thinkFanStatusMessage: {
        if (ThinkFanService.busy)
            return Translation.tr("Applying fan control profile…")
        if (!ThinkFanService.stateKnown)
            return popup.describeThinkFanStatus(ThinkFanService.statusReason)
        if (ThinkFanService.statusReason.length > 0)
            return popup.describeThinkFanStatus(ThinkFanService.statusReason)
        return popup.thinkFanManaged
            ? Translation.tr("ThinkFan is managing the fan")
            : Translation.tr("Firmware controls the fan")
    }
    readonly property string thinkFanApplyErrorMessage:
        popup.describeThinkFanApplyError(ThinkFanService.lastApplyError)

    function describeThinkFanStatus(reason): string {
        switch (String(reason ?? "")) {
        case "":
            return Translation.tr("Checking ThinkFan status…")
        case "thinkfan-unavailable":
            return Translation.tr("ThinkFan is unavailable")
        case "service-unavailable":
            return Translation.tr("thinkfan.service is unavailable")
        case "firmware-control":
            return Translation.tr("Firmware controls the fan")
        case "invalid-status":
            return Translation.tr("ThinkFan returned invalid status")
        case "unsupported-status-schema":
            return Translation.tr("ThinkFan status schema is unsupported")
        case "helper-unavailable":
            return Translation.tr("ThinkFan helper is unavailable")
        case "status-timeout":
            return Translation.tr("ThinkFan status check timed out")
        case "status-failed":
            return Translation.tr("ThinkFan status check failed")
        default:
            return Translation.tr("ThinkFan status unavailable: %1").arg(reason)
        }
    }

    function describeThinkFanApplyError(error): string {
        switch (String(error ?? "")) {
        case "":
            return ""
        case "unsupported-profile":
            return Translation.tr("Unsupported ThinkFan profile")
        case "apply-busy":
            return Translation.tr("Another ThinkFan change is already in progress")
        case "service-unavailable":
            return Translation.tr("thinkfan.service is unavailable")
        case "thinkfan-unavailable":
            return Translation.tr("ThinkFan is unavailable")
        case "apply-start-failed":
            return Translation.tr("Could not start the privileged ThinkFan helper")
        case "apply-timeout":
            return Translation.tr("Changing the ThinkFan profile timed out")
        case "apply-failed":
            return Translation.tr("Changing the ThinkFan profile failed")
        default:
            return Translation.tr("ThinkFan profile change failed: %1").arg(error)
        }
    }

    onActiveChanged: {
        if (!popup.active)
            return
        ResourceUsage.ensureRunning()
        ThinkFanService.refresh()
    }

    component ResourceItem: RowLayout {
        id: resourceItem
        required property string icon
        required property string label
        required property string value
        spacing: 4

        MaterialSymbol {
            text: resourceItem.icon
            color: Appearance.colors.colOnSurfaceVariant
            iconSize: Appearance.font.pixelSize.large
        }
        StyledText {
            text: resourceItem.label
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: resourceItem.value !== ""
            color: Appearance.colors.colOnSurfaceVariant
            text: resourceItem.value
        }
    }

    component ResourceHeaderItem: Row {
        id: headerItem
        required property var icon
        required property var label
        spacing: 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 0
            font.weight: Font.Medium
            text: headerItem.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: headerItem.label
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    ColumnLayout {
        spacing: 12

        Row {
            id: resourcesRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Column {
                anchors.top: parent.top
                spacing: 8

                ResourceHeaderItem {
                    icon: "memory"
                    label: "RAM"
                }
                Column {
                    spacing: 4
                    ResourceItem {
                        icon: "clock_loader_60"
                        label: Translation.tr("Used:")
                        value: (ResourceUsage.memoryUsed / (1024 * 1024)).toFixed(1) + " GB"
                    }
                    ResourceItem {
                        icon: "check_circle"
                        label: Translation.tr("Free:")
                        value: (ResourceUsage.memoryFree / (1024 * 1024)).toFixed(1) + " GB"
                    }
                    ResourceItem {
                        icon: "empty_dashboard"
                        label: Translation.tr("Total:")
                        value: (ResourceUsage.memoryTotal / (1024 * 1024)).toFixed(1) + " GB"
                    }
                }
            }

            Column {
                anchors.top: parent.top
                spacing: 8

                ResourceHeaderItem {
                    icon: "thermostat"
                    label: Translation.tr("Temperature")
                }
                Column {
                    spacing: 4
                    ResourceItem {
                        icon: "memory"
                        label: "CPU:"
                        value: ResourceUsage.cpuTemp + "°C"
                    }
                    ResourceItem {
                        icon: "memory_alt"
                        label: "GPU:"
                        value: ResourceUsage.gpuTemp + "°C"
                    }
                }
            }

            Column {
                anchors.top: parent.top
                spacing: 8

                ResourceHeaderItem {
                    icon: "planner_review"
                    label: "CPU"
                }
                Column {
                    spacing: 4
                    ResourceItem {
                        icon: "bolt"
                        label: Translation.tr("Load:")
                        value: (ResourceUsage.cpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.cpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.cpuUsage * 100)}%)`
                    }
                    ResourceItem {
                        icon: "memory_alt"
                        label: Translation.tr("GPU:")
                        value: (ResourceUsage.gpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.gpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.gpuUsage * 100)}%)`
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
            opacity: 0.65
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: resourcesRow.implicitWidth
            spacing: 10

            MaterialSymbol {
                text: "mode_fan"
                fill: popup.thinkFanManaged ? 1 : 0
                iconSize: Appearance.font.pixelSize.huge
                color: popup.thinkFanManaged
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurfaceVariant
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("ThinkFan")
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: popup.thinkFanStatusMessage
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            StyledSwitch {
                id: thinkFanProfileSwitch
                checked: popup.thinkFanManaged
                enabled: popup.thinkFanCanApply
                activeFocusOnTab: true
                Accessible.name: Translation.tr("Use ThinkFan managed fan control")

                onToggled: {
                    const requestedManaged = checked
                    ThinkFanService.applyProfile(
                        requestedManaged ? "managed" : "firmware")
                    checked = Qt.binding(() => popup.thinkFanManaged)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: Translation.tr("Fan speed")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                StyledText {
                    text: ThinkFanService.fanRpm >= 0
                        ? Translation.tr("%1 RPM").arg(ThinkFanService.fanRpm)
                        : "—"
                    font.weight: Font.Medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: Translation.tr("Fan level")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                StyledText {
                    text: ThinkFanService.fanLevel.length > 0
                        ? ThinkFanService.fanLevel : "—"
                    font.weight: Font.Medium
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    text: Translation.tr("Service")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                StyledText {
                    text: ThinkFanService.serviceInstalled
                        ? (ThinkFanService.active
                            ? Translation.tr("Active")
                            : Translation.tr("Inactive"))
                        : Translation.tr("Unavailable")
                    font.weight: Font.Medium
                }
            }
        }

        NoticeBox {
            visible: popup.thinkFanApplyErrorMessage.length > 0
            Layout.fillWidth: true
            materialIcon: "warning"
            text: popup.thinkFanApplyErrorMessage
        }
    }
}