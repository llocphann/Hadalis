pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import "AdaptivePreviewPolicy.js" as AdaptivePreviewPolicy

// Shared budget/capability boundary for Overview window previews.
//
// A "live claim" never starts capture by itself. Renderers publish claims only
// when they have a real compositor-native toplevel capture backend. This keeps
// Niri on the existing snapshot cache until Quickshell exposes Niri toplevel
// image-copy-capture instead of emulating live video with screenshot polling.
Singleton {
    id: root

    readonly property string mode:
        AdaptivePreviewPolicy.normalizeMode(Config.options?.overview?.previewMode ?? "adaptive")
    readonly property int maxLiveWindows:
        AdaptivePreviewPolicy.boundedLiveLimit(Config.options?.overview?.maxLiveWindows ?? 6, 6)
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

    // Stock Quickshell currently accepts a Toplevel ScreencopyView source via
    // hyprland-toplevel-export-v1. Niri supports image-copy-capture itself, but
    // Quickshell does not yet expose Niri toplevels as ScreencopyView sources.
    readonly property bool hyprlandLiveBackendAvailable: true
    readonly property bool niriLiveBackendAvailable: false

    property var _claims: ({})
    property int _nextOrder: 1
    property var liveKeys: []

    function wantsLive(active, backendAvailable, hovered, focused,
                       mediaPlaying, activityScore): bool {
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
            activityPromotionThreshold: root.activityPromotionThreshold
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
                          mediaPlaying, activityScore): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0)
            return

        const previous = root._claims[normalizedKey]
        const next = Object.assign({}, root._claims)
        next[normalizedKey] = {
            key: normalizedKey,
            requested: !!requested,
            priority: root.priorityFor(hovered, focused, mediaPlaying, activityScore),
            order: previous?.order ?? root._nextOrder++
        }
        root._claims = next
        root._recompute()
    }

    function removeLiveClaim(key): void {
        const normalizedKey = String(key ?? "")
        if (normalizedKey.length === 0 || root._claims[normalizedKey] === undefined)
            return

        const next = Object.assign({}, root._claims)
        delete next[normalizedKey]
        root._claims = next
        root._recompute()
    }

    function isLive(key): bool {
        const normalizedKey = String(key ?? "")
        const keys = root.liveKeys
        return normalizedKey.length > 0 && keys.indexOf(normalizedKey) >= 0
    }

    function _recompute(): void {
        const rows = Object.keys(root._claims).map(key => root._claims[key])
        const selected = AdaptivePreviewPolicy.selectLiveKeys(rows, root.maxLiveWindows)
        if (selected.length === root.liveKeys.length
                && selected.every((key, index) => key === root.liveKeys[index]))
            return
        root.liveKeys = selected
    }

    // Semantic dynamic-content hint. It deliberately errs toward snapshot for
    // ambiguous browser windows: when MPRIS exposes a track title, a browser
    // window must match that title instead of promoting every browser window.
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

    onMaxLiveWindowsChanged: root._recompute()
}
