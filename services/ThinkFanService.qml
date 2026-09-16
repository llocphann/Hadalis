pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool serviceInstalled: false
    property bool active: false
    property bool enabled: false
    property bool stateKnown: false
    property bool busy: false
    property string profile: "firmware"
    property int fanRpm: -1
    property string fanLevel: ""
    property string configPath: ""
    property string statusReason: ""
    property bool lastApplySucceeded: false
    property string lastApplyError: ""
    property bool _refreshQueued: false

    function _clearStatus(reason: string): void {
        root.available = false
        root.serviceInstalled = false
        root.active = false
        root.enabled = false
        root.stateKnown = false
        root.profile = "firmware"
        root.fanRpm = -1
        root.fanLevel = ""
        root.configPath = ""
        root.statusReason = reason
    }

    function _parseStatus(line: string): bool {
        let data
        try {
            data = JSON.parse(String(line ?? "").trim())
        } catch (error) {
            root._clearStatus("invalid-status")
            return false
        }
        if (data?.schema !== 1) {
            root._clearStatus("unsupported-status-schema")
            return false
        }

        root.available = data.available === true
        root.serviceInstalled = data.serviceInstalled === true
        root.active = data.active === true
        root.enabled = data.enabled === true
        root.profile = String(data.profile ?? "firmware")
        root.fanRpm = typeof data.fanRpm === "number" && isFinite(data.fanRpm)
            ? Math.max(0, Math.round(data.fanRpm)) : -1
        root.fanLevel = String(data.fanLevel ?? "")
        root.configPath = String(data.configPath ?? "")
        root.statusReason = String(data.reason ?? "")
        root.stateKnown = true
        return true
    }

    function refresh(): void {
        if (root.busy || detector.running) {
            root._refreshQueued = true
            return
        }
        root._refreshQueued = false
        detector.running = true
    }

    function applyProfile(requestedProfile: string): bool {
        const normalized = String(requestedProfile ?? "")
        if (normalized !== "managed" && normalized !== "firmware") {
            root.lastApplySucceeded = false
            root.lastApplyError = "unsupported-profile"
            return false
        }
        if (root.busy) {
            root.lastApplySucceeded = false
            root.lastApplyError = "apply-busy"
            return false
        }
        if (!root.serviceInstalled) {
            root.lastApplySucceeded = false
            root.lastApplyError = "service-unavailable"
            return false
        }
        if (normalized === "managed" && !root.available) {
            root.lastApplySucceeded = false
            root.lastApplyError = "thinkfan-unavailable"
            return false
        }

        root.busy = true
        root.lastApplySucceeded = false
        root.lastApplyError = ""
        applyProcess.command = [
            "/usr/bin/pkexec", "/usr/libexec/inir-thinkfan",
            "--apply", normalized
        ]
        applyProcess.running = true
        return true
    }

    Component.onCompleted: root.refresh()

    Process {
        id: detector
        property bool statusSeen: false
        property bool timedOut: false
        property bool startObserved: false
        command: ["/usr/libexec/inir-thinkfan", "--status"]

        stdout: SplitParser {
            onRead: data => {
                if (root._parseStatus(data))
                    detector.statusSeen = true
            }
        }

        onRunningChanged: {
            if (detector.running) {
                detector.startObserved = false
                return
            }
            if (detector.startObserved)
                return

            detectorTimeout.stop()
            root._clearStatus("helper-unavailable")
            if (root._refreshQueued) {
                root._refreshQueued = false
                Qt.callLater(() => root.refresh())
            }
        }
        onStarted: {
            detector.startObserved = true
            detector.statusSeen = false
            detector.timedOut = false
            detectorTimeout.restart()
        }
        onExited: (exitCode, exitStatus) => {
            detectorTimeout.stop()
            if (detector.timedOut)
                root._clearStatus("status-timeout")
            else if (exitCode !== 0 || !detector.statusSeen)
                root._clearStatus(exitCode === 127
                    ? "helper-unavailable" : "status-failed")
            if (root._refreshQueued) {
                root._refreshQueued = false
                Qt.callLater(() => root.refresh())
            }
        }
    }

    Timer {
        id: detectorTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (!detector.running)
                return
            detector.timedOut = true
            detector.running = false
        }
    }

    Process {
        id: applyProcess
        property bool timedOut: false
        property bool startObserved: false

        stdout: SplitParser {
            onRead: data => root._parseStatus(data)
        }

        onRunningChanged: {
            if (applyProcess.running) {
                applyProcess.startObserved = false
                return
            }
            if (applyProcess.startObserved || !root.busy)
                return

            applyTimeout.stop()
            root.busy = false
            root.lastApplySucceeded = false
            root.lastApplyError = "apply-start-failed"
            console.warn("[ThinkFan] Failed to start privileged profile helper")
            Qt.callLater(() => root.refresh())
        }
        onStarted: {
            applyProcess.startObserved = true
            applyProcess.timedOut = false
            applyTimeout.restart()
        }
        onExited: (exitCode, exitStatus) => {
            applyTimeout.stop()
            root.busy = false
            root.lastApplySucceeded = exitCode === 0 && !applyProcess.timedOut
            root.lastApplyError = applyProcess.timedOut
                ? "apply-timeout" : (exitCode === 0 ? "" : "apply-failed")
            if (!root.lastApplySucceeded) {
                if (applyProcess.timedOut)
                    console.warn("[ThinkFan] Timed out while applying profile intent")
                else
                    console.warn("[ThinkFan] Failed to apply profile intent (exit code " + exitCode + ")")
            }
            // Always re-read through the unprivileged path. The privileged helper
            // also verifies service state before returning success.
            Qt.callLater(() => root.refresh())
        }
    }

    Timer {
        id: applyTimeout
        interval: 60000
        repeat: false
        onTriggered: {
            if (!applyProcess.running)
                return
            applyProcess.timedOut = true
            applyProcess.running = false
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
