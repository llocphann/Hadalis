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
        warning: true
        text: Translation.tr("Static detection only: opening Settings never starts the MEGAcmd server.")
    }
    SettingsCardSection {
        visible: root.activeSection === "overview"
        expanded: true
        icon: "monitor_heart"
        title: Translation.tr("MEGAcmd dependency status")
        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurface
                wrapMode: Text.WordWrap
                text: CloudStorageService.backendState === "checking"
                    ? Translation.tr("Checking executables")
                    : CloudStorageService.backendState === "installed_disconnected"
                    ? Translation.tr("MEGAcmd detected; not connected")
                    : CloudStorageService.backendState === "dependency_missing"
                    ? Translation.tr("MEGAcmd shell or server executable missing")
                    : CloudStorageService.backendState === "stale"
                    ? Translation.tr("Last check is stale")
                    : Translation.tr("Dependency state not verified")
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
            SettingsNote {
                visible: CloudStorageService.safeError.length > 0
                warning: true
                text: CloudStorageService.safeError
            }
            RippleButton {
                buttonText: Translation.tr("Recheck dependencies")
                enabled: root.leaseHeld && !CloudStorageService.readBusy
                onClicked: CloudStorageService.refreshStatic()
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
                text: Translation.tr("Unavailable until installed-version capabilities and parsers are qualified.")
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "verified_user"
        title: Translation.tr("Qualification boundary")
        SettingsGroup {
            SettingsNote {
                text: Translation.tr("Sign-in, account reads and writes remain disabled; do not enter MEGA credentials.")
            }
            SettingsNote {
                text: Translation.tr("Closing Settings does not stop external MEGA Desktop or vendor sync.")
            }
        }
    }
}
