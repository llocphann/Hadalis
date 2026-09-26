pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.background?.widgets?.worldClock?.enable ?? false

    readonly property var fallbackTimezones: ["Pacific/Auckland", "Pacific/Honolulu", "Australia/Sydney", "Australia/Perth", "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore", "Asia/Bangkok", "Asia/Kolkata", "Asia/Dubai", "Asia/Tehran", "Asia/Jerusalem", "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Warsaw", "Europe/Berlin", "Europe/Paris", "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Lisbon", "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Lagos", "America/Sao_Paulo", "America/Argentina/Buenos_Aires", "America/Santiago", "America/Montevideo", "America/La_Paz", "America/Lima", "America/Bogota", "America/Caracas", "America/Mexico_City", "America/New_York", "America/Chicago", "America/Denver", "America/Phoenix", "America/Los_Angeles", "America/Anchorage", "America/Vancouver", "America/Toronto", "UTC"]

    readonly property var timezoneList: {
        if (typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function") {
            try {
                return Intl.supportedValuesOf("timeZone");
            } catch (e) {
                return root.fallbackTimezones;
            }
        }
        return root.fallbackTimezones;
    }

    function labelFor(tz: string): string {
        const parts = String(tz).split("/");
        const city = (parts[parts.length - 1] ?? tz).replace(/_/g, " ");
        const region = parts.length > 1 ? parts[0] : "";
        return region ? `${city} (${region})` : city;
    }

    readonly property var comboModel: root.timezoneList.map(tz => ({
                label: root.labelFor(tz),
                tz: tz,
                icon: ""
            }))

    readonly property var defaultTimezones: ["Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"]
    readonly property var timezones: {
        const configured = Config.options?.background?.widgets?.worldClock?.timezones
        if (!Array.isArray(configured))
            return root.defaultTimezones
        return configured.map(tz => String(tz ?? "").trim())
            .filter(tz => tz.length > 0)
    }

    function setTimezone(index: int, tz: string): void {
        let updated = root.timezones.slice();
        if (index < 0 || index >= updated.length)
            return;
        const normalized = String(tz ?? "").trim()
        if (normalized.length === 0)
            return;
        updated[index] = normalized;
        Config.setNestedValue("background.widgets.worldClock.timezones", updated);
    }

    readonly property string ampmToken: {
        const fmt = Config.options?.time?.format ?? "HH:mm";
        if (fmt.includes("AP"))
            return "AP";
        if (fmt.includes("ap"))
            return "ap";
        return "";
    }
    readonly property bool use24h: root.ampmToken === ""

    property var now: new Date()
    property var offsetsMinutes: [0, 0, 0, 0]
    property var _offsetTimezones: []
    property bool _refreshQueued: false

    function _parseOffset(value): int {
        const match = String(value ?? "").trim().match(/^([+-])(\d{2})(\d{2})$/)
        if (!match)
            return 0
        return (match[1] === "-" ? -1 : 1)
            * (parseInt(match[2]) * 60 + parseInt(match[3]))
    }

    function _finishOffsetRefresh(offsets): void {
        const expectedCount = root._offsetTimezones.length
        const normalized = []
        for (let i = 0; i < expectedCount; ++i)
            normalized.push(Number(offsets?.[i] ?? 0))

        root._offsetTimezones = []
        if (root.enabled)
            root.offsetsMinutes = normalized

        if (root._refreshQueued && root.enabled) {
            root._refreshQueued = false
            Qt.callLater(root.refreshOffsets)
        }
    }

    function refreshOffsets(): void {
        if (!root.enabled)
            return
        if (offsetProc.running) {
            root._refreshQueued = true
            return
        }

        const zones = root.timezones.slice()
        root._refreshQueued = false
        root._offsetTimezones = zones
        if (zones.length === 0) {
            root.offsetsMinutes = []
            return
        }

        // One shell process handles every configured timezone. Timezone names
        // are argv entries, never interpolated into shell source.
        const command = [
            "/usr/bin/sh",
            "-c",
            "for tz; do TZ=\"$tz\" date +%z || printf '+0000\\n'; done",
            "world-clock-offsets"
        ]
        for (let i = 0; i < zones.length; ++i)
            command.push(String(zones[i]))

        offsetProc.exec({ command: command })
    }

    function _scheduleMinuteTick(): void {
        root.now = new Date()
        if (!root.enabled) {
            minuteTick.stop()
            return
        }

        // The rendered world-clock strings have minute precision. Wake once at
        // the next minute boundary instead of keeping the shell on a 1 Hz timer.
        const nowMs = root.now.getTime()
        minuteTick.interval = Math.max(250, 60000 - (nowMs % 60000) + 25)
        minuteTick.restart()
    }

    onTimezonesChanged: root.refreshOffsets()
    onEnabledChanged: {
        if (root.enabled) {
            root._scheduleMinuteTick()
            root.refreshOffsets()
        } else {
            minuteTick.stop()
        }
    }
    Component.onCompleted: {
        root.refreshOffsets()
        if (root.enabled)
            root._scheduleMinuteTick()
    }

    Timer {
        id: minuteTick
        interval: 60000
        repeat: false
        onTriggered: root._scheduleMinuteTick()
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refreshOffsets()
    }

    Process {
        id: offsetProc
        property bool startObserved: false
        stdout: StdioCollector {
            id: offsetCollector
        }
        onRunningChanged: {
            if (offsetProc.running) {
                offsetProc.startObserved = false
                return
            }
            if (offsetProc.startObserved)
                return

            // Failed spawn: preserve one zero offset per requested timezone so
            // consumers never observe a mismatched list length.
            root._finishOffsetRefresh([])
        }
        onStarted: offsetProc.startObserved = true
        onExited: {
            const rawLines = offsetCollector.text.trim().length > 0
                ? offsetCollector.text.trim().split(/\r?\n/)
                : []
            const offsets = []
            for (let i = 0; i < root._offsetTimezones.length; ++i)
                offsets.push(root._parseOffset(rawLines[i] ?? ""))
            root._finishOffsetRefresh(offsets)
        }
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function cityDate(index: int): var {
        const offsetMin = root.offsetsMinutes[index] ?? 0;
        return new Date(root.now.getTime() + offsetMin * 60000);
    }

    function timeStringFor(index: int): string {
        const cd = root.cityDate(index);
        const h = cd.getUTCHours();
        const m = cd.getUTCMinutes();
        if (root.use24h)
            return root.pad(h) + ":" + root.pad(m);
        let h12 = h % 12;
        if (h12 === 0)
            h12 = 12;
        const base = root.pad(h12) + ":" + root.pad(m);
        if (root.ampmToken === "AP")
            return base + " " + (h >= 12 ? "PM" : "AM");
        return base + " " + (h >= 12 ? "pm" : "am");
    }

    function offsetLabelFor(index: int): string {
        const offsetMin = root.offsetsMinutes[index] ?? 0;
        const sign = offsetMin >= 0 ? "+" : "-";
        const abs = Math.abs(offsetMin);
        const h = Math.floor(abs / 60);
        const m = abs % 60;
        return "UTC" + sign + h + (m > 0 ? ":" + root.pad(m) : "");
    }

    function isDaytimeFor(index: int): bool {
        const h = root.cityDate(index).getUTCHours();
        return h >= 6 && h < 18;
    }

    readonly property var entries: root.timezones.map((tz, i) => ({
                tz: tz,
                name: root.labelFor(tz).split(" (")[0],
                time: root.timeStringFor(i),
                offset: root.offsetLabelFor(i),
                isDay: root.isDaytimeFor(i)
            }))
}
