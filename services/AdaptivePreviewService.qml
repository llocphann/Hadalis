pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import "AdaptivePreviewPolicy.js" as AdaptivePreviewPolicy

// Shared scheduler for compositor-native Overview previews.
//
// Snapshot caches stay independent from this service. A live claim is accepted
// only when the corresponding renderer has a real capture backend. Niri uses a
// Hadalis-owned QML plugin backed by ext-image-copy-capture; stock installations
// without that plugin remain on WindowPreviewService PNG snapshots.
Singleton {
    id: root

    readonly property string mode:
        AdaptivePreviewPolicy.normalizeMode(Config.options?.overview?.previewMode ?? "adaptive")
    readonly property int maxLiveWindows:
        AdaptivePreviewPolicy.boundedLiveLimit(Config.options?.overview?.maxLiveWindows ?? 6, 6)
    readonly property int niriMaxLiveWindows:
        AdaptivePreviewPolicy.boundedLiveLimit(Config.options?.overview?.niriMaxLiveWindows ?? 3, 3)
    readonly property bool liveOnHover: Config.options?.overview?.liveOnHover ?? true
    readonly property bool liveFocusedWindow: Config.options?.overview?.liveFocusedWindow ?? false
    readonly property bool liveMediaWindows: Config.options?.overview?.liveMediaWindows ?? true
    readonly property int promotionDelayMs:
        Math.max(0, Math.min(2000, Config.options?.overview?.livePromotionDelayMs ?? 180))
    readonly property int cooldownMs:
        Math.max(0, Math.min(10000, Config.options?.overview?.liveCooldownMs ?? 2500))
    readonly property real activityPromotionThreshold: {
        const value = Number(Config.options?.overview?.activityPromotionThreshold ?? 0.55)
        return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0.55
    }

    readonly property int niriPreviewMaxFps:
        Math.max(1, Math.min(30, Config.options?.overview?.niriPreviewMaxFps ?? 18))
    readonly property int niriProbeSlots:
        Math.max(1, Math.min(4, Config.options?.overview?.niriProbeSlots ?? 2))
    readonly property int niriProbeWindowMs:
        Math.max(350, Math.min(4000, Config.options?.overview?.niriProbeWindowMs ?? 800))
    readonly property int niriMotionSamples:
        Math.max(1, Math.min(6, Config.options?.overview?.niriMotionSamples ?? 2))
    readonly property real niriMotionSampleThreshold: {
        const value = Number(Config.options?.overview?.niriMotionSampleThreshold ?? 0.006)
        return Number.isFinite(value) ? Math.max(0.0005, Math.min(1, value)) : 0.006
    }
    readonly property real niriActivityPromotionThreshold: {
        const value = Number(Config.options?.overview?.niriActivityPromotionThreshold ?? 0.06)
        return Number.isFinite(value) ? Math.max(0.001, Math.min(1, value)) : 0.06
    }
    readonly property real niriMediaActivityPromotionThreshold: {
        const value = Number(Config.options?.overview?.niriMediaActivityPromotionThreshold ?? 0.02)
        return Number.isFinite(value) ? Math.max(0.001, Math.min(1, value)) : 0.02
    }
    readonly property real niriFocusedActivityPromotionThreshold: {
        const value = Number(Config.options?.overview?.niriFocusedActivityPromotionThreshold ?? 0.035)
        return Number.isFinite(value) ? Math.max(0.001, Math.min(1, value)) : 0.035
    }
    readonly property int niriStaticCooldownMs:
        Math.max(600, Math.min(10000, Config.options?.overview?.niriStaticCooldownMs ?? 2800))

    readonly property bool hyprlandLiveBackendAvailable: true
    readonly property bool niriLiveBackendAvailable:
        (Quickshell.env("INIR_NIRI_PREVIEW_PLUGIN") ?? "") === "1"

    property var _claims: ({})
    property int _nextOrder: 1
    property var liveKeys: []

    property var _probeCandidates: ({})
    property int _nextProbeOrder: 1
    property int _probeCursor: 0
    property var probeKeys: []
    readonly property int _probeCandidateCount: Object.keys(root._probeCandidates).length

    function wantsLive(active, backendAvailable, hovered, focused,
                       mediaPlaying, activityScore, requireActivityForHints,
                       activityThreshold, mediaThreshold, focusedThreshold): bool {
        return AdaptivePreviewPolicy.wantsLive({
            mode: root.mode,
            active: active,
            backendAvailable: backendAvailable,
            hovered: hovered,
            focused: focused,
            mediaPlaying: mediaPlaying,
            activityScore: activityScore,
            liveOnHover: root.liveOnHover,
            liveFocusedWindow: root.liveFocusedWindow,
            liveMediaWindows: root.liveMediaWindows,
            requireActivityForHints: !!requireActivityForHints,
            activityPromotionThreshold: activityThreshold === undefined
                ? root.activityPromotionThreshold : activityThreshold,
            mediaActivityPromotionThreshold: mediaThreshold,
            focusedActivityPromotionThreshold: focusedThreshold
        })
    }

    function priorityFor(hovered, focused, mediaPlaying, activityScore): int {
        return AdaptivePreviewPolicy.candidatePriority({
            hovered: hovered,
            focused: focused,
            mediaPlaying: mediaPlaying,
            activityScore: activityScore
        })
    }

    function setLiveClaim(key, requested, hovered, focused,
                          mediaPlaying, activityScore, pool): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0)
            return

        const previous = root._claims[normalizedKey]
        const next = Object.assign({}, root._claims)
        next[normalizedKey] = {
            key: normalizedKey,
            requested: !!requested,
            priority: root.priorityFor(hovered, focused, mediaPlaying, activityScore),
            order: previous?.order ?? root._nextOrder++,
            pool: String(pool ?? "default")
        }
        root._claims = next
        root._recomputeLive()
    }

    function removeLiveClaim(key): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0 || root._claims[normalizedKey] === undefined)
            return

        const next = Object.assign({}, root._claims)
        delete next[normalizedKey]
        root._claims = next
        root._recomputeLive()
    }

    function isLive(key): bool {
        const normalizedKey = String(key ?? "")
        return normalizedKey.length > 0 && root.liveKeys.indexOf(normalizedKey) >= 0
    }

    function _recomputeLive(): void {
        const rows = Object.keys(root._claims).map(key => root._claims[key])
        const standardRows = rows.filter(row => row.pool !== "niri")
        const niriRows = rows.filter(row => row.pool === "niri")
        const selected = AdaptivePreviewPolicy
            .selectLiveKeys(standardRows, root.maxLiveWindows)
            .concat(AdaptivePreviewPolicy.selectLiveKeys(niriRows, root.niriMaxLiveWindows))

        if (!(selected.length === root.liveKeys.length
                && selected.every((key, index) => key === root.liveKeys[index])))
            root.liveKeys = selected

        root._advanceProbeBatch()
    }

    function setProbeCandidate(key, active, priority): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0)
            return

        if (!active) {
            root.removeProbeCandidate(normalizedKey)
            return
        }

        const previous = root._probeCandidates[normalizedKey]
        const next = Object.assign({}, root._probeCandidates)
        next[normalizedKey] = {
            key: normalizedKey,
            active: true,
            priority: Math.max(0, Math.floor(Number(priority) || 0)),
            order: previous?.order ?? root._nextProbeOrder++
        }
        root._probeCandidates = next
        if (root.probeKeys.length === 0)
            root._advanceProbeBatch()
    }

    function removeProbeCandidate(key): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0
                || root._probeCandidates[normalizedKey] === undefined)
            return

        const next = Object.assign({}, root._probeCandidates)
        delete next[normalizedKey]
        root._probeCandidates = next
        if (root.probeKeys.indexOf(normalizedKey) >= 0)
            root._advanceProbeBatch()
    }

    function isProbeActive(key): bool {
        const normalizedKey = String(key ?? "")
        return normalizedKey.length > 0 && root.probeKeys.indexOf(normalizedKey) >= 0
    }

    function _advanceProbeBatch(): void {
        if (!root.niriLiveBackendAvailable || root._probeCandidateCount <= 0) {
            root.probeKeys = []
            return
        }

        const rows = Object.keys(root._probeCandidates)
            .map(key => root._probeCandidates[key])
            .filter(row => row?.active && !root.isLive(row.key))
        if (rows.length === 0) {
            root.probeKeys = []
            return
        }

        rows.sort((a, b) => {
            const orderDelta = Number(a.order ?? 0) - Number(b.order ?? 0)
            return orderDelta !== 0
                ? orderDelta : String(a.key).localeCompare(String(b.key))
        })

        const slots = Math.min(root.niriProbeSlots, rows.length)
        const selected = []

        // Reserve one probe slot for the most valuable dynamic hint (normally
        // playing media) while the remaining slots continue round-robin
        // discovery so generic animations are never starved.
        const urgent = rows.slice().sort((a, b) =>
            Number(b.priority ?? 0) - Number(a.priority ?? 0))
        if (urgent.length > 0 && Number(urgent[0].priority ?? 0) >= 5000)
            selected.push(String(urgent[0].key))

        const remaining = rows.filter(row => selected.indexOf(String(row.key)) < 0)
        if (remaining.length > 0 && selected.length < slots) {
            let cursor = root._probeCursor % remaining.length
            while (selected.length < slots) {
                const key = String(remaining[cursor].key)
                if (selected.indexOf(key) < 0)
                    selected.push(key)
                cursor = (cursor + 1) % remaining.length
                if (selected.length >= remaining.length + 1)
                    break
            }
            root._probeCursor = cursor
        }

        root.probeKeys = selected
    }

    Timer {
        id: niriProbeRotation
        interval: root.niriProbeWindowMs
        repeat: true
        running: root.niriLiveBackendAvailable && root._probeCandidateCount > 0
        onTriggered: root._advanceProbeBatch()
        onRunningChanged: {
            if (running)
                root._advanceProbeBatch()
            else
                root.probeKeys = []
        }
    }

    // Semantic dynamic-content hint. Browser players require a title match so
    // one playing tab does not promote every window from the same browser.
    function mediaPlayingForWindow(windowData, players): bool {
        if (!windowData)
            return false

        const normalized = value => String(value ?? "")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, " ")
            .trim()
        const app = normalized(windowData.app_id ?? windowData.appId
                               ?? windowData.class ?? windowData.initialClass ?? "")
        const title = normalized(windowData.title ?? "")
        const list = players ?? []

        for (const player of list) {
            if (!player?.isPlaying)
                continue

            const track = normalized(player.trackTitle ?? "")
            const hints = [
                player.desktopEntry,
                player.identity,
                String(player.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "")
            ].map(normalized).filter(value => value.length > 0)

            const titleMatch = track.length >= 4 && title.length >= 4
                && (title.includes(track) || track.includes(title))
            if (titleMatch)
                return true

            const browserPlayer = hints.some(value =>
                /(^| )(firefox|zen|chromium|chrome|brave|vivaldi|opera)( |$)/.test(value))
            if (browserPlayer && track.length >= 4)
                continue

            if (app.length > 0 && hints.some(value =>
                    app === value || app.includes(value) || value.includes(app)))
                return true
        }
        return false
    }

    onMaxLiveWindowsChanged: root._recomputeLive()
    onNiriMaxLiveWindowsChanged: root._recomputeLive()
    onNiriProbeSlotsChanged: root._advanceProbeBatch()
}
