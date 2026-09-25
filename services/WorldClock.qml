pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

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
    property int _offsetIndex: -1
    property var _offsetTimezones: []
    property var _nextOffsets: []
    property bool _refreshQueued: false
    property string _offsetText: ""
    property var _intlFormatters: ({})

    function _intlFormatter(tz: string): var {
        if (typeof Intl === "undefined" || typeof Intl.DateTimeFormat !== "function")
            return null

        const key = String(tz ?? "UTC")
        const cached = root._intlFormatters[key]
        if (cached)
            return cached

        try {
            const formatter = new Intl.DateTimeFormat("en-US", {
                timeZone: key,
                year: "numeric",
                month: "2-digit",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
                hourCycle: "h23"
            })
            root._intlFormatters[key] = formatter
            return formatter
        } catch (error) {
            return null
        }
    }

    function _intlOffsetMinutes(tz: string, instant: var): var {
        const formatter = root._intlFormatter(tz)
        if (!formatter || typeof formatter.formatToParts !== "function")
            return null

        try {
            const values = {}
            const parts = formatter.formatToParts(instant)
            for (const part of parts) {
                if (part.type === "year" || part.type === "month"
                        || part.type === "day" || part.type === "hour"
                        || part.type === "minute" || part.type === "second")
                    values[part.type] = Number(part.value)
            }

            if (![values.year, values.month, values.day, values.hour,
                    values.minute, values.second].every(Number.isFinite))
                return null

            const zonedAsUtc = Date.UTC(values.year, values.month - 1, values.day,
                values.hour, values.minute, values.second)
            const instantMs = Math.floor(instant.getTime() / 1000) * 1000
            return Math.round((zonedAsUtc - instantMs) / 60000)
        } catch (error) {
            return null
        }
    }

    function _intlOffsets(timezones: var): var {
        const instant = new Date()
        const offsets = []
        for (const tz of timezones) {
            const offset = root._intlOffsetMinutes(String(tz ?? "UTC"), instant)
            if (!Number.isFinite(offset))
                return null
            offsets.push(offset)
        }
        return offsets
    }

    function refreshOffsets(): void {
        if (!root.enabled)
            return;
        if (offsetProc.running) {
            root._refreshQueued = true;
            return;
        }

        root._refreshQueued = false;

        // Modern Qt JS runtimes already expose Intl timezone data. Compute all
        // offsets in-process and avoid spawning one date(1) process per city on
        // every refresh. The existing date path remains the compatibility
        // fallback for older or incomplete Intl implementations.
        const intlOffsets = root._intlOffsets(root.timezones)
        if (intlOffsets !== null) {
            root.offsetsMinutes = intlOffsets
            root._offsetIndex = -1
            root._offsetTimezones = []
            root._nextOffsets = []
            return
        }

        root._offsetIndex = 0;
        root._offsetTimezones = root.timezones.slice();
        root._nextOffsets = [];
        root._runNextOffset();
    }

    function _completeOffset(offset: int): void {
        const nextOffsets = root._nextOffsets.slice();
        nextOffsets.push(offset);
        root._nextOffsets = nextOffsets;
        root._offsetIndex++;
        Qt.callLater(root._runNextOffset);
    }

    function _runNextOffset(): void {
        if (!root.enabled) {
            root._offsetIndex = -1;
            root._offsetTimezones = [];
            root._nextOffsets = [];
            root._refreshQueued = false;
            return;
        }
        if (root._offsetIndex >= root._offsetTimezones.length) {
            root._offsetIndex = -1;
            if (root._refreshQueued) {
                root.refreshOffsets();
                return;
            }
            root.offsetsMinutes = root._nextOffsets;
            root._offsetTimezones = [];
            return;
        }

        root._offsetText = "";
        offsetProc.exec({
            command: ["date", "+%z"],
            environment: ({ TZ: String(root._offsetTimezones[root._offsetIndex] ?? "UTC") })
        });
    }

    onTimezonesChanged: root.refreshOffsets()
    onEnabledChanged: {
        if (!root.enabled)
            return
        root.now = new Date()
        root.refreshOffsets()
    }
    Component.onCompleted: {
        root.now = new Date()
        root.refreshOffsets()
    }

    Connections {
        target: DateTime
        enabled: root.enabled

        function onMinuteEpochChanged(): void {
            root.now = new Date()
            // Offset changes are rare (DST), so preserve the existing five-minute
            // refresh cadence without owning a second repeating timer.
            if ((DateTime.minuteEpoch % 5) === 0)
                root.refreshOffsets()
        }
    }

    Process {
        id: offsetProc
        property bool startObserved: false
        stdout: StdioCollector {
            id: offsetCollector
            onStreamFinished: root._offsetText = offsetCollector.text.trim()
        }
        onRunningChanged: {
            if (offsetProc.running) {
                offsetProc.startObserved = false;
                return;
            }
            if (offsetProc.startObserved)
                return;

            root._completeOffset(0);
        }
        onStarted: offsetProc.startObserved = true
        onExited: {
            const match = root._offsetText.match(/^([+-])(\d{2})(\d{2})$/);
            const offset = match
                ? (match[1] === "-" ? -1 : 1)
                    * (parseInt(match[2]) * 60 + parseInt(match[3]))
                : 0;
            root._completeOffset(offset);
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
