pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false
    property bool nativeInstalled: false

    function fetchAvailability() {
        if (whichProc.running || flatpakInfoProc.running) return
        whichProc.running = true
    }

    function fetchActiveState() {
        if (!root.available) {
            root.active = false
            return
        }
        if (root.nativeInstalled) {
            if (nativeStatusProc.running) return
            nativeStatusProc.running = true
            return
        }
        if (flatpakPsProc.running) return
        flatpakPsProc.running = true
    }

    function disable() {
        if (!root.available) return
        root.active = false
        if (root.nativeInstalled) {
            if (pkillProc.running) return
            pkillProc.running = true
        } else {
            if (flatpakKillProc.running) return
            flatpakKillProc.running = true
        }
    }

    function enable() {
        if (!root.available) return
        root.active = true
        if (root.nativeInstalled) {
            Quickshell.execDetached(["/usr/bin/env", "easyeffects", "--service-mode"])
        } else {
            Quickshell.execDetached(["/usr/bin/env", "flatpak", "run", "com.github.wwmm.easyeffects", "--service-mode"])
        }
        refreshStateTimer.restart()
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Timer {
        id: initTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.fetchAvailability()
            root.fetchActiveState()
        }
    }

    Timer {
        id: refreshStateTimer
        interval: 900
        repeat: false
        onTriggered: root.fetchActiveState()
    }

    Timer {
        id: statePollTimer
        interval: 5000
        repeat: true
        running: Config.ready && root.available
        onTriggered: root.fetchActiveState()
    }

    Component.onCompleted: {
        if (Config.ready) {
            initTimer.start()
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                initTimer.start()
            }
        }
    }

    Process {
        id: whichProc
        running: false
        command: ["/usr/bin/env", "sh", "-c", "command -v easyeffects >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.nativeInstalled = true
                root.available = true
                Qt.callLater(() => root.fetchActiveState())
            } else {
                root.nativeInstalled = false
                flatpakInfoProc.running = true
            }
        }
    }

    Process {
        id: flatpakInfoProc
        running: false
        command: ["/usr/bin/env", "flatpak", "info", "com.github.wwmm.easyeffects"]
        onExited: (exitCode, exitStatus) => {
            root.nativeInstalled = false
            root.available = (exitCode === 0)
            if (root.available)
                Qt.callLater(() => root.fetchActiveState())
            else
                root.active = false
        }
    }

    Process {
        id: nativeStatusProc
        running: false
        command: ["/usr/bin/env", "pgrep", "-x", "easyeffects"]
        onExited: (exitCode, _exitStatus) => {
            root.active = (exitCode === 0)
        }
    }

    Process {
        id: flatpakPsProc
        running: false
        command: ["/usr/bin/env", "flatpak", "ps", "--columns=application"]
        stdout: StdioCollector {
            id: flatpakPsCollector
            onStreamFinished: {
                const t = (flatpakPsCollector.text ?? "")
                root.active = t.split("\n").some(l => l.trim() === "com.github.wwmm.easyeffects")
            }
        }
    }

    Process {
        id: pkillProc
        running: false
        command: ["/usr/bin/env", "pkill", "-x", "easyeffects"]
        onExited: (_exitCode, _exitStatus) => refreshStateTimer.restart()
    }

    Process {
        id: flatpakKillProc
        running: false
        command: ["/usr/bin/env", "flatpak", "kill", "com.github.wwmm.easyeffects"]
        onExited: (_exitCode, _exitStatus) => refreshStateTimer.restart()
    }
}
