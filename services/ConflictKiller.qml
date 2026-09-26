pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string killDialogQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("killDialog.qml"))

    function load() {
        // dummy to force init
    }

    // Defer conflict checks to avoid process spawns during the critical shell startup window
    Timer {
        id: conflictCheckDelay
        interval: 1500
        repeat: false
        onTriggered: conflictProbe.running = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                conflictCheckDelay.restart()
            }
        }
    }

    Component.onCompleted: {
        if (Config.ready) {
            conflictCheckDelay.restart()
        }
    }

    function _maybeHandleConflicts(): void {
        if (conflictProbe.running)
            return

        const conflictingTrays = root._traysConflict
        const conflictingNotifications = root._notifsConflict

        var openDialog = false;
        if (conflictingTrays) {
            if (!(Config.options?.conflictKiller?.autoKillTrays ?? false)) openDialog = true;
            else Quickshell.execDetached(["/usr/bin/killall", "kded6"])
        }
        if (conflictingNotifications) {
            if (!(Config.options?.conflictKiller?.autoKillNotificationDaemons ?? false)) openDialog = true;
            else Quickshell.execDetached(["/usr/bin/killall", "mako", "dunst"])
        }
        if (openDialog) {
            Quickshell.execDetached(["/usr/bin/qs", "-p", root.killDialogQmlPath])
        }
    }

    property bool _traysConflict: false
    property bool _notifsConflict: false

    Process {
        id: conflictProbe
        property bool startObserved: false
        command: [
            "/bin/sh", "-c",
            "trays=0; notifs=0; " +
            "for comm in /proc/[0-9]*/comm; do " +
            "[ -r \"$comm\" ] || continue; " +
            "IFS= read -r name < \"$comm\" || continue; " +
            "case \"$name\" in " +
            "kded6) trays=1 ;; " +
            "mako|dunst) notifs=1 ;; " +
            "esac; " +
            "[ \"$trays\" -eq 1 ] && [ \"$notifs\" -eq 1 ] && break; " +
            "done; " +
            "printf '%s\\t%s\\n' \"$trays\" \"$notifs\""
        ]

        stdout: StdioCollector {
            id: conflictProbeOutput
        }

        onRunningChanged: {
            if (conflictProbe.running) {
                conflictProbe.startObserved = false
                return
            }
            if (conflictProbe.startObserved)
                return

            root._traysConflict = false
            root._notifsConflict = false
            root._maybeHandleConflicts()
        }

        onStarted: conflictProbe.startObserved = true

        onExited: (exitCode, exitStatus) => {
            const fields = String(conflictProbeOutput.text ?? "").trim().split("\t")
            root._traysConflict = exitCode === 0 && fields[0] === "1"
            root._notifsConflict = exitCode === 0 && fields[1] === "1"
            root._maybeHandleConflicts()
        }
    }
}
