pragma Singleton
import qs
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import qs.modules.common

Singleton {
    id: root

    property string _hibernateCapability: ""
    readonly property bool hibernateCapabilityKnown: _hibernateCapability.length > 0
    readonly property bool canHibernate: _hibernateCapability === "yes"
    readonly property bool showHibernateAction: !hibernateCapabilityKnown || canHibernate

    Timer {
        id: _hibernateMonitorsOffTimer
        interval: 450
        repeat: false
        onTriggered: NiriService.powerOffMonitors()
    }

    Timer {
        id: _hibernateTimer
        interval: 900
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/systemctl", "hibernate", "-i"])
            Quickshell.execDetached(["/usr/bin/loginctl", "hibernate"])
        }
    }

    Timer {
        id: _suspendTimer
        interval: 600
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["/usr/bin/systemctl", "suspend", "-i"])
        }
    }

    function _parseLogin1Capability(text: string): string {
        const trimmed = (text ?? "").trim()
        const match = trimmed.match(/^s\s+"([^"]+)"$/)
        return (match ? match[1] : trimmed).toLowerCase()
    }

    function refreshSleepCapabilities(): void {
        detectHibernateCapability.running = false
        detectHibernateCapability.running = true
    }

    function _notifyHibernateUnavailable(): void {
        Quickshell.execDetached([
            "/usr/bin/notify-send",
            Translation.tr("Hibernate unavailable"),
            Translation.tr("This system does not report hibernation support. Configure persistent swap and resume first."),
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])
    }

    function closeAllWindows() {
        const windows = NiriService.windows ?? []
        windows.forEach(window => {
            const id = window?.id
            if (id !== undefined && id !== null)
                NiriService.closeWindow(id)
        })
    }

    function lock() {
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"]);
    }

    function suspend() {
        if (Config.options?.idle?.lockBeforeSleep !== false) {
            lock()
            _suspendTimer.restart()
        } else {
            Quickshell.execDetached(["/usr/bin/systemctl", "suspend", "-i"])
        }
    }

    function logout() {
        NiriService.quit()
    }

    function launchTaskManager() {
        AppLauncher.launch("taskManager")
    }

    function hibernate() {
        if (hibernateCapabilityKnown && !canHibernate) {
            root.refreshSleepCapabilities()
            root._notifyHibernateUnavailable()
            return
        }

        lock();
        _hibernateMonitorsOffTimer.restart()
        _hibernateTimer.restart()
    }

    function poweroff() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "poweroff", "-i"])
        Quickshell.execDetached(["/usr/bin/loginctl", "poweroff"])
    }

    function reboot() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "reboot", "-i"])
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot"])
    }

    function rebootToFirmware() {
        closeAllWindows();
        Quickshell.execDetached(["/usr/bin/systemctl", "reboot", "--firmware-setup"])
        Quickshell.execDetached(["/usr/bin/loginctl", "reboot", "--firmware-setup"])
    }

    Connections {
        target: GlobalStates

        function onSessionOpenChanged() {
            if (GlobalStates.sessionOpen) {
                root.refreshSleepCapabilities()
            }
        }
    }

    Process {
        id: detectHibernateCapability
        command: [
            "/usr/bin/busctl", "--system", "call",
            "org.freedesktop.login1",
            "/org/freedesktop/login1",
            "org.freedesktop.login1.Manager",
            "CanHibernate",
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const capability = root._parseLogin1Capability(text)
                if (capability.length > 0) {
                    root._hibernateCapability = capability
                }
            }
        }
    }
}
