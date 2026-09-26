pragma Singleton
pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: ((Config.options?.time?.secondPrecision ?? false)
                || GlobalStates.screenLocked)
            ? SystemClock.Seconds : SystemClock.Minutes
    }
    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
    // Like time, but appends :ss when secondPrecision is enabled — used by bar clocks
    property string timeDisplay: {
        const fmt = Config.options?.time?.format ?? "hh:mm";
        if (!(Config.options?.time?.secondPrecision ?? false) || fmt.includes("s"))
            return Qt.locale().toString(clock.date, fmt);
        const meridiemIndex = Math.max(fmt.lastIndexOf(" AP"), fmt.lastIndexOf(" ap"));
        return Qt.locale().toString(clock.date, meridiemIndex >= 0 ? fmt.slice(0, meridiemIndex) + ":ss" + fmt.slice(meridiemIndex) : fmt + ":ss");
    }
    property string shortDate: Qt.locale().toString(clock.date, Config.options?.time.shortDateFormat ?? "dd/MM")
    property string date: Qt.locale().toString(clock.date, Config.options?.time.dateFormat ?? "dddd, dd/MM")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dd MMMM yyyy")
    property string uptime: "0h, 0m"

    function _refreshUptime(): void {
        fileUptime.reload();
        const textUptime = String(fileUptime.text() ?? "").trim();
        const uptimeSeconds = Number(textUptime.split(/\s+/)[0]);
        if (!Number.isFinite(uptimeSeconds) || uptimeSeconds < 0)
            return;

        // Convert seconds to days, hours, and minutes
        const days = Math.floor(uptimeSeconds / 86400);
        const hours = Math.floor((uptimeSeconds % 86400) / 3600);
        const minutes = Math.floor((uptimeSeconds % 3600) / 60);

        // Build the formatted uptime string
        let formatted = "";
        if (days > 0)
            formatted += `${days}d`;
        if (hours > 0)
            formatted += `${formatted ? ", " : ""}${hours}h`;
        if (minutes > 0 || !formatted)
            formatted += `${formatted ? ", " : ""}${minutes}m`;
        uptime = formatted;
    }

    Connections {
        target: clock
        function onMinutesChanged(): void {
            root._refreshUptime()
        }
    }

    Component.onCompleted: root._refreshUptime()

    FileView {
        id: fileUptime

        path: "/proc/uptime"
    }
}
