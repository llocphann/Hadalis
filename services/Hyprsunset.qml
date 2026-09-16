pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

/**
 * Night light service with automatic mode.
 * Uses hyprsunset on Hyprland, wlsunset on Niri.
 */
Singleton {
    id: root
    property string from: Config.options?.light?.night?.from ?? "19:00" 
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool automatic: (Config.options?.light?.night?.automatic ?? true) && (Config?.ready ?? true)
    property bool manualEnabled: Config.options?.light?.night?.enabled ?? false
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property bool shouldBeOn
    property bool firstEvaluation: true
    property bool active: false
    property bool stateKnown: false
    property bool _pendingEnable: false
    property bool _pendingRestart: false
    property bool _restartOwnedAfterExit: false
    property bool _destroying: false

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

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    // Debounce temperature-driven restarts of the process Hadalis owns. An
    // externally started night-light process is observed but never restarted.
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

    onClockMinuteChanged: reEvaluate()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        } else if (root.automatic && root.manualActive === undefined
                && root.active !== root.shouldBeOn) {
            // State probes may reveal that a start/stop failed after the desired
            // schedule value stopped changing. Reconcile on the next minute so
            // automatic mode self-heals without creating a tight process loop.
            root.ensureState();
        }
    }

    onShouldBeOnChanged: ensureState()
    function ensureState() {
        if (root.manualActive !== undefined)
            return;

        if (root.automatic) {
            if (root.shouldBeOn) {
                root.enable();
            } else {
                root.disable();
            }
        } else if (root.manualEnabled) {
            root.enable();
        } else {
            root.disable();
        }
    }

    function load() { } // Dummy to force init

    function _ownedProcessRunning(): bool {
        return CompositorService.isNiri ? wlsunsetProc.running : hyprsunsetProc.running
    }

    function _startOwnedProcess(): void {
        if (root._destroying || root._ownedProcessRunning())
            return
        root._pendingEnable = false
        if (CompositorService.isNiri)
            wlsunsetProc.running = true
        else
            hyprsunsetProc.running = true
    }

    function _stopOwnedProcess(restart: bool): void {
        root._restartOwnedAfterExit = restart
        if (CompositorService.isNiri) {
            if (wlsunsetProc.running) {
                wlsunsetProc.running = false
                return
            }
        } else if (hyprsunsetProc.running) {
            hyprsunsetProc.running = false
            return
        }

        if (restart) {
            root._restartOwnedAfterExit = false
            root._startOwnedProcess()
        }
    }

    function _restartOwnedProcess(): void {
        // Do not mutate an externally-owned process merely because Hadalis can
        // detect it. Only the child launched by this singleton is restartable.
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
        if (root._pendingEnable) {
            root._pendingEnable = false
            if (!root.active)
                root._startOwnedProcess()
        }
    }

    function enable() {
        if (root._ownedProcessRunning()) {
            root.active = true
            return
        }
        if (!root.stateKnown) {
            root._pendingEnable = true
            root.fetchState()
            return
        }
        // A process that Hadalis did not launch is not ours to replace or kill.
        if (root.active)
            return
        root._startOwnedProcess()
    }

    function disable() {
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

        // Re-check externally-owned state, but never use kill-by-name here.
        if (!root.stateKnown || root.active)
            root.fetchState()
        else
            root.active = false
    }

    function fetchState() {
        if (CompositorService.isNiri) {
            if (!niriFetchProc.running)
                niriFetchProc.running = true;
        } else if (!fetchProc.running) {
            fetchProc.running = true;
        }
    }

    // === Hyprland processes ===
    Process {
        id: hyprsunsetProc
        property bool startObserved: false
        running: false
        command: ["/usr/bin/hyprsunset", "--temperature", root.colorTemperature.toString()]

        onRunningChanged: {
            if (hyprsunsetProc.running) {
                hyprsunsetProc.startObserved = false
                return
            }
            if (hyprsunsetProc.startObserved)
                return
            root.active = false
            root._ownedProcessStopped()
        }
        onStarted: {
            hyprsunsetProc.startObserved = true
            root.stateKnown = true
            root.active = true
        }
        onExited: root._ownedProcessStopped()
    }

    Process {
        id: fetchProc
        running: !CompositorService.isNiri
        command: ["/usr/bin/bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
        }
        onExited: (exitCode, exitStatus) => {
            const output = stateCollector.text.trim()
            root._finishStateProbe(exitCode === 0
                && output.length > 0
                && !output.startsWith("Couldn't")
                && output !== "6500")
        }
    }

    // === Niri processes (wlsunset) ===
    Process {
        id: wlsunsetProc
        property bool startObserved: false
        running: false
        // Force "always night" mode: sunset at 00:00, sunrise at 23:59.
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
            if (wlsunsetProc.startObserved)
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
        id: niriFetchProc
        running: CompositorService.isNiri
        command: ["/usr/bin/pidof", "wlsunset"]
        onExited: (exitCode, exitStatus) => root._finishStateProbe(exitCode === 0)
    }

    function toggle(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.active;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        Config.setNestedValue("light.night.enabled", root.manualActive);
        if (root.manualActive) {
            root.enable();
        } else {
            root.disable();
        }
    }

    // React to temperature changes while active. Restart only the process that
    // this singleton owns; an external night-light process is left untouched.
    Connections {
        target: Config.options?.light?.night ?? null
        enabled: !!(Config.options?.light?.night)
        
        function onColorTemperatureChanged() {
            if (!root.active || !root._ownedProcessRunning())
                return
            root._pendingRestart = true
            restartDebounce.restart()
        }
    }

    // React to schedule changes while automatic mode is on
    Connections {
        target: Config.options?.light?.night ?? null
        enabled: root.automatic && !!(Config.options?.light?.night)
        
        function onFromChanged() {
            root.firstEvaluation = true;
            root.reEvaluate();
        }
        
        function onToChanged() {
            root.firstEvaluation = true;
            root.reEvaluate();
        }
    }

    Component.onDestruction: {
        root._destroying = true
        restartDebounce.stop()
        stateVerifyTimer.stop()
        root._restartOwnedAfterExit = false
        hyprsunsetProc.running = false
        wlsunsetProc.running = false
    }
}
