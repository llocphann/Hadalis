pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple Pomodoro time manager.
 */
Singleton {
    id: root

    // Pomodoro config - use explicit properties to ensure reactivity
    property int focusTime: 1500
    property int breakTime: 300
    property int longBreakTime: 900
    property int cyclesBeforeLongBreak: 4

    function _positiveInt(value, fallback: int): int {
        const parsed = Number(value)
        return Number.isFinite(parsed) && parsed > 0 ? Math.max(1, Math.round(parsed)) : fallback
    }

    function _stopwatchTick(value): int {
        const parsed = Number(value)
        if (!Number.isFinite(parsed)) return 0

        // Keep 10 ms wall-clock ticks inside the signed 32-bit range used by
        // Persistent.states.timer.stopwatch.start and stopwatchTime. Elapsed
        // values use the same modulus, so wraparound remains monotonic for the
        // full duration an int stopwatch can represent (~248 days).
        const modulus = 2147483648
        const tick = Math.floor(parsed)
        return ((tick % modulus) + modulus) % modulus
    }

    // While a timer is paused, reuse its persisted `start` field to hold the
    // frozen progress. Negative values distinguish this encoding from legacy
    // positive wall-clock/tick starts without expanding the persistent schema.
    function _encodePausedValue(value): int {
        const parsed = Number(value)
        const normalized = Number.isFinite(parsed) ? Math.max(0, Math.round(parsed)) : 0
        return -normalized - 1
    }

    function _decodePausedValue(value, fallback: int, maximum: int): int {
        const parsed = Number(value)
        let decoded = Number.isFinite(parsed) && parsed < 0
            ? Math.max(0, -Math.round(parsed) - 1)
            : Math.max(0, fallback)
        if (maximum >= 0)
            decoded = Math.min(decoded, maximum)
        return decoded
    }

    // Helper to sync all pomodoro values from Config
    function _syncPomodoroConfig() {
        root.focusTime = root._positiveInt(Config.options?.time?.pomodoro?.focus, 1500)
        root.breakTime = root._positiveInt(Config.options?.time?.pomodoro?.breakTime, 300)
        root.longBreakTime = root._positiveInt(Config.options?.time?.pomodoro?.longBreak, 900)
        root.cyclesBeforeLongBreak = root._positiveInt(Config.options?.time?.pomodoro?.cyclesBeforeLongBreak, 4)
    }

    // Sync pomodoro config on ANY config change (reliable - survives object recreation after file reload)
    Connections {
        target: Config
        function onConfigChanged() { root._syncPomodoroConfig() }
        function onReadyChanged() {
            if (Config.ready) {
                root._syncPomodoroConfig()
                if (Persistent.ready)
                    root._restorePersistedTimers()
            }
        }
    }

    Component.onCompleted: {
        if (Config.ready) root._syncPomodoroConfig()
        if (Persistent.ready) root._restorePersistedTimers()
    }

    property bool pomodoroRunning: Persistent.states?.timer?.pomodoro?.running ?? false
    property bool pomodoroPaused: Persistent.states?.timer?.pomodoro?.paused ?? false
    property bool pomodoroBreak: Persistent.states?.timer?.pomodoro?.isBreak ?? false
    property bool pomodoroLongBreak: pomodoroBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak)
    property int pomodoroLapDuration: pomodoroLongBreak ? longBreakTime : pomodoroBreak ? breakTime : focusTime
    property int pomodoroSecondsLeft: pomodoroLapDuration
    property int pomodoroCycle: Persistent.states?.timer?.pomodoro?.cycle ?? 0

    // When focusTime changes and timer is not running, reset pomodoroSecondsLeft
    onFocusTimeChanged: {
        if (!pomodoroRunning && !pomodoroBreak) {
            pomodoroSecondsLeft = focusTime
        }
    }
    onBreakTimeChanged: {
        if (!pomodoroRunning && pomodoroBreak && !pomodoroLongBreak) {
            pomodoroSecondsLeft = breakTime
        }
    }
    onLongBreakTimeChanged: {
        if (!pomodoroRunning && pomodoroLongBreak) {
            pomodoroSecondsLeft = longBreakTime
        }
    }

    property bool stopwatchRunning: Persistent.states?.timer?.stopwatch?.running ?? false
    property bool stopwatchPaused: Persistent.states?.timer?.stopwatch?.paused ?? false
    property int stopwatchTime: 0
    property int stopwatchStart: root._stopwatchTick(Persistent.states?.timer?.stopwatch?.start ?? 0)
    property var stopwatchLaps: {
        const stored = Persistent.states?.timer?.stopwatch?.laps
        return Array.isArray(stored) ? stored : []
    }

    // Countdown Timer
    property bool countdownRunning: Persistent.states?.timer?.countdown?.running ?? false
    property bool countdownPaused: Persistent.states?.timer?.countdown?.paused ?? false
    property int countdownDuration: root._positiveInt(Persistent.states?.timer?.countdown?.duration, 300)
    property int countdownSecondsLeft: countdownDuration

    function _restorePersistedTimers(): void {
        if (!Persistent.ready)
            return

        if (root.pomodoroRunning) {
            if (root.pomodoroPaused) {
                root.pomodoroSecondsLeft = root._decodePausedValue(
                    Persistent.states.timer.pomodoro.start,
                    root.pomodoroLapDuration,
                    root.pomodoroLapDuration)
            } else {
                root.refreshPomodoro()
            }
        }

        if (!root.stopwatchRunning) {
            root.stopwatchTime = 0
        } else if (root.stopwatchPaused
                && Number(Persistent.states.timer.stopwatch.start) < 0) {
            root.stopwatchTime = root._decodePausedValue(
                Persistent.states.timer.stopwatch.start, 0, -1)
        } else {
            // Preserve legacy paused states that stored a positive start value;
            // future pauses use the negative frozen-progress encoding above.
            root.refreshStopwatch()
        }

        if (!root.countdownRunning) {
            root.countdownSecondsLeft = root.countdownDuration
        } else if (root.countdownPaused) {
            root.countdownSecondsLeft = root._decodePausedValue(
                Persistent.states.timer.countdown.start,
                root.countdownDuration,
                root.countdownDuration)
        } else {
            root.refreshCountdown()
        }
    }

    // Initialize when Persistent is ready
    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready)
                root._restorePersistedTimers()
        }
    }

    function getCurrentTimeInSeconds() {  // Pomodoro uses Seconds
        return Math.floor(Date.now() / 1000);
    }

    function getCurrentTimeIn10ms() {  // Stopwatch uses 10ms ticks kept in int range
        return root._stopwatchTick(Date.now() / 10);
    }

    // Pomodoro
    function refreshPomodoro() {
        // Work <-> break ?
        if (getCurrentTimeInSeconds() >= Persistent.states.timer.pomodoro.start + pomodoroLapDuration) {
            // Reset counts
            Persistent.states.timer.pomodoro.isBreak = !Persistent.states.timer.pomodoro.isBreak;
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();

            // Send notification
            let notificationMessage;
            if (Persistent.states.timer.pomodoro.isBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak)) {
                notificationMessage = Translation.tr(`🌿 Long break: %1 minutes`).arg(Math.floor(longBreakTime / 60));
            } else if (Persistent.states.timer.pomodoro.isBreak) {
                notificationMessage = Translation.tr(`☕ Break: %1 minutes`).arg(Math.floor(breakTime / 60));
            } else {
                notificationMessage = Translation.tr(`🔴 Focus: %1 minutes`).arg(Math.floor(focusTime / 60));
            }

            Quickshell.execDetached(["/usr/bin/notify-send", "Pomodoro", notificationMessage, "-a", "Shell"]);
            if (Config.options?.sounds?.pomodoro ?? false) {
                Audio.playEvent("pomodoroDone")
            }

            if (!pomodoroBreak) {
                Persistent.states.timer.pomodoro.cycle = (Persistent.states.timer.pomodoro.cycle + 1) % root.cyclesBeforeLongBreak;
            }
        }

        pomodoroSecondsLeft = pomodoroLapDuration - (getCurrentTimeInSeconds() - Persistent.states.timer.pomodoro.start);
    }

    Timer {
        id: pomodoroTimer
        interval: 200
        running: root.pomodoroRunning && !root.pomodoroPaused
        repeat: true
        onTriggered: refreshPomodoro()
    }

    function togglePomodoro() {
        if (pomodoroRunning) {
            if (pomodoroPaused) {
                const remaining = root._decodePausedValue(
                    Persistent.states.timer.pomodoro.start,
                    pomodoroSecondsLeft,
                    pomodoroLapDuration)
                pomodoroSecondsLeft = remaining
                Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds()
                    + remaining - pomodoroLapDuration
                Persistent.states.timer.pomodoro.paused = false
            } else {
                root.refreshPomodoro()
                Persistent.states.timer.pomodoro.start = root._encodePausedValue(pomodoroSecondsLeft)
                Persistent.states.timer.pomodoro.paused = true
            }
        } else {
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds()
                + pomodoroSecondsLeft - pomodoroLapDuration
            Persistent.states.timer.pomodoro.paused = false
            Persistent.states.timer.pomodoro.running = true
        }
    }

    function stopPomodoro() {
        resetPomodoro();
    }

    function resetPomodoro() {
        Persistent.states.timer.pomodoro.running = false;
        Persistent.states.timer.pomodoro.paused = false;
        Persistent.states.timer.pomodoro.isBreak = false;
        Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();
        Persistent.states.timer.pomodoro.cycle = 0;
        refreshPomodoro();
    }

    // Stopwatch
    function refreshStopwatch() {  // Stopwatch stores elapsed time in 10ms ticks
        stopwatchTime = root._stopwatchTick(getCurrentTimeIn10ms() - stopwatchStart);
    }

    Timer {
        id: stopwatchTimer
        interval: 33
        running: root.stopwatchRunning && !root.stopwatchPaused
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning) {
            if (root.stopwatchPaused)
                root.stopwatchResume()
            else
                root.stopwatchPause()
        } else {
            if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
            Persistent.states.timer.stopwatch.start = root._stopwatchTick(getCurrentTimeIn10ms() - stopwatchTime);
            Persistent.states.timer.stopwatch.paused = false;
            Persistent.states.timer.stopwatch.running = true;
        }
    }

    function stopStopwatch() {
        stopwatchReset();
    }

    function stopwatchPause() {
        if (!root.stopwatchRunning || root.stopwatchPaused)
            return
        root.refreshStopwatch()
        Persistent.states.timer.stopwatch.start = root._encodePausedValue(stopwatchTime)
        Persistent.states.timer.stopwatch.paused = true;
    }

    function stopwatchResume() {
        let elapsed = stopwatchTime
        if (root.stopwatchPaused) {
            elapsed = root._decodePausedValue(
                Persistent.states.timer.stopwatch.start,
                stopwatchTime,
                -1)
        }
        if (elapsed === 0) Persistent.states.timer.stopwatch.laps = [];
        root.stopwatchTime = elapsed
        Persistent.states.timer.stopwatch.start = root._stopwatchTick(getCurrentTimeIn10ms() - elapsed);
        Persistent.states.timer.stopwatch.paused = false;
        if (!stopwatchRunning) Persistent.states.timer.stopwatch.running = true;
    }

    function stopwatchReset() {
        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
        Persistent.states.timer.stopwatch.paused = false;
        Persistent.states.timer.stopwatch.start = 0;
    }

    function stopwatchRecordLap() {
        const stored = Persistent.states?.timer?.stopwatch?.laps
        const laps = Array.isArray(stored) ? stored.slice() : []
        laps.push(stopwatchTime)
        Persistent.states.timer.stopwatch.laps = laps
    }

    // Countdown Timer
    function refreshCountdown() {
        const elapsed = getCurrentTimeInSeconds() - Persistent.states.timer.countdown.start;
        countdownSecondsLeft = Math.max(0, countdownDuration - elapsed);
        
        if (countdownSecondsLeft <= 0 && countdownRunning) {
            Persistent.states.timer.countdown.running = false;
            Persistent.states.timer.countdown.paused = false;
            Quickshell.execDetached(["/usr/bin/notify-send", "Timer", Translation.tr("Time's up!"), "-a", "Shell", "-i", "alarm-symbolic"]);
            if (Config.options?.sounds?.timer ?? false) {
                Audio.playEvent("timerDone");
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 200
        running: root.countdownRunning && !root.countdownPaused
        repeat: true
        onTriggered: refreshCountdown()
    }

    function toggleCountdown(): void {
        if (countdownRunning) {
            if (countdownPaused) {
                const remaining = root._decodePausedValue(
                    Persistent.states.timer.countdown.start,
                    countdownSecondsLeft,
                    countdownDuration)
                countdownSecondsLeft = remaining
                Persistent.states.timer.countdown.start = getCurrentTimeInSeconds()
                    - (countdownDuration - remaining)
                Persistent.states.timer.countdown.paused = false
            } else {
                root.refreshCountdown()
                if (!root.countdownRunning)
                    return
                Persistent.states.timer.countdown.start = root._encodePausedValue(countdownSecondsLeft)
                Persistent.states.timer.countdown.paused = true
            }
        } else {
            Persistent.states.timer.countdown.start = getCurrentTimeInSeconds()
                - (countdownDuration - countdownSecondsLeft)
            Persistent.states.timer.countdown.paused = false;
            Persistent.states.timer.countdown.running = true;
        }
    }

    function stopCountdown(): void {
        resetCountdown();
    }

    function resetCountdown(): void {
        Persistent.states.timer.countdown.running = false;
        Persistent.states.timer.countdown.paused = false;
        countdownSecondsLeft = countdownDuration;
        Persistent.states.timer.countdown.start = getCurrentTimeInSeconds();
    }

    function setCountdownDuration(seconds: int): void {
        const normalized = root._positiveInt(seconds, 300)
        Persistent.states.timer.countdown.duration = normalized;
        if (!countdownRunning) {
            countdownSecondsLeft = normalized;
        }
    }
}
