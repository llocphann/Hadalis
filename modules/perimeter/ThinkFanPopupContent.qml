import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    implicitWidth: 320
    spacing: 12

    readonly property bool managed:
        ThinkFanService.stateKnown && ThinkFanService.profile === "managed"
    readonly property bool canApply:
        ThinkFanService.stateKnown
        && ThinkFanService.serviceInstalled
        && !ThinkFanService.busy
        && (root.managed || ThinkFanService.available)
    readonly property string statusMessage: {
        if (ThinkFanService.busy)
            return Translation.tr("Applying fan control profile…")
        if (!ThinkFanService.stateKnown)
            return root.describeStatus(ThinkFanService.statusReason)
        if (ThinkFanService.statusReason.length > 0)
            return root.describeStatus(ThinkFanService.statusReason)
        return root.managed
            ? Translation.tr("ThinkFan is managing the fan")
            : Translation.tr("Firmware controls the fan")
    }
    readonly property string applyErrorMessage:
        root.describeApplyError(ThinkFanService.lastApplyError)

    function focusInitialControl(): void {
        profileSwitch.forceActiveFocus()
    }

    function describeStatus(reason): string {
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

    function describeApplyError(error): string {
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        MaterialSymbol {
            text: "mode_fan"
            fill: root.managed ? 1 : 0
            iconSize: Appearance.font.pixelSize.huge
            color: root.managed
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
                text: root.statusMessage
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: telemetryLayout.implicitHeight + 20
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colSurfaceContainer

        GridLayout {
            id: telemetryLayout
            anchors.fill: parent
            anchors.margins: 10
            columns: 2
            columnSpacing: 16
            rowSpacing: 6

            StyledText {
                text: Translation.tr("Fan speed")
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.alignment: Qt.AlignRight
                text: ThinkFanService.fanRpm >= 0
                    ? Translation.tr("%1 RPM").arg(ThinkFanService.fanRpm)
                    : "—"
                font.weight: Font.Medium
            }

            StyledText {
                text: Translation.tr("Fan level")
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.alignment: Qt.AlignRight
                text: ThinkFanService.fanLevel.length > 0
                    ? ThinkFanService.fanLevel : "—"
                font.weight: Font.Medium
            }

            StyledText {
                text: Translation.tr("Service")
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                Layout.alignment: Qt.AlignRight
                text: ThinkFanService.serviceInstalled
                    ? (ThinkFanService.active
                        ? Translation.tr("Active")
                        : Translation.tr("Inactive"))
                    : Translation.tr("Unavailable")
                font.weight: Font.Medium
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: profileLayout.implicitHeight + 20
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colSurfaceContainer

        RowLayout {
            id: profileLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.managed
                        ? Translation.tr("Managed by ThinkFan")
                        : Translation.tr("Firmware control")
                    font.weight: Font.Medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Changing control mode may require administrator authorization.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            StyledSwitch {
                id: profileSwitch
                checked: root.managed
                enabled: root.canApply
                activeFocusOnTab: true
                Accessible.name: Translation.tr("Use ThinkFan managed fan control")

                onToggled: {
                    const requestedManaged = checked
                    ThinkFanService.applyProfile(
                        requestedManaged ? "managed" : "firmware")
                    checked = Qt.binding(() => root.managed)
                }
            }
        }
    }

    NoticeBox {
        visible: root.applyErrorMessage.length > 0
        Layout.fillWidth: true
        materialIcon: "warning"
        text: root.applyErrorMessage
    }
}
