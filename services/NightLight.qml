pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * Niri night-light service backed by wlsunset.
 *
 * The singleton owns only the process it launches itself. It can observe and
 * explicitly stop a detached wlsunset instance when the user requests OFF,
 * while destruction never kills an externally-owned process.
 */
Singleton {
    id: root

    property string from: Config.options?.light?.night?.from ?? "19:00"
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic:
        (Config.options?.light?.night?.automatic ?? true)
        && (Config?.ready ?? true)
    property bool manualEnabled: Config.options?.light?.night?.enabled ?? false
    property int colorTemperature:
        Config.options?.light?.night?.colorTemperature ?? 5000
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool active: false
    property bool stateKnown: false
    property bool _pendingEnable: false
    property bool _pendingDisable: false
    property bool _toggleAfterProbe: false
    property bool _pendingRestart: false
    property bool _restartOwnedAfterExit: false
    property bool _destroying: false
    property var manualActive
    property real manualOverrideUntilMs: 0

    function _timeParts(value, fallbackHour: int, fallbackMinute: int): var {
        const match = String(value ?? "").trim().match(/^(\d{1,2}):(\d{2})$/)
        if (!match)
            return ({ hour: fallbackHour, minute: fallbackMinute })
        const hour = Number(match[1])
        const minute = Number(match[2])
        if (!Number.isInteger(hour) || !Number.isInteger(minute)
                || hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return ({ hour: fallbackHour, minute: fallbackMinute })
        return ({ hour: hour, minute: minute })
    }

    readonly property var fromParts: root._timeParts(root.from, 19, 0)
    readonly property var toParts: root._timeParts(root.to, 6, 30)
    readonly property int fromHour: root.fromParts.hour
    readonly property int fromMinute: root.fromParts.minute
    readonly property int toHour: root.toParts.hour
    readonly property int toMinute: root.toParts.minute
    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    Timer {
        id: restartDebounce
        interval: 300
        onTriggered: {
            if (!root._pendingRestart)
                return
            root._pendingRestart = false
            root._restartOwnedProcess()
        }
    }

    Timer {
        id: stateVerifyTimer
        interval: 800
        repeat: false
        onTriggered: root.fetchState()
    }

    Timer {
        id: stateProbeTimeout
        interval: 5000
        repeat: false
        onTriggered: {
            if (!stateProbeProc.running)
                return
            stateProbeProc.timedOut = true
            stateProbeProc.running = false
        }
    }

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined
        root.manualOverrideUntilMs = 0
        root.firstEvaluation = true
        root.reEvaluate()
    }
    onShouldBeOnChanged: ensureState()

    function inBetween(t, from, to): bool {
        return from < to ? (t >= from && t <= to) : (t >= from || t <= to)
    }

    function _nextScheduleBoundaryMs(): real {
        const now = new Date()
        const nowMs = now.getTime()
        let nextMs = Number.MAX_VALUE
        for (let dayOffset = 0; dayOffset <= 1; ++dayOffset) {
            const fromDate = new Date(now)
            fromDate.setDate(fromDate.getDate() + dayOffset)
            fromDate.setHours(root.fromHour, root.fromMinute, 0, 0)
            const fromMs = fromDate.getTime()
            if (fromMs > nowMs && fromMs < nextMs)
                nextMs = fromMs

            const toDate = new Date(now)
            toDate.setDate(toDate.getDate() + dayOffset)
            toDate.setHours(root.toHour, root.toMinute, 0, 0)
            const toMs = toDate.getTime()
            if (toMs > nowMs && toMs < nextMs)
                nextMs = toMs
        }
        return nextMs === Number.MAX_VALUE
            ? nowMs + 24 * 60 * 60 * 1000
            : nextMs
    }

    function reEvaluate(): void {
        const t = root.clockHour * 60 + root.clockMinute
        const fromValue = root.fromHour * 60 + root.fromMinute
        const toValue = root.toHour * 60 + root.toMinute

        if (root.manualActive !== undefined
                && root.manualOverrideUntilMs > 0
                && Date.now() >= root.manualOverrideUntilMs) {
            root.manualActive = undefined
            root.manualOverrideUntilMs = 0
        }

        root.shouldBeOn = root.inBetween(t, fromValue, toValue)
        if (root.firstEvaluation) {
            root.firstEvaluation = false
            root.ensureState()
        } else if (root.automatic && root.manualActive === undefined
                && root.active !== root.shouldBeOn) {
            root.ensureState()
        }
    }

    function ensureState(): void {
        if (root.automatic && root.manualActive !== undefined)
            return
        if (root.automatic ? root.shouldBeOn : root.manualEnabled)
            root.enable()
        else
            root.disable()
    }

    function load(): void {
        root.reEvaluate()
    }

    function _ownedProcessRunning(): bool {
        return wlsunsetProc.running
    }

    function _startOwnedProcess(): void {
        if (root._destroying || wlsunsetProc.running)
            return
        root._pendingEnable = false
        wlsunsetProc.running = true
    }

    function _stopOwnedProcess(restart: bool): void {
        root._restartOwnedAfterExit = restart
        if (wlsunsetProc.running) {
            wlsunsetProc.running = false
            return
        }
        if (restart) {
            root._restartOwnedAfterExit = false
            root._startOwnedProcess()
        }
    }

    function _restartOwnedProcess(): void {
        if (root._ownedProcessRunning())
            root._stopOwnedProcess(true)
    }

    function _ownedProcessStopped(): void {
        if (root._destroying)
            return
        if (root._restartOwnedAfterExit) {
            root._restartOwnedAfterExit = false
            Qt.callLater(() => root._startOwnedProcess())
            return
        }
        stateVerifyTimer.restart()
    }

    function _finishStateProbe(detectedActive: bool): void {
        root.active = detectedActive || root._ownedProcessRunning()
        root.stateKnown = true

        if (root._toggleAfterProbe) {
            root._toggleAfterProbe = false
            root._applyManualDesiredState(!root.active)
            return
        }

        if (root._pendingDisable) {
            root._pendingDisable = false
            if (root.active) {
                root._stopDetectedBackend()
                return
            }
            root.active = false
        }

        if (root._pendingEnable) {
            root._pendingEnable = false
            if (!root.active)
                root._startOwnedProcess()
        }
    }

    function enable(): void {
        root._pendingDisable = false
        if (backendStopProc.running) {
            root._pendingEnable = true
            return
        }
        if (root._ownedProcessRunning()) {
            root.active = true
            return
        }
        if (!root.stateKnown) {
            root._pendingEnable = true
            root.fetchState()
            return
        }
        if (!root.active)
            root._startOwnedProcess()
    }

    function _stopDetectedBackend(): void {
        if (root._destroying || backendStopProc.running)
            return
        backendStopProc.running = true
    }

    function disable(): void {
        root._pendingEnable = false
        root._pendingRestart = false
        root._restartOwnedAfterExit = false
        restartDebounce.stop()

        if (root._ownedProcessRunning()) {
            root.active = false
            root._stopOwnedProcess(false)
            stateVerifyTimer.restart()
            return
        }
        if (backendStopProc.running) {
            root._pendingDisable = true
            return
        }
        if (!root.stateKnown) {
            root._pendingDisable = true
            root.fetchState()
            return
        }
        if (root.active) {
            root._pendingDisable = true
            root._stopDetectedBackend()
            return
        }
        root._pendingDisable = false
        root.active = false
    }

    function fetchState(): void {
        if (!stateProbeProc.running)
            stateProbeProc.running = true
    }

    Process {
        id: backendStopProc
        running: false
        property bool startObserved: false
        command: ["/usr/bin/pkill", "-TERM", "-x", "wlsunset"]

        onRunningChanged: {
            if (backendStopProc.running) {
                backendStopProc.startObserved = false
                return
            }
            if (!backendStopProc.startObserved) {
                console.warn("[NightLight] Backend stop command failed to start")
                stateVerifyTimer.restart()
            }
        }
        onStarted: backendStopProc.startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (exitCode > 1)
                console.warn("[NightLight] Backend stop failed with code", exitCode)
            root.active = false
            stateVerifyTimer.restart()
        }
    }

    Process {
        id: wlsunsetProc
        property bool startObserved: false
        running: false
        command: [
            "/usr/bin/wlsunset",
            "-T", "6500",
            "-t", root.colorTemperature.toString(),
            "-s", "00:00",
            "-S", "23:59"
        ]

        onRunningChanged: {
            if (wlsunsetProc.running) {
                wlsunsetProc.startObserved = false
                return
            }
            if (!wlsunsetProc.startObserved)
                return
            root.active = false
            root._ownedProcessStopped()
        }
        onStarted: {
            wlsunsetProc.startObserved = true
            root.stateKnown = true
            root.active = true
        }
        onExited: root._ownedProcessStopped()
    }

    Process {
        id: stateProbeProc
        property bool startObserved: false
        property bool timedOut: false
        running: false
        command: ["/usr/bin/pidof", "wlsunset"]

        onRunningChanged: {
            if (stateProbeProc.running) {
                stateProbeProc.startObserved = false
                return
            }
            if (stateProbeProc.startObserved)
                return
            stateProbeTimeout.stop()
            console.warn("[NightLight] State probe failed to start")
            root._finishStateProbe(false)
        }
        onStarted: {
            stateProbeProc.startObserved = true
            stateProbeProc.timedOut = false
            stateProbeTimeout.restart()
        }
        onExited: (exitCode, exitStatus) => {
            stateProbeTimeout.stop()
            if (stateProbeProc.timedOut)
                console.warn("[NightLight] State probe timed out")
            root._finishStateProbe(!stateProbeProc.timedOut && exitCode === 0)
        }
    }

    function _applyManualDesiredState(desired: bool): void {
        root.manualActive = desired
        root.manualOverrideUntilMs = root.automatic
            ? root._nextScheduleBoundaryMs() : 0
        Config.setNestedValue("light.night.enabled", desired)
        if (desired)
            root.enable()
        else
            root.disable()
    }

    function toggle(active = undefined): void {
        if (active === undefined && !root.stateKnown) {
            root._toggleAfterProbe = true
            root.fetchState()
            return
        }
        const desired = active !== undefined ? Boolean(active) : !root.active
        root._applyManualDesiredState(desired)
    }

    Connections {
        target: Config.options?.light?.night ?? null
        enabled: !!(Config.options?.light?.night)

        function onColorTemperatureChanged(): void {
            if (!root.active)
                return
            if (root._ownedProcessRunning()) {
                root._pendingRestart = true
                restartDebounce.restart()
                return
            }
            root._pendingEnable = true
            root._stopDetectedBackend()
        }
    }

    Connections {
        target: Config.options?.light?.night ?? null
        enabled: root.automatic && !!(Config.options?.light?.night)

        function onFromChanged(): void {
            if (root.manualActive !== undefined)
                root.manualOverrideUntilMs = root._nextScheduleBoundaryMs()
            root.firstEvaluation = true
            root.reEvaluate()
        }

        function onToChanged(): void {
            if (root.manualActive !== undefined)
                root.manualOverrideUntilMs = root._nextScheduleBoundaryMs()
            root.firstEvaluation = true
            root.reEvaluate()
        }
    }

    Component.onDestruction: {
        root._destroying = true
        restartDebounce.stop()
        stateVerifyTimer.stop()
        stateProbeTimeout.stop()
        root._restartOwnedAfterExit = false
        root._pendingDisable = false
        root._toggleAfterProbe = false
        backendStopProc.running = false
        wlsunsetProc.running = false
    }
}
