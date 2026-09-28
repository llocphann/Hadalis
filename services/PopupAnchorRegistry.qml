pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "PopupAnchorPolicy.js" as AnchorPolicy

// Runtime-only registry of real on-screen source Items. It carries geometry/
// identity references only; authentication responses never enter this service.
Singleton {
    id: root

    property var entries: []
    signal anchorRemoved(var item)

    function _windowFor(item): var {
        if (!item)
            return null
        try {
            return item.QsWindow?.window ?? null
        } catch (e) {
            return null
        }
    }

    function _liquidAnchorFor(item): var {
        for (let ancestor = item; ancestor; ancestor = ancestor.parent) {
            if (ancestor.liquidController)
                return ancestor
        }
        return null
    }

    function _validItem(item): bool {
        const window = root._windowFor(item)
        // Registered sources are usable only when they already belong to an
        // Abyss connected surface. This prevents a still-visible Waffle/shared
        // tray instance from resolving and making StyledPopup fall back to a
        // detached native popup window.
        return item !== null && item !== undefined
            && item.visible && item.enabled
            && Number(item.width ?? 0) > 0
            && Number(item.height ?? 0) > 0
            && root._liquidAnchorFor(item) !== null
            && window !== null
            && window.screen !== null
            && window.screen !== undefined
    }

    function _aliases(entry): var {
        if (!entry)
            return []
        try {
            const values = typeof entry.aliasProvider === "function"
                ? entry.aliasProvider() : []
            return Array.isArray(values) ? values : []
        } catch (e) {
            return []
        }
    }

    function _sourceAliases(source): var {
        if (!source)
            return []
        // Only stable machine identities participate in implicit source
        // resolution. Human-facing names/titles are descriptive, localizable
        // and may collide; unresolved requests must use the safe fallback.
        return [
            source.appId,
            source.sourceAppId,
            source.sourceApp,
            source.desktopId,
            source.desktopEntry
        ].filter(value => String(value ?? "").trim().length > 0)
    }

    function registerAnchor(item, kind, aliasProvider, priority = -1): void {
        if (!item)
            return
        root.unregisterAnchor(item, false)
        const next = root.entries.slice()
        next.push({
            item: item,
            kind: String(kind ?? ""),
            aliasProvider: aliasProvider,
            priority: priority >= 0
                ? Number(priority)
                : AnchorPolicy.kindPriority(kind)
        })
        root.entries = next
    }

    function unregisterAnchor(item, notify = true): void {
        if (!item)
            return
        const old = root.entries
        const next = old.filter(entry => entry?.item !== item)
        if (next.length === old.length)
            return
        root.entries = next
        if (notify)
            root.anchorRemoved(item)
    }

    function resolve(source): var {
        const direct = source?.anchorItem ?? null
        if (root._validItem(direct)) {
            const window = root._windowFor(direct)
            return {
                item: direct,
                kind: String(source?.anchorKind ?? "direct"),
                outputName: String(window?.screen?.name ?? ""),
                score: Number.MAX_SAFE_INTEGER
            }
        }

        const wanted = root._sourceAliases(source)
        if (wanted.length === 0)
            return null

        let best = null
        let bestScore = 0
        for (const entry of root.entries) {
            if (!root._validItem(entry?.item))
                continue
            let identityScore = 0
            for (const candidate of wanted) {
                for (const alias of root._aliases(entry))
                    identityScore = Math.max(identityScore,
                        AnchorPolicy.matchScore(candidate, alias))
            }
            if (identityScore <= 0)
                continue
            const total = Number(entry.priority ?? 0) * 10000
                + identityScore
            if (total <= bestScore)
                continue
            const window = root._windowFor(entry.item)
            bestScore = total
            best = {
                item: entry.item,
                kind: entry.kind,
                outputName: String(window?.screen?.name ?? ""),
                score: total
            }
        }
        return best
    }
}
