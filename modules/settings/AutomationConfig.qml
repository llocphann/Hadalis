pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    id: root
    settingsPageIndex: 35
    settingsPageName: Translation.tr("Automation")

    readonly property string bridge: Quickshell.shellPath("scripts/hadalis-automation-control.py")
    property string activeSection: "overview"
    property string selectedProfileId: ""
    property var snapshot: null
    property bool loaded: false
    property bool reloadDraftOnce: false
    property string errorText: ""
    property string pendingRemoveId: ""
    property string pendingParkOwnerId: ""
    property string pendingCleanupScope: ""
    property string pendingCleanupField: ""
    property string diagnosticText: ""
    property string logMessage: ""
    readonly property bool logsBusy: logsProcess.running
    readonly property string blockedOwnerId: root.selectedState?.status === "waiting_owner"
        ? (root.snapshot?.runtime?.owner_id ?? "") : ""
    readonly property var blockedOwnerState: root.blockedOwnerId
        && root.snapshot && root.snapshot.runtime && root.snapshot.runtime.profiles
        ? (root.snapshot.runtime.profiles[root.blockedOwnerId] ?? null) : null
    readonly property bool canParkBlockedOwner: !!root.blockedOwnerId
        && root.blockedOwnerState?.desired === "stopped"
        && root.blockedOwnerState?.pending !== null
        && root.blockedOwnerState?.status === "waiting_desktop"
        && String(root.blockedOwnerState?.last_error ?? "").includes("project guard is not visible")
    property int nowUnix: Math.floor(Date.now() / 1000)
    readonly property bool busy: actionProcess.running
    readonly property var profiles: root.snapshot?.config?.profiles ?? []
    readonly property var selectedProfile: root.profiles.find(p => p.id === root.selectedProfileId) ?? null
    readonly property var selectedState: root.snapshot?.runtime?.profiles?.[root.selectedProfileId] ?? null

    function activateSettingsSearchSection(section: string): bool {
        const label = String(section ?? "").toLowerCase()
        root.activeSection = label.includes("maint") || label.includes("archiv") ? "maintenance"
            : label.includes("histor") || label.includes("activ") ? "history"
            : label.includes("profile") || label.includes("prompt") || label.includes("sched") ? "profiles"
            : "overview"
        return true
    }

    function refresh(): void {
        if (!root.visible || statusProcess.running || actionProcess.running)
            return
        statusProcess.running = true
    }

    function runAction(parts): void {
        if (root.busy)
            return
        root.errorText = ""
        actionProcess.command = ["python3", root.bridge].concat(parts)
        actionProcess.running = true
    }

    function setProfile(field, value, confirmed = false): void {
        if (!root.selectedProfileId)
            return
        const args = ["profile-set", root.selectedProfileId, field, JSON.stringify(value)]
        if (confirmed) args.push("confirm-delete")
        root.runAction(args)
    }

    function setMaintenance(field, value, confirmed = false): void {
        const args = ["maintenance-set", field, JSON.stringify(value)]
        if (confirmed) args.push("confirm-delete")
        root.runAction(args)
    }

    function confirmCleanup(field, global): void {
        root.pendingCleanupScope = global ? "global" : root.selectedProfileId
        root.pendingCleanupField = field
    }

    function cancelConfirmation(): void {
        root.pendingRemoveId = ""
        root.pendingParkOwnerId = ""
        root.pendingCleanupScope = ""
        root.pendingCleanupField = ""
    }

    function applyCleanup(): void {
        const scope = root.pendingCleanupScope
        const field = root.pendingCleanupField
        root.cancelConfirmation()
        if (field !== "delete_completed" || root.busy) return
        if (scope === "global") root.setMaintenance(field, true, true)
        else if (scope && scope === root.selectedProfileId)
            root.setProfile(field, true, true)
    }

    function confirmRemoval(): void {
        const id = root.selectedProfileId
        if (!id || id === "strict-lossless-research" || root.busy) return
        if (root.snapshot?.runtime?.owner_id === id
            && (root.selectedState?.desired !== "stopped" || root.selectedState?.pending !== null)) {
            root.errorText = Translation.tr("Stop the profile and finish its current response before removing it.")
            return
        }
        root.pendingRemoveId = id
    }

    function applyRemoval(): void {
        const id = root.pendingRemoveId
        root.cancelConfirmation()
        if (id && id === root.selectedProfileId && id !== "strict-lossless-research")
            root.runAction(["profile-remove", id])
    }

    function confirmParkBlockedOwner(): void {
        if (!root.canParkBlockedOwner || root.busy) return
        root.pendingParkOwnerId = root.blockedOwnerId
    }

    function applyParkBlockedOwner(): void {
        const id = root.pendingParkOwnerId
        root.cancelConfirmation()
        if (id && id === root.blockedOwnerId)
            root.runAction(["profile-park-unresolved", id])
    }

    function refreshLogs(): void {
        if (!root.visible || root.activeSection !== "history" || root.logsBusy) return
        logsProcess.running = true
    }

    function copyLogs(): void {
        if (!root.diagnosticText.length) return
        Quickshell.clipboardText = root.diagnosticText
        root.logMessage = Translation.tr("Diagnostic log copied.")
    }

    function loadDraft(): void {
        if (!root.selectedProfile) return
        nameEditor.text = root.selectedProfile.name
        descriptionEditor.text = root.selectedProfile.description
        projectEditor.text = root.selectedProfile.project_name
        promptEditor.text = root.selectedProfile.prompt
        continuationEditor.text = root.selectedProfile.continuation_prompt
        rotationEditor.text = root.selectedProfile.rotation_prompt
    }

    function statusLabel(value): string {
        const labels = {
            active: "Active", inactive: "Inactive", starting: "Starting",
            stopping: "Stopping", failed: "Failed", blocked: "Blocked",
            unavailable: "Unavailable", thinking: "Thinking", waiting_result: "Waiting for local result",
            waiting_desktop: "Waiting for ChatGPT",
            continuing: "Continuing", restart_queued: "Restart queued",
            waiting_owner: "Waiting for previous profile",
            recovering_pending: "Recovering previous response",
            parked_unresolved: "Parked unresolved response",
            scheduler_unavailable: "Scheduler unavailable",
            invalid_configuration: "Invalid configuration",
            rotating: "Rotating chat", paused: "Paused",
            pausing: "Pausing", scheduled: "Scheduled", idle: "Idle", completed: "Completed",
            connector_blocked: "GitHub connector blocked", transport_unavailable: "Transport unavailable",
            disabled: "Disabled", running: "Running"
        }
        return Translation.tr(labels[value] ?? String(value ?? "Unknown"))
    }

    function statusColor(value): color {
        if (["active", "running", "continuing"].includes(value)) return Appearance.colors.colPrimary
        if (["failed", "connector_blocked", "blocked", "transport_unavailable", "scheduler_unavailable", "invalid_configuration", "parked_unresolved"].includes(value)) return Appearance.colors.colTertiary
        if (["starting", "stopping", "thinking", "waiting_result", "waiting_desktop", "waiting_owner", "recovering_pending", "rotating", "restart_queued", "pausing"].includes(value)) return Appearance.colors.colSecondary
        return Appearance.colors.colSubtext
    }

    function when(value): string {
        return value ? new Date(value * 1000).toLocaleString() : Translation.tr("Never")
    }

    function elapsed(value): string {
        if (!value) return "—"
        const seconds = Math.max(0, root.nowUnix - value)
        return Math.floor(seconds / 3600) + "h " + Math.floor(seconds % 3600 / 60) + "m"
    }

    onSelectedProfileIdChanged: {
        root.cancelConfirmation()
        Qt.callLater(root.loadDraft)
    }
    onActiveSectionChanged: {
        root.cancelConfirmation()
        if (root.activeSection === "history") Qt.callLater(root.refreshLogs)
    }
    onVisibleChanged: if (visible) {
        Qt.callLater(root.refresh)
        if (root.activeSection === "history") Qt.callLater(root.refreshLogs)
    }
    Component.onCompleted: Qt.callLater(root.refresh)

    Timer {
        interval: 4000
        running: root.visible
        repeat: true
        onTriggered: {
            root.nowUnix = Math.floor(Date.now() / 1000)
            root.refresh()
        }
    }

    Timer {
        interval: 15000
        running: root.visible && root.activeSection === "history"
        repeat: true
        onTriggered: root.refreshLogs()
    }

    Process {
        id: logsProcess
        command: ["python3", root.bridge, "logs"]
        stdout: StdioCollector { id: logsOutput }
        stderr: StdioCollector { id: logsError }
        onExited: exitCode => {
            try {
                const response = JSON.parse(logsOutput.text || logsError.text)
                if (exitCode !== 0 || response.ok !== true)
                    throw new Error(response.error ?? "Diagnostic log unavailable")
                root.diagnosticText = response.text ?? ""
            } catch (error) {
                root.logMessage = String(error)
            }
        }
    }

    Process {
        id: statusProcess
        command: ["python3", root.bridge, "status"]
        stdout: StdioCollector { id: statusOutput }
        stderr: StdioCollector { id: statusError }
        onExited: exitCode => {
            try {
                const response = JSON.parse(statusOutput.text || statusError.text)
                if (exitCode !== 0 || response.ok !== true)
                    throw new Error(response.error ?? "Automation status unavailable")
                root.snapshot = response
                root.loaded = true
                if (!root.selectedProfileId || !response.config.profiles.some(p => p.id === root.selectedProfileId))
                    root.selectedProfileId = response.config.profiles[0]?.id ?? ""
                if (root.reloadDraftOnce) {
                    root.reloadDraftOnce = false
                    Qt.callLater(root.loadDraft)
                }
                if (!root.errorText) root.errorText = ""
            } catch (error) {
                root.errorText = String(error)
            }
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: exitCode => {
            try {
                const response = JSON.parse(actionOutput.text || actionError.text)
                if (exitCode !== 0 || response.ok !== true)
                    throw new Error(response.error ?? "Automation action failed")
                if (response.profile_id) root.selectedProfileId = response.profile_id
                if (response.reload_draft) root.reloadDraftOnce = true
                if (response.path) {
                    root.logMessage = Translation.tr("Private diagnostic log saved: %1").arg(response.path)
                }
            } catch (error) {
                root.errorText = String(error)
            }
            Qt.callLater(root.refresh)
        }
    }

    SettingsTaskNavigator {
        icon: "smart_toy"
        title: Translation.tr("Automation")
        description: Translation.tr("Control Hadalis ChatGPT research sessions and their local services.")
        summary: Translation.tr("Service health · profiles · maintenance · activity")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Overview"), icon: "monitor_heart", value: "overview" },
            { displayName: Translation.tr("Profiles"), icon: "view_list", value: "profiles" },
            { displayName: Translation.tr("Maintenance"), icon: "cleaning_services", value: "maintenance" },
            { displayName: Translation.tr("Activity"), icon: "history", value: "history" }
        ]
    }

    SettingsNote {
        visible: root.errorText.length > 0
        warning: true
        icon: "error"
        text: root.errorText
    }
    SettingsNote {
        visible: !!root.snapshot?.scheduler_problem
        warning: true
        icon: "error"
        text: root.snapshot?.scheduler_problem ?? ""
    }
    SettingsNote {
        visible: root.snapshot?.issues?.length > 0
        warning: true
        icon: "warning"
        text: (root.snapshot?.issues ?? []).join(" · ")
    }

    SettingsCardSection {
        settingsTaskSection: "overview"
        visible: root.activeSection === "overview"
        expanded: true
        icon: "monitor_heart"
        title: Translation.tr("Automation services")

        SettingsGroup {
            Repeater {
                model: ["chatgpt", "worker", "bridge"]
                delegate: ColumnLayout {
                    id: serviceRow
                    required property string modelData
                    readonly property var service: root.snapshot?.services?.[modelData] ?? ({ state: "unavailable", detail: "" })
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle { width: 9; height: 9; radius: 5; color: root.statusColor(serviceRow.service.state) }
                        StyledText {
                            Layout.fillWidth: true
                            text: ({ chatgpt: "ChatGPT Desktop", worker: "Local worker", bridge: "Chat bridge" })[serviceRow.modelData]
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            text: root.statusLabel(serviceRow.service.state)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.statusColor(serviceRow.service.state)
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: serviceRow.service.detail.length > 0
                        text: serviceRow.service.detail + (serviceRow.service.result && serviceRow.service.result !== "success" ? " · " + serviceRow.service.result : "")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: childrenRect.height
                        spacing: 4
                        DialogButton { buttonText: Translation.tr("Start"); enabled: !root.busy && serviceRow.service.state !== "active"; onClicked: root.runAction(["service", "start", serviceRow.modelData]) }
                        DialogButton { buttonText: Translation.tr("Stop"); enabled: !root.busy && serviceRow.service.state === "active"; onClicked: root.runAction(["service", "stop", serviceRow.modelData]) }
                        DialogButton { buttonText: Translation.tr("Restart"); enabled: !root.busy && serviceRow.service.state !== "unavailable"; onClicked: root.runAction(["service", "restart", serviceRow.modelData]) }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "overview"
        visible: root.activeSection === "overview"
        expanded: true
        icon: "hub"
        title: Translation.tr("Transport ownership")
        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.snapshot?.runtime?.owner_id
                    ? Translation.tr("ChatGPT is assigned to %1. Other profiles wait until it stops.").arg(root.profiles.find(p => p.id === root.snapshot.runtime.owner_id)?.name ?? root.snapshot.runtime.owner_id)
                    : Translation.tr("No profile currently owns the ChatGPT composer.")
                color: Appearance.colors.colOnSurface
            }
            SettingsNote {
                text: Translation.tr("A paused profile keeps its chat. Stop it to let the next queued profile run. Pauses and stops finish the current ChatGPT response first.")
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "profiles"
        visible: root.activeSection === "profiles"
        expanded: true
        icon: "view_list"
        title: Translation.tr("Automation profiles")

        SettingsGroup {
            Repeater {
                model: root.profiles
                delegate: RowLayout {
                    id: profileRow
                    required property var modelData
                    readonly property var run: root.snapshot?.runtime?.profiles?.[modelData.id] ?? ({ status: "idle" })
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle { width: 9; height: 9; radius: 5; color: root.statusColor(profileRow.modelData.enabled ? profileRow.run.status : "disabled") }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText { Layout.fillWidth: true; text: profileRow.modelData.name; elide: Text.ElideRight; color: Appearance.colors.colOnSurface }
                        StyledText { Layout.fillWidth: true; text: root.statusLabel(profileRow.run.parked_pending ? profileRow.run.status : (profileRow.modelData.enabled ? profileRow.run.status : "disabled")); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                    }
                    DialogButton { buttonText: Translation.tr("Edit"); onClicked: root.selectedProfileId = profileRow.modelData.id }
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("New profile"); enabled: !root.busy; onClicked: root.runAction(["profile-create", "New automation"]) }
                DialogButton { buttonText: Translation.tr("Duplicate selected"); enabled: !root.busy && !!root.selectedProfile; onClicked: root.runAction(["profile-duplicate", root.selectedProfileId, root.selectedProfile.name + " copy"]) }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "profiles"
        visible: root.activeSection === "profiles" && !!root.selectedProfile
        expanded: true
        icon: "tune"
        title: root.selectedProfile?.name ?? Translation.tr("Selected profile")

        SettingsGroup {
            SettingsSwitch {
                text: Translation.tr("Enabled")
                buttonIcon: "power_settings_new"
                checked: root.selectedProfile?.enabled ?? false
                autoToggle: false
                onToggledByUser: checked => root.setProfile("enabled", checked)
            }
            SettingsNote { text: Translation.tr("GitHub is required for Hadalis repository automations. ChatGPT remains the only reasoning agent.") }
            MaterialTextField { id: nameEditor; Layout.fillWidth: true; placeholderText: Translation.tr("Profile name") }
            MaterialTextField { id: descriptionEditor; Layout.fillWidth: true; placeholderText: Translation.tr("Description (optional)") }
            SettingsNote { text: Translation.tr("Exact ChatGPT Desktop project name. Stop this profile before changing its project.") }
            MaterialTextField { id: projectEditor; Layout.fillWidth: true; placeholderText: Translation.tr("ChatGPT project") }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Save name"); enabled: !root.busy; onClicked: root.setProfile("name", nameEditor.text) }
                DialogButton { buttonText: Translation.tr("Save description"); enabled: !root.busy; onClicked: root.setProfile("description", descriptionEditor.text) }
                DialogButton { buttonText: Translation.tr("Save project"); enabled: !root.busy && root.snapshot?.runtime?.owner_id !== root.selectedProfileId; onClicked: root.setProfile("project_name", projectEditor.text) }
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Start"); enabled: !root.busy && (root.selectedProfile?.enabled ?? false); onClicked: root.runAction(["profile-action", "start", root.selectedProfileId]) }
                DialogButton { buttonText: Translation.tr("Pause"); enabled: !root.busy && root.selectedState?.desired === "run"; onClicked: root.runAction(["profile-action", "pause", root.selectedProfileId]) }
                DialogButton { buttonText: Translation.tr("Resume"); enabled: !root.busy && root.selectedState?.desired === "paused"; onClicked: root.runAction(["profile-action", "resume", root.selectedProfileId]) }
                DialogButton { buttonText: Translation.tr("Stop"); enabled: !root.busy; onClicked: root.runAction(["profile-action", "stop", root.selectedProfileId]) }
                DialogButton { buttonText: Translation.tr("Restart"); enabled: !root.busy && (root.selectedProfile?.enabled ?? false); onClicked: root.runAction(["profile-action", "restart", root.selectedProfileId]) }
                DialogButton {
                    buttonText: Translation.tr("Remove")
                    enabled: !root.busy && root.selectedProfileId !== "strict-lossless-research"
                    onClicked: root.confirmRemoval()
                }
            }
            SettingsNote {
                visible: root.snapshot?.runtime?.owner_id === root.selectedProfileId
                    && root.selectedState?.desired !== "stopped"
                text: Translation.tr("Stop this profile first. Wait for its current response to finish.")
            }
            SettingsNote {
                visible: !!root.selectedState?.status_detail
                text: root.selectedState?.status_detail ?? ""
            }
            SettingsNote {
                visible: root.canParkBlockedOwner
                warning: true
                text: Translation.tr("Open the previous profile's original ChatGPT project chat to recover it, or park the unresolved turn to continue.")
            }
            Flow {
                visible: root.canParkBlockedOwner && root.pendingParkOwnerId !== root.blockedOwnerId
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton {
                    buttonText: Translation.tr("Park unresolved previous turn")
                    enabled: !root.busy
                    onClicked: root.confirmParkBlockedOwner()
                }
            }
            SettingsNote {
                visible: root.pendingParkOwnerId === root.blockedOwnerId
                warning: true
                text: Translation.tr("The old pending baseline is kept, but that profile will require manual reconciliation.")
            }
            Flow {
                visible: root.pendingParkOwnerId === root.blockedOwnerId
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                DialogButton {
                    buttonText: Translation.tr("Confirm park and continue")
                    enabled: !root.busy
                    onClicked: root.applyParkBlockedOwner()
                }
            }
            SettingsNote {
                visible: root.pendingRemoveId === root.selectedProfileId
                warning: true
                text: Translation.tr("Remove this profile? ChatGPT conversation history will be kept.")
            }
            Flow {
                visible: root.pendingRemoveId === root.selectedProfileId
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                DialogButton { buttonText: Translation.tr("Confirm remove"); enabled: !root.busy; onClicked: root.applyRemoval() }
            }
        }

        SettingsGroup {
            StyledText { text: Translation.tr("Execution mode"); color: Appearance.colors.colOnSurface }
            ConfigSelectionArray {
                currentValue: root.selectedProfile?.mode ?? "manual"
                options: [
                    { displayName: Translation.tr("Manual"), value: "manual" },
                    { displayName: Translation.tr("Continuous"), value: "continuous" },
                    { displayName: Translation.tr("Interval"), value: "interval" },
                    { displayName: Translation.tr("Duration"), value: "duration" },
                    { displayName: Translation.tr("Iterations"), value: "iterations" }
                ]
                onSelected: value => root.setProfile("mode", value)
            }
            ConfigSpinBox { text: Translation.tr("Interval (minutes)"); visible: root.selectedProfile?.mode === "interval"; from: 1; to: 43200; value: (root.selectedProfile?.interval_seconds ?? 3600) / 60; onValueModified: root.setProfile("interval_seconds", value * 60) }
            ConfigSpinBox { text: Translation.tr("Run duration (minutes)"); visible: root.selectedProfile?.mode === "duration"; from: 1; to: 43200; value: (root.selectedProfile?.duration_seconds ?? 3600) / 60; onValueModified: root.setProfile("duration_seconds", value * 60) }
            ConfigSelectionArray {
                visible: root.selectedProfile?.mode === "duration"
                currentValue: root.selectedProfile?.duration_action ?? "stop"
                options: [ { displayName: Translation.tr("Stop"), value: "stop" }, { displayName: Translation.tr("Pause"), value: "pause" }, { displayName: Translation.tr("Rotate"), value: "rotate" } ]
                onSelected: value => root.setProfile("duration_action", value)
            }
            ConfigSpinBox { text: Translation.tr("Iteration limit (0 = unlimited)"); from: root.selectedProfile?.mode === "iterations" ? 1 : 0; to: 1000000; value: root.selectedProfile?.iteration_limit ?? 0; onValueModified: root.setProfile("iteration_limit", value) }
            ConfigSpinBox { text: Translation.tr("Prompt limit (0 = unlimited)"); from: 0; to: 1000000; value: root.selectedProfile?.prompt_limit ?? 0; onValueModified: root.setProfile("prompt_limit", value) }
            ConfigSpinBox { text: Translation.tr("Rotate after iterations (0 = off)"); from: 0; to: 1000000; value: root.selectedProfile?.rotate_after_iterations ?? 0; onValueModified: root.setProfile("rotate_after_iterations", value) }
            ConfigSpinBox { text: Translation.tr("Rotate after minutes (0 = off)"); from: 0; to: 43200; value: (root.selectedProfile?.rotate_after_seconds ?? 0) / 60; onValueModified: root.setProfile("rotate_after_seconds", value * 60) }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "profiles"
        visible: root.activeSection === "profiles" && !!root.selectedProfile
        expanded: false
        icon: "edit_note"
        title: Translation.tr("Prompts")
        SettingsGroup {
            StyledText { text: Translation.tr("Bootstrap prompt"); color: Appearance.colors.colOnSurface }
            MaterialTextArea { id: promptEditor; Layout.fillWidth: true; Layout.preferredHeight: 160; placeholderText: Translation.tr("Initial prompt") }
            Flow {
                Layout.fillWidth: true; Layout.preferredHeight: childrenRect.height; spacing: 6
                DialogButton { buttonText: Translation.tr("Save prompt"); enabled: !root.busy; onClicked: root.setProfile("prompt", promptEditor.text) }
                DialogButton { buttonText: Translation.tr("Reset to saved"); onClicked: root.loadDraft() }
                DialogButton { buttonText: Translation.tr("Reset default"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "prompt"]) }
            }
            StyledText { text: Translation.tr("Continuation prompt"); color: Appearance.colors.colOnSurface }
            MaterialTextArea { id: continuationEditor; Layout.fillWidth: true; Layout.preferredHeight: 110 }
            DialogButton { buttonText: Translation.tr("Save continuation"); enabled: !root.busy; onClicked: root.setProfile("continuation_prompt", continuationEditor.text) }
            DialogButton { buttonText: Translation.tr("Reset continuation"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "continuation_prompt"]) }
            StyledText { text: Translation.tr("Rotation prompt"); color: Appearance.colors.colOnSurface }
            MaterialTextArea { id: rotationEditor; Layout.fillWidth: true; Layout.preferredHeight: 110 }
            DialogButton { buttonText: Translation.tr("Save rotation"); enabled: !root.busy; onClicked: root.setProfile("rotation_prompt", rotationEditor.text) }
            DialogButton { buttonText: Translation.tr("Reset rotation"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "rotation_prompt"]) }
            SettingsNote { text: Translation.tr("Mandatory GitHub, current dev, ChatGPT-only and no Work mode rules remain attached to edited prompts.") }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "profiles"
        visible: root.activeSection === "profiles" && !!root.selectedProfile
        expanded: false
        icon: "health_and_safety"
        title: Translation.tr("Advanced recovery and cleanup")
        SettingsGroup {
            ConfigSpinBox { text: Translation.tr("Consecutive polling errors before pause"); from: 0; to: 100; value: root.selectedProfile?.max_poll_errors ?? 3; onValueModified: root.setProfile("max_poll_errors", value) }
            ConfigSpinBox { text: Translation.tr("Retry delay (seconds)"); from: 1; to: 3600; value: root.selectedProfile?.retry_delay_seconds ?? 30; onValueModified: root.setProfile("retry_delay_seconds", value) }
            ConfigSpinBox { text: Translation.tr("Local result fetch failures before pause"); from: 0; to: 100; value: root.selectedProfile?.max_failures ?? 3; onValueModified: root.setProfile("max_failures", value) }
            SettingsNote { text: Translation.tr("Polling retries use bounded backoff. A failed submission is never resent automatically; its status needs review.") }
            SettingsSwitch { text: Translation.tr("Archive completed chats (pending desktop support)"); checked: root.selectedProfile?.archive_completed ?? true; autoToggle: false; onToggledByUser: checked => root.setProfile("archive_completed", checked) }
            SettingsSwitch { text: Translation.tr("Delete completed chats (pending desktop support)"); checked: root.selectedProfile?.delete_completed ?? false; autoToggle: false; enabled: !(root.selectedProfile?.archive_completed ?? true); onToggledByUser: checked => checked ? root.confirmCleanup("delete_completed", false) : root.setProfile("delete_completed", false) }
            SettingsNote {
                visible: root.pendingCleanupScope === root.selectedProfileId && root.pendingCleanupField === "delete_completed"
                warning: true
                text: Translation.tr("Save deletion preference? Chat deletion is not implemented.")
            }
            Flow {
                visible: root.pendingCleanupScope === root.selectedProfileId && root.pendingCleanupField === "delete_completed"
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                DialogButton { buttonText: Translation.tr("Confirm preference"); enabled: !root.busy; onClicked: root.applyCleanup() }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "maintenance"
        visible: root.activeSection === "maintenance"
        expanded: true
        icon: "cleaning_services"
        title: Translation.tr("Session maintenance")
        SettingsGroup {
            SettingsSwitch { text: Translation.tr("Archive completed sessions (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.archive_completed ?? true; autoToggle: false; onToggledByUser: checked => root.setMaintenance("archive_completed", checked) }
            SettingsSwitch { text: Translation.tr("Delete completed sessions (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.delete_completed ?? false; autoToggle: false; enabled: !(root.snapshot?.config?.maintenance?.archive_completed ?? true); onToggledByUser: checked => checked ? root.confirmCleanup("delete_completed", true) : root.setMaintenance("delete_completed", false) }
            SettingsSwitch { text: Translation.tr("Archive old sessions (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.archive_old ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("archive_old", checked) }
            SettingsSwitch { text: Translation.tr("Clean abandoned sessions (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.cleanup_abandoned ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("cleanup_abandoned", checked) }
            SettingsSwitch { text: Translation.tr("Recover stuck generation (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.recover_stuck_generation ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("recover_stuck_generation", checked) }
            SettingsSwitch { text: Translation.tr("Recover stale composer (pending desktop support)"); checked: root.snapshot?.config?.maintenance?.recover_stale_composer ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("recover_stale_composer", checked) }
            SettingsNote { warning: true; icon: "info"; text: Translation.tr("ChatGPT Desktop has no verified semantic archive or delete control. These preferences persist but no chat is changed. Active or uncertain chats are never cleaned.") }
            SettingsNote {
                visible: root.pendingCleanupScope === "global" && root.pendingCleanupField === "delete_completed"
                warning: true
                text: Translation.tr("Save deletion preference? Chat deletion is not implemented.")
            }
            Flow {
                visible: root.pendingCleanupScope === "global" && root.pendingCleanupField === "delete_completed"
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                DialogButton { buttonText: Translation.tr("Confirm preference"); enabled: !root.busy; onClicked: root.applyCleanup() }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "history"
        visible: root.activeSection === "history"
        expanded: true
        icon: "history"
        title: Translation.tr("Recent activity")
        SettingsGroup {
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 6
                DialogButton { buttonText: Translation.tr("Refresh logs"); enabled: !root.logsBusy; onClicked: root.refreshLogs() }
                DialogButton { buttonText: Translation.tr("Copy logs"); enabled: root.diagnosticText.length > 0; onClicked: root.copyLogs() }
                DialogButton { buttonText: Translation.tr("Export to /tmp"); enabled: !root.busy; onClicked: root.runAction(["logs-export"]) }
            }
            SettingsNote {
                text: Translation.tr("System logs may contain private data. Review before sharing. Exports use private permissions.")
            }
            StyledText {
                visible: root.logMessage.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.logMessage
                color: Appearance.colors.colSecondary
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                clip: true
                MaterialTextArea {
                    width: parent.width
                    readOnly: true
                    selectByMouse: true
                    enableSettingsSearch: false
                    text: root.diagnosticText || Translation.tr("Open Activity or select Refresh logs to load diagnostics.")
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.selectedProfile?.name ?? Translation.tr("Select a profile")
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
            Repeater {
                model: (root.snapshot?.runtime?.events ?? []).filter(e => e.profile_id === root.selectedProfileId || e.profile_id === null).slice().reverse()
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    StyledText { Layout.fillWidth: true; text: modelData.kind + (modelData.detail ? " · " + modelData.detail : ""); wrapMode: Text.WordWrap; color: Appearance.colors.colOnSurface }
                    StyledText { text: root.when(modelData.at_unix); font.pixelSize: Appearance.font.pixelSize.smallest; color: Appearance.colors.colSubtext }
                }
            }
            SettingsNote { text: Translation.tr("Only the most recent 100 operational events are kept.") }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "history"
        visible: root.activeSection === "history" && !!root.selectedProfile
        expanded: true
        icon: "info"
        title: Translation.tr("Current run")
        SettingsGroup {
            StyledText { text: Translation.tr("Status: %1").arg(root.statusLabel(root.selectedState?.status ?? "idle")); color: Appearance.colors.colOnSurface }
            StyledText {
                visible: !!root.selectedState?.status_detail
                Layout.fillWidth: true
                text: root.selectedState?.status_detail ?? ""
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSecondary
            }
            StyledText { text: Translation.tr("Loop: %1 · Job: %2").arg(root.selectedState?.loop_state || "—").arg(root.selectedState?.job_id || root.selectedState?.last_job_id || "—"); color: Appearance.colors.colOnSurface }
            StyledText { text: Translation.tr("Elapsed: %1 · Iterations: %2 · Prompts: %3").arg(root.elapsed(root.selectedState?.started_at_unix)).arg(root.selectedState?.iterations ?? 0).arg(root.selectedState?.prompts_sent ?? 0); color: Appearance.colors.colOnSurface }
            StyledText { text: Translation.tr("Polling errors: %1 · Last result: %2").arg(root.selectedState?.poll_errors ?? 0).arg(root.selectedState?.last_result || "—"); color: Appearance.colors.colOnSurface }
            StyledText { text: Translation.tr("Accumulated failures: %1").arg(root.selectedState?.failures ?? 0); color: Appearance.colors.colOnSurface }
            StyledText { text: Translation.tr("Last run: %1").arg(root.when(root.selectedState?.last_run_at_unix)); color: Appearance.colors.colOnSurface }
            StyledText { text: Translation.tr("Next run: %1").arg(root.when(root.selectedState?.next_run_at_unix)); color: Appearance.colors.colOnSurface }
            SettingsNote { visible: !!root.selectedState?.last_error; warning: true; icon: "error"; text: root.selectedState?.last_error ?? "" }
        }
    }
}
