pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 19
    pageTitle: Translation.tr("Diagnostics")
    pageIcon: "info"
    pageDescription: Translation.tr("On-demand runtime resource diagnostics")

    readonly property int targetCount:
        CodeWorkflowRuntime.activeCatalog.length
    readonly property int collisionCount:
        CodeWorkflowRuntime.identityCollisions.length

    WSettingsCard {
        title: Translation.tr("Runtime diagnostics")
        icon: "info"

        WSettingsRow {
            label: RuntimeDiagnosticsSession.pageCurrent
                ? Translation.tr("Diagnostics session active")
                : Translation.tr("Diagnostics session inactive")
            description: Translation.tr("Sampling is leased only while this page is current.")
            icon: "info"
        }

        WText {
            Layout.fillWidth: true
            text: Translation.tr("Leaving Diagnostics stops diagnostics-owned sampling immediately; a short server TTL also cleans up crashed standalone Settings clients.")
            color: Looks.colors.subfg
            font.pixelSize: Looks.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
    }

    WSettingsCard {
        title: Translation.tr("Workflow identity")
        icon: "apps"

        WSettingsRow {
            label: Translation.tr("Canonical targets")
            description: String(root.targetCount)
            icon: "apps"
        }

        WSettingsRow {
            label: Translation.tr("Identity collisions")
            description: String(root.collisionCount)
            icon: "info"
        }
    }

    WSettingsCard {
        title: Translation.tr("Resource probes")
        icon: "info"

        WSettingsRow {
            label: Translation.tr("CPU · RAM · Swap · GPU · Network")
            description: Translation.tr("Exact shell/system samplers are added behind the active diagnostics lease before per-target attribution.")
            icon: "info"
        }
    }
}
