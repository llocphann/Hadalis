pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Currently only supports Arch.
 */
Singleton {
    id: root

    function _nonNegativeInt(value, fallback: int): int {
        const parsed = Number(value)
        return Number.isFinite(parsed) && parsed >= 0
            ? Math.max(0, Math.round(parsed)) : fallback
    }

    property bool available: false
    property int count: 0
    readonly property int checkIntervalMinutes: {
        const configured = Number(Config.options?.updates?.checkInterval)
        return Number.isFinite(configured) && configured > 0
            ? Math.max(1, Math.round(configured)) : 120
    }
    readonly property int adviseUpdateThreshold: root._nonNegativeInt(
        Config.options?.updates?.adviseUpdateThreshold, 75)
    readonly property int stronglyAdviseUpdateThreshold: root._nonNegativeInt(
        Config.options?.updates?.stronglyAdviseUpdateThreshold, 200)
    
    readonly property bool updateAdvised: available && count > root.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > root.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available || checkUpdatesProc.running) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: root.checkIntervalMinutes * 60 * 1000
        repeat: true
        running: Config.ready
        onTriggered: {
            if (root.available) {
                print("[Updates] Periodic update check due")
                root.refresh();
            } else if (!checkAvailabilityProc.running) {
                checkAvailabilityProc.running = true;
            }
        }
    }

    Timer {
        id: availabilityDefer
        interval: 1500
        repeat: false
        onTriggered: checkAvailabilityProc.running = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) availabilityDefer.start()
        }
    }

    Component.onCompleted: {
        if (Config.ready) availabilityDefer.start()
    }

    Process {
        id: checkAvailabilityProc
        running: false
        property bool startObserved: false
        command: ["/usr/bin/sh", "-c", "command -v checkupdates >/dev/null 2>&1"]

        onRunningChanged: {
            if (checkAvailabilityProc.running) {
                checkAvailabilityProc.startObserved = false
                return
            }
            if (checkAvailabilityProc.startObserved)
                return

            root.available = false
            root.count = 0
            console.warn("[Updates] Failed to start update availability probe")
        }

        onStarted: checkAvailabilityProc.startObserved = true

        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            if (!root.available)
                root.count = 0;
            root.refresh();
        }
    }

    Process {
        id: checkUpdatesProc
        property bool startObserved: false
        command: ["checkupdates"]

        onRunningChanged: {
            if (checkUpdatesProc.running) {
                checkUpdatesProc.startObserved = false
                return
            }
            if (checkUpdatesProc.startObserved)
                return

            root.count = 0
            root.available = false
            console.warn("[Updates] Failed to start checkupdates")
        }

        onStarted: checkUpdatesProc.startObserved = true

        stdout: StdioCollector {
            onStreamFinished: {
                const t = (text ?? "").trim();
                root.count = t.length > 0 ? t.split("\n").length : 0;
            }
        }
        onExited: (exitCode, exitStatus) => {
            // pacman-contrib checkupdates uses exit 2 for the normal
            // "no updates available" state. Clear any stale previous count and
            // reserve error logging for genuine failures.
            if (exitCode === 2) {
                root.count = 0;
                return;
            }
            if (exitCode !== 0) {
                root.count = 0;
                console.error("[Updates] checkupdates failed", exitCode, exitStatus)
            }
        }
    }
}
