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

    readonly property string bridge: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/hadalis-automation/control.py"
    property string activeSection: "overview"
    property string selectedProfileId: ""
    property var snapshot: null
    property bool loaded: false
    property bool reloadDraftOnce: false
    property string errorText: ""
    property string pendingRemoveId: ""
    property bool pendingRemoveUnresolved: false
    property string pendingCleanupScope: ""
    property string pendingCleanupField: ""
    property string diagnosticText: ""
    property string logMessage: ""
    property bool showDiagnostics: false
    property string secretInput: ""
    readonly property bool tokenSaved: root.snapshot?.credentials?.github?.[root.selectedProfileId] ?? false
    readonly property var activityEvents: (root.snapshot?.runtime?.events ?? []).filter(e => !root.selectedProfileId || e.profile_id === root.selectedProfileId || e.profile_id === null).reverse()
    readonly property string activityText: root.activityEvents.map(e => {
        const name = root.profiles.find(p => p.id === e.profile_id)?.name ?? Translation.tr("System")
        const time = Qt.formatDateTime(new Date(e.at_unix * 1000), "MM-dd HH:mm:ss")
        return time + "  " + name + " · " + String(e.kind).replace(/_/g, " ") + (e.detail ? "\n" + e.detail : "")
    }).join("\n\n")
    readonly property string visibleLogText: root.showDiagnostics ? root.diagnosticText : root.activityText
    readonly property bool logsBusy: logsProcess.running
    property int nowUnix: Math.floor(Date.now() / 1000)
    readonly property bool busy: actionProcess.running || secretProcess.running
    readonly property var profiles: root.snapshot?.config?.profiles ?? []
    readonly property var selectedProfile: root.profiles.find(p => p.id === root.selectedProfileId) ?? null
    readonly property var selectedState: root.snapshot?.runtime?.profiles?.[root.selectedProfileId] ?? null
    readonly property var thinkingEfforts: ["instant", "standard", "extended"]
    readonly property var thinkingLabels: ["Instant", "Medium", "High"]
    readonly property string savedThinkingEffort: root.selectedProfile?.thinking_effort ?? "extended"
    readonly property string defaultThinkingEffort: root.snapshot?.config?.default_thinking_effort ?? "extended"

    function thinkingIndex(effort): int {
        const index = root.thinkingEfforts.indexOf(effort)
        return index < 0 ? 2 : index
    }

    onSavedThinkingEffortChanged: if (!thinkingSlider.pressed)
        thinkingSlider.value = root.thinkingIndex(root.savedThinkingEffort)

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
        root.pendingRemoveUnresolved = false
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

    function confirmRemoval(profileId = root.selectedProfileId): void {
        const id = profileId
        if (!id || root.busy) return
        root.selectedProfileId = id
        const item = root.snapshot?.runtime?.profiles?.[id]
        root.pendingRemoveUnresolved = root.snapshot?.runtime?.owner_id === id
            || (!!item?.pending && !item?.parked_pending)
        root.pendingRemoveId = id
    }

    function applyRemoval(): void {
        const id = root.pendingRemoveId
        const unresolved = root.pendingRemoveUnresolved
        root.cancelConfirmation()
        if (id && id === root.selectedProfileId) {
            const args = ["profile-remove", id]
            if (unresolved) args.push("confirm-unresolved")
            root.runAction(args)
        }
    }

    function refreshLogs(): void {
        if (!root.visible || root.activeSection !== "history" || !root.showDiagnostics || root.logsBusy) return
        logsProcess.running = true
    }

    function copyLogs(): void {
        if (!root.visibleLogText.length) return
        Quickshell.clipboardText = root.visibleLogText
        root.logMessage = Translation.tr("Copied")
    }

    function saveToken(): void {
        if (root.busy || !githubToken.text.length || !root.selectedProfileId) return
        root.errorText = ""
        root.secretInput = githubToken.text
        githubToken.clear()
        secretProcess.command = ["python3", root.bridge, "github-token-save", root.selectedProfileId]
        secretProcess.stdinEnabled = true
        secretProcess.running = true
    }

    function loadDraft(): void {
        if (!root.selectedProfile) return
        nameEditor.text = root.selectedProfile.name
        projectEditor.text = root.selectedProfile.project_name
        promptEditor.text = root.selectedProfile.prompt
        continuationEditor.text = root.selectedProfile.continuation_prompt
        rotationEditor.text = root.selectedProfile.rotation_prompt
        thinkingSlider.value = root.thinkingIndex(root.savedThinkingEffort)
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
            disabled: "Disabled", running: "Running",
            submission_uncertain: "Verifying submission", stream_failed: "Response interrupted",
            response_unavailable: "Response unavailable", transport_rate_limited: "Rate limited",
            thinking_unavailable: "Effort unavailable",
            recovering_generation: "Recovering workflow", recovery_required: "Recovery needs review",
            session_changed: "Managed chat changed", session_conflict: "Managed chat conflict", evidence_required: "Evidence needs review"
        }
        return Translation.tr(labels[value] ?? String(value ?? "Unknown"))
    }

    function statusColor(value): color {
        if (["active", "running", "continuing"].includes(value)) return Appearance.colors.colPrimary
        if (["failed", "connector_blocked", "blocked", "transport_unavailable", "transport_rate_limited", "thinking_unavailable", "stream_failed", "response_unavailable", "scheduler_unavailable", "invalid_configuration", "parked_unresolved"].includes(value)) return Appearance.colors.colTertiary
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
        githubToken.clear()
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
        id: secretProcess
        stdinEnabled: true
        stdout: StdioCollector { id: secretOutput }
        stderr: StdioCollector { id: secretError }
        onRunningChanged: if (!running) root.secretInput = ""
        onStarted: {
            secretProcess.write(root.secretInput)
            root.secretInput = ""
            secretProcess.stdinEnabled = false
        }
        onExited: exitCode => {
            root.secretInput = ""
            try {
                const response = JSON.parse(secretOutput.text)
                if (exitCode !== 0 || !response.ok) root.errorText = response.error ?? Translation.tr("Keyring unavailable")
            } catch (error) { root.errorText = Translation.tr("Keyring unavailable") }
            Qt.callLater(root.refresh)
        }
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
        description: ""
        summary: ""
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
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        AutomationButton { iconName: "play_arrow"; buttonText: Translation.tr("Start"); enabled: !root.busy && serviceRow.service.state !== "active"; onClicked: root.runAction(["service", "start", serviceRow.modelData]) }
                        AutomationButton { iconName: "stop"; buttonText: Translation.tr("Stop"); enabled: !root.busy && serviceRow.service.state === "active"; onClicked: root.runAction(["service", "stop", serviceRow.modelData]) }
                        AutomationButton { iconName: "restart_alt"; buttonText: Translation.tr("Restart"); enabled: !root.busy && serviceRow.service.state !== "unavailable"; onClicked: root.runAction(["service", "restart", serviceRow.modelData]) }
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
        title: Translation.tr("Independent workflows")
        SettingsGroup {
            SettingsNote { icon: "forum"; text: Translation.tr("Independent chats · background recovery") }
            SettingsNote { icon: "memory"; text: Translation.tr("Workers: %1 / %2").arg(root.snapshot?.worker_pool?.running?.length ?? 0).arg(root.snapshot?.worker_pool?.limit ?? 2) }
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
                    AutomationButton { iconName: "edit"; buttonText: Translation.tr("Edit"); enabled: !root.busy; onClicked: root.selectedProfileId = profileRow.modelData.id }
                    AutomationButton { iconName: "delete"; buttonText: Translation.tr("Remove"); enabled: !root.busy; onClicked: root.confirmRemoval(profileRow.modelData.id) }
                }
            }
            SettingsNote {
                visible: !!root.pendingRemoveId && root.pendingRemoveId === root.selectedProfileId
                warning: true
                text: root.pendingRemoveUnresolved
                    ? Translation.tr("Remove this profile and stop tracking its current response? A private recovery copy is saved. ChatGPT history stays.")
                    : root.selectedState?.parked_pending
                    ? Translation.tr("Remove this profile and parked recovery state? ChatGPT history stays.")
                    : Translation.tr("Remove this profile? ChatGPT history stays.")
            }
            RowLayout {
                visible: !!root.pendingRemoveId && root.pendingRemoveId === root.selectedProfileId
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "close"; buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                AutomationButton { iconName: "delete_forever"; buttonText: Translation.tr("Confirm"); enabled: !root.busy; onClicked: root.applyRemoval() }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "add"; buttonText: Translation.tr("New"); hint: Translation.tr("New profile"); enabled: !root.busy; onClicked: root.runAction(["profile-create", "New automation"]) }
                AutomationButton { iconName: "content_copy"; buttonText: Translation.tr("Duplicate"); enabled: !root.busy && !!root.selectedProfile; onClicked: root.runAction(["profile-duplicate", root.selectedProfileId, root.selectedProfile.name + " copy"]) }
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
            SettingsSwitch { buttonIcon: "code"; text: Translation.tr("Require GitHub"); checked: root.selectedProfile?.requires_github ?? true; autoToggle: false; onToggledByUser: checked => root.setProfile("requires_github", checked) }
            SettingsSwitch { buttonIcon: "task_alt"; text: Translation.tr("Stop on completion"); checked: root.selectedProfile?.stop_on_done ?? true; autoToggle: false; onToggledByUser: checked => root.setProfile("stop_on_done", checked) }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialTextField { id: nameEditor; objectName: "automationProfileName"; Layout.fillWidth: true; Layout.preferredWidth: 1; placeholderText: Translation.tr("Profile name") }
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); hint: Translation.tr("Save name"); enabled: !root.busy; onClicked: root.setProfile("name", nameEditor.text) }
                MaterialTextField { id: projectEditor; objectName: "automationProjectName"; Layout.fillWidth: true; Layout.preferredWidth: 1; placeholderText: Translation.tr("ChatGPT project") }
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); hint: Translation.tr("Save project · applies to the next chat"); enabled: !root.busy; onClicked: root.setProfile("project_name", projectEditor.text) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialTextField {
                    id: githubToken
                    objectName: "automationGithubToken"
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("GitHub token")
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    maximumLength: 512
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    enableSettingsSearch: false
                    enabled: !root.busy
                }
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); hint: Translation.tr("Save token to keyring"); enabled: !root.busy && githubToken.text.length > 0; onClicked: root.saveToken() }
                AutomationButton { iconName: "key_off"; buttonText: Translation.tr("Clear"); hint: Translation.tr("Remove saved token"); enabled: !root.busy && root.tokenSaved; onClicked: root.runAction(["github-token-clear", root.selectedProfileId]) }
            }
            SettingsNote {
                icon: root.tokenSaved ? "lock" : "key"
                text: root.tokenSaved ? Translation.tr("Token saved · local Git only") : Translation.tr("Optional · stored in system keyring")
            }
            RowLayout {
                objectName: "automationRunActions"
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "play_arrow"; buttonText: Translation.tr("Start"); enabled: !root.busy && (root.selectedProfile?.enabled ?? false); onClicked: root.runAction(["profile-action", "start", root.selectedProfileId]) }
                AutomationButton { iconName: "pause"; buttonText: Translation.tr("Pause"); enabled: !root.busy && root.selectedState?.desired === "run"; onClicked: root.runAction(["profile-action", "pause", root.selectedProfileId]) }
                AutomationButton { iconName: "play_pause"; buttonText: Translation.tr("Resume"); enabled: !root.busy && root.selectedState?.desired === "paused"; onClicked: root.runAction(["profile-action", "resume", root.selectedProfileId]) }
                AutomationButton { iconName: "stop"; buttonText: Translation.tr("Stop"); enabled: !root.busy; onClicked: root.runAction(["profile-action", "stop", root.selectedProfileId]) }
                AutomationButton { iconName: "restart_alt"; buttonText: Translation.tr("Restart"); enabled: !root.busy && (root.selectedProfile?.enabled ?? false); onClicked: root.runAction(["profile-action", "restart", root.selectedProfileId]) }
                AutomationButton { iconName: "cancel"; buttonText: Translation.tr("Cancel"); hint: Translation.tr("Cancel local job"); visible: !!root.selectedState?.job_id; enabled: !root.busy; onClicked: root.runAction(["job-cancel", root.selectedProfileId]) }
                AutomationButton {
                    iconName: "delete"
                    buttonText: Translation.tr("Remove")
                    enabled: !root.busy
                    onClicked: root.confirmRemoval()
                }
            }
            SettingsNote {
                visible: !!root.selectedState?.status_detail
                text: root.selectedState?.status_detail ?? ""
            }
            SettingsNote { visible: !!root.selectedState?.checkpoint; text: Translation.tr("Checkpoint: %1").arg(root.selectedState?.checkpoint?.summary ?? root.selectedState?.checkpoint?.phase ?? "") }
        }

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol { text: "psychology"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                StyledText { Layout.fillWidth: true; text: Translation.tr("Thinking effort"); color: Appearance.colors.colOnSurface }
                StyledText { text: Translation.tr(root.thinkingLabels[Math.round(thinkingSlider.value)] ?? "High"); color: Appearance.colors.colPrimary }
            }
            StyledSlider {
                id: thinkingSlider
                objectName: "automationThinkingEffort"
                Layout.fillWidth: true
                from: 0
                to: root.thinkingEfforts.length - 1
                stepSize: 1
                snapMode: Slider.SnapAlways
                configuration: StyledSlider.Configuration.S
                stopIndicatorValues: [0, 1, 2]
                value: root.thinkingIndex(root.savedThinkingEffort)
                enabled: !root.busy
                Accessible.name: Translation.tr("Thinking effort")
                settingsSearchLabel: Translation.tr("Thinking effort")
                settingsSearchKeywords: ["chat", "reasoning", "effort", "thinking", "model"]
                tooltipContent: Translation.tr(root.thinkingLabels[Math.round(value)] ?? "High")
                function saveLevel(): void {
                    if (pressed || root.busy) return
                    const effort = root.thinkingEfforts[Math.round(value)]
                    if (effort && effort !== root.savedThinkingEffort) root.setProfile("thinking_effort", effort)
                }
                onMoved: saveLevel()
                onPressedChanged: if (!pressed) saveLevel()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                AutomationButton {
                    objectName: "automationThinkingDefault"
                    iconName: "star"
                    buttonText: Translation.tr("Set default")
                    enabled: !root.busy && root.thinkingEfforts[Math.round(thinkingSlider.value)] !== root.defaultThinkingEffort
                    onClicked: root.runAction(["thinking-default", root.thinkingEfforts[Math.round(thinkingSlider.value)]])
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Default: %1").arg(Translation.tr(root.thinkingLabels[root.thinkingIndex(root.defaultThinkingEffort)]))
                    color: Appearance.colors.colSubtext
                }
            }
            SettingsNote { icon: "chat"; text: Translation.tr("Next turn · default applies to new profiles") }
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
            StyledText { text: Translation.tr("Initial"); color: Appearance.colors.colOnSurface }
            AutomationEditor { id: promptEditor; objectName: "automationInitialPrompt" }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); enabled: !root.busy; onClicked: root.setProfile("prompt", promptEditor.text) }
                AutomationButton { iconName: "undo"; buttonText: Translation.tr("Undo"); hint: Translation.tr("Restore saved prompt"); onClicked: promptEditor.text = root.selectedProfile.prompt }
                AutomationButton { iconName: "restore"; buttonText: Translation.tr("Default"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "prompt"]) }
            }
            StyledText { text: Translation.tr("Continuation"); color: Appearance.colors.colOnSurface }
            AutomationEditor { id: continuationEditor; objectName: "automationContinuationPrompt"; implicitHeight: 160 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); enabled: !root.busy; onClicked: root.setProfile("continuation_prompt", continuationEditor.text) }
                AutomationButton { iconName: "undo"; buttonText: Translation.tr("Undo"); hint: Translation.tr("Restore saved prompt"); onClicked: continuationEditor.text = root.selectedProfile.continuation_prompt }
                AutomationButton { iconName: "restore"; buttonText: Translation.tr("Default"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "continuation_prompt"]) }
            }
            StyledText { text: Translation.tr("Rotation"); color: Appearance.colors.colOnSurface }
            AutomationEditor { id: rotationEditor; objectName: "automationRotationPrompt"; implicitHeight: 160 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                AutomationButton { iconName: "save"; buttonText: Translation.tr("Save"); enabled: !root.busy; onClicked: root.setProfile("rotation_prompt", rotationEditor.text) }
                AutomationButton { iconName: "undo"; buttonText: Translation.tr("Undo"); hint: Translation.tr("Restore saved prompt"); onClicked: rotationEditor.text = root.selectedProfile.rotation_prompt }
                AutomationButton { iconName: "restore"; buttonText: Translation.tr("Default"); enabled: !root.busy; onClicked: root.runAction(["profile-reset-prompt", root.selectedProfileId, "rotation_prompt"]) }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "profiles"
        visible: root.activeSection === "profiles" && !!root.selectedProfile
        expanded: false
        icon: "health_and_safety"
        title: Translation.tr("Recovery & cleanup")
        SettingsGroup {
            ConfigSpinBox { text: Translation.tr("Retry delay (seconds)"); from: 1; to: 3600; value: root.selectedProfile?.retry_delay_seconds ?? 30; onValueModified: root.setProfile("retry_delay_seconds", value) }
            SettingsNote { icon: "shield"; text: Translation.tr("Uncertain submissions are kept for verification.") }
            SettingsNote { icon: "admin_panel_settings"; text: Translation.tr("Administrator actions use system authentication.") }
            SettingsSwitch { buttonIcon: "archive"; text: Translation.tr("Archive completed chats"); checked: root.selectedProfile?.archive_completed ?? true; autoToggle: false; onToggledByUser: checked => root.setProfile("archive_completed", checked) }
            SettingsSwitch { buttonIcon: "delete"; text: Translation.tr("Delete completed chats"); checked: root.selectedProfile?.delete_completed ?? false; autoToggle: false; enabled: !(root.selectedProfile?.archive_completed ?? true); onToggledByUser: checked => checked ? root.confirmCleanup("delete_completed", false) : root.setProfile("delete_completed", false) }
            SettingsNote { icon: "info"; text: Translation.tr("Cleanup preferences only · Desktop support pending") }
            SettingsNote {
                visible: root.pendingCleanupScope === root.selectedProfileId && root.pendingCleanupField === "delete_completed"
                warning: true
                text: Translation.tr("Save deletion preference? Chat deletion is not implemented.")
            }
            RowLayout {
                visible: root.pendingCleanupScope === root.selectedProfileId && root.pendingCleanupField === "delete_completed"
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "close"; buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                AutomationButton { iconName: "check"; buttonText: Translation.tr("Confirm"); enabled: !root.busy; onClicked: root.applyCleanup() }
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
            SettingsSwitch { buttonIcon: "archive"; text: Translation.tr("Archive completed"); checked: root.snapshot?.config?.maintenance?.archive_completed ?? true; autoToggle: false; onToggledByUser: checked => root.setMaintenance("archive_completed", checked) }
            SettingsSwitch { buttonIcon: "delete"; text: Translation.tr("Delete completed"); checked: root.snapshot?.config?.maintenance?.delete_completed ?? false; autoToggle: false; enabled: !(root.snapshot?.config?.maintenance?.archive_completed ?? true); onToggledByUser: checked => checked ? root.confirmCleanup("delete_completed", true) : root.setMaintenance("delete_completed", false) }
            SettingsSwitch { buttonIcon: "inventory_2"; text: Translation.tr("Archive old chats"); checked: root.snapshot?.config?.maintenance?.archive_old ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("archive_old", checked) }
            SettingsSwitch { buttonIcon: "cleaning_services"; text: Translation.tr("Clean abandoned"); checked: root.snapshot?.config?.maintenance?.cleanup_abandoned ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("cleanup_abandoned", checked) }
            SettingsSwitch { buttonIcon: "healing"; text: Translation.tr("Recover generation"); checked: root.snapshot?.config?.maintenance?.recover_stuck_generation ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("recover_stuck_generation", checked) }
            SettingsSwitch { buttonIcon: "edit_note"; text: Translation.tr("Recover composer"); checked: root.snapshot?.config?.maintenance?.recover_stale_composer ?? false; autoToggle: false; onToggledByUser: checked => root.setMaintenance("recover_stale_composer", checked) }
            SettingsNote { warning: true; icon: "info"; text: Translation.tr("Preferences saved · Desktop cleanup support pending") }
            SettingsNote {
                visible: root.pendingCleanupScope === "global" && root.pendingCleanupField === "delete_completed"
                warning: true
                text: Translation.tr("Save deletion preference? Chat deletion is not implemented.")
            }
            RowLayout {
                visible: root.pendingCleanupScope === "global" && root.pendingCleanupField === "delete_completed"
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "close"; buttonText: Translation.tr("Cancel"); onClicked: root.cancelConfirmation() }
                AutomationButton { iconName: "check"; buttonText: Translation.tr("Confirm"); enabled: !root.busy; onClicked: root.applyCleanup() }
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
            ConfigSelectionArray {
                currentValue: root.showDiagnostics ? "diagnostics" : "events"
                options: [
                    { displayName: Translation.tr("Events"), icon: "history", value: "events" },
                    { displayName: Translation.tr("Diagnostics"), icon: "monitor_heart", value: "diagnostics" }
                ]
                onSelected: value => {
                    root.showDiagnostics = value === "diagnostics"
                    root.logMessage = ""
                    root.refreshLogs()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                AutomationButton { iconName: "refresh"; buttonText: Translation.tr("Refresh"); enabled: !root.logsBusy; onClicked: { root.refresh(); root.refreshLogs() } }
                AutomationButton { iconName: "content_copy"; buttonText: Translation.tr("Copy"); enabled: root.visibleLogText.length > 0; onClicked: root.copyLogs() }
                AutomationButton { iconName: "download"; buttonText: Translation.tr("Export"); hint: Translation.tr("Export diagnostics to /tmp"); enabled: !root.busy && root.showDiagnostics; onClicked: root.runAction(["logs-export"]) }
            }
            SettingsNote {
                visible: root.showDiagnostics
                icon: "privacy_tip"
                text: Translation.tr("Private logs · review before sharing")
            }
            StyledText {
                visible: root.logMessage.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.logMessage
                color: Appearance.colors.colSecondary
            }
            AutomationEditor {
                objectName: "automationActivityLog"
                implicitHeight: 360
                readOnly: true
                enableSettingsSearch: false
                text: root.visibleLogText || (root.logsBusy ? Translation.tr("Loading…") : Translation.tr("No activity"))
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "history"
        visible: root.activeSection === "history" && !!root.selectedProfile
        expanded: true
        icon: "info"
        title: Translation.tr("Current run")
        SettingsGroup {
            SettingsNote { icon: "monitor_heart"; text: root.statusLabel(root.selectedState?.status ?? "idle") }
            StyledText {
                visible: !!root.selectedState?.status_detail
                Layout.fillWidth: true
                text: root.selectedState?.status_detail ?? ""
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSecondary
            }
            SettingsNote { icon: "terminal"; visible: !!(root.selectedState?.job_id || root.selectedState?.last_job_id); text: root.selectedState?.job_id || root.selectedState?.last_job_id || "" }
            SettingsNote { icon: "timer"; text: Translation.tr("%1 · %2 iterations · %3 prompts").arg(root.elapsed(root.selectedState?.started_at_unix)).arg(root.selectedState?.iterations ?? 0).arg(root.selectedState?.prompts_sent ?? 0) }
            SettingsNote { icon: "warning"; visible: (root.selectedState?.poll_errors ?? 0) > 0 || (root.selectedState?.failures ?? 0) > 0; text: Translation.tr("Failures: %1 · Poll errors: %2").arg(root.selectedState?.failures ?? 0).arg(root.selectedState?.poll_errors ?? 0) }
            SettingsNote { icon: "task_alt"; visible: !!root.selectedState?.last_result; text: root.selectedState?.last_result ?? "" }
            SettingsNote { icon: "history"; visible: !!root.selectedState?.last_run_at_unix; text: Translation.tr("Last: %1").arg(root.when(root.selectedState?.last_run_at_unix)) }
            SettingsNote { icon: "schedule"; visible: !!root.selectedState?.next_run_at_unix; text: Translation.tr("Next: %1").arg(root.when(root.selectedState?.next_run_at_unix)) }
            SettingsNote { visible: !!root.selectedState?.last_error; warning: true; icon: "error"; text: root.selectedState?.last_error ?? "" }
        }
    }
}
