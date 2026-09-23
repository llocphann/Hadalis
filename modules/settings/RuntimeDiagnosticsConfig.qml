import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 31
    settingsPageName: Translation.tr("Diagnostics")

    readonly property int targetCount:
        CodeWorkflowRuntime.activeCatalog.length
    readonly property int collisionCount:
        CodeWorkflowRuntime.identityCollisions.length

    SettingsCardSection {
        expanded: true
        icon: "monitoring"
        title: Translation.tr("Runtime diagnostics")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: RuntimeDiagnosticsSession.pageCurrent
                    ? Translation.tr("Diagnostics session active")
                    : Translation.tr("Diagnostics session inactive")
                color: RuntimeDiagnosticsSession.pageCurrent
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Sampling is leased only while this page is current. Leaving the page stops diagnostics work even if Settings keeps this page cached.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "account_tree"
        title: Translation.tr("Workflow identity")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Canonical targets") + " · "
                    + String(root.targetCount)
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                text: root.collisionCount === 0
                    ? Translation.tr("No canonical identity collisions detected")
                    : Translation.tr("Identity collisions") + " · "
                        + String(root.collisionCount)
                color: root.collisionCount === 0
                    ? Appearance.colors.colSubtext
                    : Appearance.colors.colError
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "memory"
        title: Translation.tr("Resource probes")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("CPU · RAM · Swap · GPU · Network")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("The session and identity foundation is active. Exact shell/system samplers are added behind this lease before per-target attribution.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }
}
