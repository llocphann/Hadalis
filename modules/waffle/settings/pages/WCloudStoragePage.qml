pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.waffle.settings

// Independent Waffle standalone Settings uses positional page index 19.
// This native Waffle page only consumes the dormant shared static detect service.
WSettingsPage {
    id: root
    settingsPageIndex: 19
    pageTitle: Translation.tr("Cloud Storage")
    pageIcon: "cloud"
    pageDescription: Translation.tr("MEGAcmd dependency status")

    property bool leaseHeld: false
    property string activeGroup: "overview"
    property string activeSection: "overview"
    readonly property var groups: [
        {key:"overview", label:Translation.tr("Overview"),
         sections:[{key:"overview",label:Translation.tr("Overview")}]},
        {key:"files", label:Translation.tr("Files"),
         sections:[{key:"drive",label:Translation.tr("Drive")},
                   {key:"transfers",label:Translation.tr("Transfers")}]},
        {key:"sync-backup", label:Translation.tr("Sync & Backup"),
         sections:[{key:"sync",label:Translation.tr("Sync Folders")},
                   {key:"backups",label:Translation.tr("Backups")}]},
        {key:"sharing", label:Translation.tr("Sharing"),
         sections:[{key:"sharing",label:Translation.tr("Sharing")},
                   {key:"contacts",label:Translation.tr("Contacts")}]},
        {key:"advanced", label:Translation.tr("Advanced"),
         sections:[{key:"mounts",label:Translation.tr("Mounts & Local Access")},
                   {key:"security",label:Translation.tr("Account & Security")},
                   {key:"preferences",label:Translation.tr("Preferences & Diagnostics")}]}
    ]
    readonly property var currentGroup: root.groups.find(group => group.key === root.activeGroup)
        ?? root.groups[0]
    readonly property var currentSection: root.currentGroup.sections.find(
        section => section.key === root.activeSection) ?? root.currentGroup.sections[0]

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

    WSettingsCard {
        title: Translation.tr("Sections")
        icon: "cloud"
        WSettingsDropdown {
            label: Translation.tr("Area")
            icon: "cloud"
            currentValue: root.activeGroup
            options: root.groups.map(group => ({value:group.key, displayName:group.label}))
            onSelected: value => {
                const group = root.groups.find(item => item.key === value)
                if (group) root.setSection(group.sections[0].key)
            }
        }
        WSettingsDropdown {
            visible: root.currentGroup.sections.length > 1
            label: Translation.tr("Section")
            icon: "folder"
            currentValue: root.activeSection
            options: root.currentGroup.sections.map(item => ({
                value:item.key, displayName:item.label
            }))
            onSelected: value => root.setSection(value)
        }
        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Info
            message: Translation.tr("Static detection only: opening Settings never starts the MEGAcmd server.")
        }
    }
    WSettingsCard {
        visible: root.activeSection === "overview"
        title: Translation.tr("MEGAcmd dependency status")
        icon: "cloud"
        WSettingsInfoBar {
            severity: CloudStorageService.backendState === "installed_disconnected"
                ? WSettingsInfoBar.Severity.Info : WSettingsInfoBar.Severity.Warning
            message: CloudStorageService.backendState === "checking"
                ? Translation.tr("Checking executables")
                : CloudStorageService.backendState === "installed_disconnected"
                ? Translation.tr("MEGAcmd detected; not connected")
                : CloudStorageService.backendState === "dependency_missing"
                ? Translation.tr("MEGAcmd shell or server executable missing")
                : CloudStorageService.backendState === "stale"
                ? Translation.tr("Last check is stale")
                : Translation.tr("Dependency state not verified")
        }
        WSettingsInfoBar {
            visible: CloudStorageService.dependencySnapshot !== null
            severity: WSettingsInfoBar.Severity.Info
            message: Translation.tr("Shell: %1 · Server: %2")
                .arg(CloudStorageService.dependencySnapshot?.shell
                     ? Translation.tr("Found") : Translation.tr("Missing"))
                .arg(CloudStorageService.dependencySnapshot?.server
                     ? Translation.tr("Found") : Translation.tr("Missing"))
        }
        WSettingsInfoBar {
            visible: CloudStorageService.dependencySnapshot !== null
            severity: WSettingsInfoBar.Severity.Info
            message: "mega-login: " + (CloudStorageService.dependencySnapshot?.login
                ? Translation.tr("Found") : Translation.tr("Missing"))
                + "\nmega-whoami: " + (CloudStorageService.dependencySnapshot?.whoami
                ? Translation.tr("Found") : Translation.tr("Missing"))
                + "\nmega-version: " + (CloudStorageService.dependencySnapshot?.version
                ? Translation.tr("Found") : Translation.tr("Missing"))
        }
        WSettingsInfoBar {
            visible: CloudStorageService.safeError.length > 0
            severity: WSettingsInfoBar.Severity.Warning
            message: CloudStorageService.safeError
        }
        WSettingsButton {
            label: Translation.tr("MEGAcmd dependency status")
            icon: "cloud"
            buttonText: Translation.tr("Recheck dependencies")
            enabled: root.leaseHeld && !CloudStorageService.readBusy
            onButtonClicked: CloudStorageService.refreshStatic()
        }
    }
    WSettingsCard {
        visible: root.activeSection !== "overview"
        title: root.currentSection.label
        icon: "folder"
        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Warning
            message: Translation.tr("Unavailable until installed-version capabilities and parsers are qualified.")
        }
    }
    WSettingsCard {
        title: Translation.tr("Qualification boundary")
        icon: "shield"
        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Warning
            message: Translation.tr("Sign-in, account reads and writes remain disabled; do not enter MEGA credentials.")
        }
        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Info
            message: Translation.tr("Closing Settings does not stop external MEGA Desktop or vendor sync.")
        }
    }
}
