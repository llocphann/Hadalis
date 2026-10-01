pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 36
    settingsPageName: Translation.tr("Cloud Storage")
    property bool leaseHeld: false
    property string activeGroup: "overview"
    property string activeSection: "overview"
    readonly property var groups: [
        {key:"overview", label:Translation.tr("Overview"), icon:"dashboard",
         sections:[{key:"overview",label:Translation.tr("Overview")}]},
        {key:"files", label:Translation.tr("Files"), icon:"folder",
         sections:[{key:"drive",label:Translation.tr("Drive")},
                   {key:"transfers",label:Translation.tr("Transfers")}]},
        {key:"sync-backup", label:Translation.tr("Sync & Backup"), icon:"sync",
         sections:[{key:"sync",label:Translation.tr("Sync Folders")},
                   {key:"backups",label:Translation.tr("Backups")}]},
        {key:"sharing", label:Translation.tr("Sharing"), icon:"share",
         sections:[{key:"sharing",label:Translation.tr("Sharing")},
                   {key:"contacts",label:Translation.tr("Contacts")}]},
        {key:"advanced", label:Translation.tr("Advanced"), icon:"tune",
         sections:[{key:"mounts",label:Translation.tr("Mounts & Local Access")},
                   {key:"security",label:Translation.tr("Account & Security")},
                   {key:"preferences",label:Translation.tr("Preferences & Diagnostics")}]}
    ]
    readonly property var currentGroup: root.groups.find(g => g.key === root.activeGroup) ?? root.groups[0]
    readonly property var currentSection: root.currentGroup.sections.find(s => s.key === root.activeSection)
        ?? root.currentGroup.sections[0]

    function setSection(value) {
        for (const group of root.groups) {
            if (group.sections.some(section => section.key === value)) {
                root.activeGroup = group.key
                root.activeSection = value
                return true
            }
        }
        return false
    }
    function selectGroup(value) {
        const group = root.groups.find(g => g.key === value)
        if (group) root.setSection(group.sections[0].key)
    }
    function activateSettingsSearchSection(section: string): bool {
        const value = String(section ?? "").toLowerCase().trim()
        return root.setSection(value) || root.setSection(
            value.includes("transfer") ? "transfers"
            : value.includes("backup") ? "backups"
            : value.includes("sync") ? "sync"
            : value.includes("drive") || value.includes("file") ? "drive"
            : value.includes("contact") ? "contacts"
            : value.includes("shar") ? "sharing"
            : value.includes("mount") ? "mounts"
            : value.includes("secur") || value.includes("account") ? "security"
            : value.includes("prefer") || value.includes("diagnostic") ? "preferences"
            : "overview")
    }
    function syncLease() {
        if (root.visible && !root.leaseHeld) {
            root.leaseHeld = true
            CloudStorageService.registerConsumer()
        } else if (!root.visible && root.leaseHeld) {
            root.leaseHeld = false
            CloudStorageService.unregisterConsumer()
        }
    }
    Component.onCompleted: root.syncLease()
    Component.onDestruction: {
        if (root.leaseHeld) CloudStorageService.unregisterConsumer()
    }
    onVisibleChanged: root.syncLease()

    SettingsTaskNavigator {
        visible: root.width >= 800
        showIntro: false
        highContrastSelection: true
        currentValue: root.activeGroup
        options: root.groups.map(g => ({displayName:g.label,icon:g.icon,value:g.key}))
        onSelected: value => root.selectGroup(value)
    }
    SettingsCardSection {
        visible: root.width < 800
        expanded: true
        icon: "cloud"
        title: Translation.tr("Area")
        SettingsGroup {
            StyledComboBox {
                Layout.fillWidth: true
                model: root.groups.map(g => g.label)
                currentIndex: Math.max(0, root.groups.findIndex(g => g.key === root.activeGroup))
                onActivated: index => root.selectGroup(root.groups[index].key)
            }
        }
    }
    SettingsCardSection {
        visible: root.currentGroup.sections.length > 1
        expanded: true
        icon: root.currentGroup.icon
        title: Translation.tr("Section")
        SettingsGroup {
            StyledComboBox {
                Layout.fillWidth: true
                model: root.currentGroup.sections.map(s => s.label)
                currentIndex: Math.max(0, root.currentGroup.sections.findIndex(s => s.key === root.activeSection))
                onActivated: index => root.setSection(root.currentGroup.sections[index].key)
            }
        }
    }
    SettingsNote {
        text: Translation.tr("Static only · no server start")
    }
    SettingsCardSection {
        visible: root.activeSection === "overview"
        expanded: true
        icon: "monitor_heart"
        title: Translation.tr("MEGAcmd status")
        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurface
                wrapMode: Text.WordWrap
                text: CloudStorageService.backendState === "checking"
                    ? Translation.tr("Checking executables")
                    : CloudStorageService.backendState === "installed_disconnected"
                    ? Translation.tr("Detected · disconnected")
                    : CloudStorageService.backendState === "dependency_missing"
                    ? Translation.tr("Required tools missing")
                    : CloudStorageService.backendState === "stale"
                    ? Translation.tr("Previous result stale")
                    : Translation.tr("Not checked")
            }
            StyledText {
                visible: CloudStorageService.dependencySnapshot !== null
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Shell: %1 · Server: %2")
                    .arg(CloudStorageService.dependencySnapshot?.shell
                         ? Translation.tr("Found") : Translation.tr("Missing"))
                    .arg(CloudStorageService.dependencySnapshot?.server
                         ? Translation.tr("Found") : Translation.tr("Missing"))
            }
            // Show the complete, allowlisted static executable inventory.
            // No vendor paths or subprocess output is exposed.
            StyledText {
                visible: CloudStorageService.dependencySnapshot !== null
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                text: "mega-login: " + (CloudStorageService.dependencySnapshot?.login
                    ? Translation.tr("Found") : Translation.tr("Missing"))
                    + "\nmega-whoami: " + (CloudStorageService.dependencySnapshot?.whoami
                    ? Translation.tr("Found") : Translation.tr("Missing"))
                    + "\nmega-version: " + (CloudStorageService.dependencySnapshot?.version
                    ? Translation.tr("Found") : Translation.tr("Missing"))
            }
            SettingsNote {
                visible: CloudStorageService.safeError.length > 0
                warning: true
                text: CloudStorageService.safeError
            }
            RippleButton {
                id: recheckButton
                buttonText: Translation.tr("Recheck")
                Accessible.name: Translation.tr("Recheck MEGAcmd dependencies")
                horizontalPadding: 10
                verticalPadding: 6
                contentItem: RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "refresh"
                        iconSize: 17
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        text: recheckButton.buttonText
                        color: Appearance.colors.colOnLayer0
                    }
                }
                enabled: root.leaseHeld && !CloudStorageService.readBusy
                onClicked: CloudStorageService.refreshStatic()
            }
        }
    }
    SettingsCardSection {
        visible: root.activeSection === "overview"
        expanded: true
        icon: "verified_user"
        title: Translation.tr("Offline readiness")
        SettingsGroup {
            SettingsNote {
                text: Translation.tr("Offline only · no server or login")
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Appearance.colors.colOnSurface
                text: CloudStorageService.preflightState === "checking"
                    ? Translation.tr("Checking local tools")
                    : CloudStorageService.preflightState === "dependencies_ready"
                    ? Translation.tr("Tools ready · sign-in disabled")
                    : CloudStorageService.preflightState === "dependency_missing"
                    ? Translation.tr("Tools missing · offline only")
                    : CloudStorageService.preflightState === "unavailable"
                    ? Translation.tr("Check unavailable")
                    : Translation.tr("Not checked")
            }
            SettingsNote {
                visible: CloudStorageService.preflightError.length > 0
                warning: true
                text: CloudStorageService.preflightError
            }
            RippleButton {
                id: offlineCheckButton
                buttonText: Translation.tr("Offline check")
                Accessible.name: Translation.tr("Check connection readiness (offline)")
                horizontalPadding: 10
                verticalPadding: 6
                contentItem: RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "shield"
                        iconSize: 17
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        text: offlineCheckButton.buttonText
                        color: Appearance.colors.colOnLayer0
                    }
                }
                enabled: root.leaseHeld && !CloudStorageService.preflightBusy
                onClicked: CloudStorageService.requestConnectPreflight()
            }
        }
    }
    SettingsCardSection {
        visible: root.activeSection !== "overview"
        expanded: true
        icon: root.currentGroup.icon
        title: root.currentSection.label
        SettingsGroup {
            SettingsNote {
                warning: true
                text: Translation.tr("Unavailable · verification pending")
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "verified_user"
        title: Translation.tr("Safety")
        SettingsGroup {
            SettingsNote {
                text: Translation.tr("Sign-in and cloud access disabled")
            }
            SettingsNote {
                text: Translation.tr("Closing Settings won\u0027t stop external sync")
            }
        }
    }
}
