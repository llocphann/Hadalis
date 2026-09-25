pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isRecording: false
    property int recorderPid: 0
    property string requestedAudioMode: "none"
    property string activeAudioMode: "none"
    property bool audioFallback: false
    property bool hasAudioMetadata: false
    property bool hasStoredAudioMode: false
    property bool hasStoredSystemAudioSource: false
    property bool hasStoredMicrophoneSource: false
    property string legacyAudioSource: ""
    readonly property string configuredAudioMode: root.hasStoredAudioMode
        ? root.normalizeAudioMode(Config.options?.screenRecord?.audioMode ?? "system")
        : root.audioModeFromLegacySource(root.legacyAudioSource)
    readonly property string configuredSystemAudioSource: {
        const configured = String(Config.options?.screenRecord?.systemAudioSource ?? "")
        if (root.hasStoredSystemAudioSource)
            return configured
        return root.legacyAudioSource.endsWith(".monitor") ? root.legacyAudioSource : configured
    }
    readonly property string configuredMicrophoneSource: {
        const configured = String(Config.options?.screenRecord?.microphoneSource ?? "")
        if (root.hasStoredMicrophoneSource)
            return configured
        return root.legacyAudioSource.length > 0 && !root.legacyAudioSource.endsWith(".monitor")
            ? root.legacyAudioSource : configured
    }
    readonly property string effectiveAudioMode: isRecording && hasAudioMetadata ? activeAudioMode : configuredAudioMode
    readonly property string recorderStatusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/inir/recorder-status.json"
    // Timestamp (ms since epoch) when recording started, 0 when not recording
    property real recordingStartTime: 0
    // Elapsed seconds since recording started, updated every second
    property int elapsedSeconds: 0

    function normalizeAudioMode(mode: string): string {
        switch (mode) {
        case "none":
        case "system":
        case "microphone":
        case "both":
            return mode
        default:
            return "system"
        }
    }

    function audioModeFromLegacySource(source: string): string {
        if (source.length > 0 && !source.endsWith(".monitor"))
            return "microphone"
        return "system"
    }

    function setConfiguredAudioMode(mode: string): void {
        Config.setNestedValue("screenRecord.audioMode", root.normalizeAudioMode(mode))
        root.hasStoredAudioMode = true
    }

    function setConfiguredSystemAudioSource(source): void {
        Config.setNestedValue("screenRecord.systemAudioSource", String(source ?? ""))
        root.hasStoredSystemAudioSource = true
    }

    function setConfiguredMicrophoneSource(source): void {
        Config.setNestedValue("screenRecord.microphoneSource", String(source ?? ""))
        root.hasStoredMicrophoneSource = true
    }

    function resetStoredAudioConfig(): void {
        root.hasStoredAudioMode = false
        root.hasStoredSystemAudioSource = false
        root.hasStoredMicrophoneSource = false
        root.legacyAudioSource = ""
    }

    function parseStoredAudioConfig(payloadText: string): void {
        try {
            const payload = JSON.parse(payloadText.trim() || "{}")
            const screenRecord = payload?.screenRecord
            if (screenRecord === null || typeof screenRecord !== "object" || Array.isArray(screenRecord)) {
                root.resetStoredAudioConfig()
                return
            }
            root.hasStoredAudioMode = Object.prototype.hasOwnProperty.call(screenRecord, "audioMode")
            root.hasStoredSystemAudioSource = Object.prototype.hasOwnProperty.call(screenRecord, "systemAudioSource")
            root.hasStoredMicrophoneSource = Object.prototype.hasOwnProperty.call(screenRecord, "microphoneSource")
            root.legacyAudioSource = typeof screenRecord.audioSource === "string"
                ? screenRecord.audioSource : ""
        } catch (error) {
            root.resetStoredAudioConfig()
        }
    }

    function refreshStoredAudioConfig(): void {
        if (!Config.ready || storedConfigFile.loadPending)
            return
        storedConfigFile.loadPending = true
        if (storedConfigFile.path === Config.filePath)
            storedConfigFile.reload()
        else
            storedConfigFile.path = Config.filePath
    }

    function resetAudioMetadata(): void {
        requestedAudioMode = "none"
        activeAudioMode = "none"
        audioFallback = false
        hasAudioMetadata = false
    }

    function loadAudioMetadata(): void {
        if (metadataFile.loadPending)
            return
        metadataFile.loadPending = true
        if (metadataFile.path === root.recorderStatusPath)
            metadataFile.reload()
        else
            metadataFile.path = root.recorderStatusPath
    }

    onIsRecordingChanged: {
        if (isRecording) {
            recordingStartTime = Date.now()
            elapsedSeconds = 0
        } else {
            recordingStartTime = 0
            elapsedSeconds = 0
            recorderPid = 0
            activePidFile.loadPending = false
            activePidFile.path = ""
            resetAudioMetadata()
        }
    }

    function refreshStatus() {
        if (!checkProcess.running)
            checkProcess.running = true
    }

    function refreshActivePid(): void {
        if (!root.isRecording || root.recorderPid <= 0 || activePidFile.loadPending)
            return

        activePidFile.pid = root.recorderPid
        activePidFile.loadPending = true
        const target = "/proc/" + root.recorderPid + "/comm"
        if (activePidFile.path === target)
            activePidFile.reload()
        else
            activePidFile.path = target
    }

    readonly property int idlePollIntervalMs:
        (Config.options?.performance?.lowPower ?? false) ? 30000 : 15000

    // External recorders are uncommon, and in-shell recording actions already
    // schedule a fast bounded recheck. Avoid spawning pgrep every five seconds
    // for the entire desktop session just to discover an external recorder.
    Timer {
        id: idlePollTimer
        interval: root.idlePollIntervalMs
        running: Config.ready && !root.isRecording
        repeat: true
        onTriggered: root.refreshStatus()
    }

    // Active poll: keep elapsed UI precise, but verify the known recorder PID
    // in-process. Fall back to pgrep only when that PID disappears or changes.
    Timer {
        id: activePollTimer
        interval: 1000
        running: root.isRecording
        repeat: true
        onTriggered: {
            if (root.recordingStartTime > 0)
                root.elapsedSeconds = Math.floor((Date.now() - root.recordingStartTime) / 1000)
            root.refreshActivePid()
        }
    }

    // Quick recheck after a recording action (start/stop) to catch state change fast
    function scheduleQuickCheck(): void {
        quickCheckTimer.initialRecordingState = root.isRecording
        quickCheckTimer.attemptsRemaining = 6
        quickCheckTimer.restart()
    }
    Timer {
        id: quickCheckTimer
        property bool initialRecordingState: false
        property int attemptsRemaining: 0
        interval: 350
        repeat: true
        onTriggered: {
            root.refreshStatus()
            attemptsRemaining = Math.max(0, attemptsRemaining - 1)
            if (root.isRecording !== initialRecordingState || attemptsRemaining <= 0)
                stop()
        }
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                Qt.callLater(root.refreshStoredAudioConfig)
        }
    }

    Component.onCompleted: {
        Qt.callLater(root.refreshStatus)
        Qt.callLater(root.refreshStoredAudioConfig)
    }

    FileView {
        id: storedConfigFile
        property bool loadPending: false
        path: ""
        printErrors: false

        onLoaded: {
            loadPending = false
            root.parseStoredAudioConfig(text())
        }
        onLoadFailed: {
            loadPending = false
            root.resetStoredAudioConfig()
        }
    }

    FileView {
        id: metadataFile
        property bool loadPending: false
        path: ""
        printErrors: false

        onLoaded: {
            loadPending = false
            try {
                const payload = JSON.parse(text())
                const payloadPid = Number(payload.recorderPid ?? 0)
                if (!root.isRecording || payloadPid <= 0 || payloadPid !== root.recorderPid) {
                    root.resetAudioMetadata()
                    return
                }
                root.requestedAudioMode = root.normalizeAudioMode(String(payload.requestedAudioMode ?? "system"))
                root.activeAudioMode = root.normalizeAudioMode(String(payload.activeAudioMode ?? "none"))
                root.audioFallback = payload.audioFallback === true
                root.hasAudioMetadata = true
            } catch (error) {
                root.resetAudioMetadata()
            }
        }
        onLoadFailed: {
            loadPending = false
            root.resetAudioMetadata()
        }
    }

    FileView {
        id: activePidFile
        property bool loadPending: false
        property int pid: 0
        path: ""
        printErrors: false

        onLoaded: {
            const probedPid = activePidFile.pid
            loadPending = false
            if (!root.isRecording || root.recorderPid !== probedPid)
                return
            if (text().trim() !== "wf-recorder")
                root.refreshStatus()
        }
        onLoadFailed: {
            const probedPid = activePidFile.pid
            loadPending = false
            if (root.isRecording && root.recorderPid === probedPid)
                root.refreshStatus()
        }
    }

    Process {
        id: checkProcess
        property bool startObserved: false
        command: ["/usr/bin/pgrep", "-xo", "wf-recorder"]
        stdout: StdioCollector {
            id: recorderPidCollector
        }
        onRunningChanged: {
            if (checkProcess.running) {
                checkProcess.startObserved = false
                return
            }
            if (checkProcess.startObserved)
                return
            root.recorderPid = 0
            root.isRecording = false
        }
        onStarted: checkProcess.startObserved = true
        onExited: (exitCode, exitStatus) => {
            const previousPid = root.recorderPid
            const parsedPid = parseInt(recorderPidCollector.text.trim(), 10)
            root.recorderPid = exitCode === 0 && !isNaN(parsedPid) ? parsedPid : 0
            root.isRecording = root.recorderPid > 0
            if (root.isRecording && (!root.hasAudioMetadata || root.recorderPid !== previousPid))
                root.loadAudioMetadata()
        }
    }
}
