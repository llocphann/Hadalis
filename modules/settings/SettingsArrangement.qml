pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    readonly property int layoutSchemaVersion: 7
    readonly property int retiredTlpPageIndex: 28
    readonly property int overviewPageIndex: 29
    readonly property int codeWorkflowPageIndex: 30

    function snapshot(): var {
        return ({
            groups: SettingsPageRegistry.categories.map(c => ({
                label: c.label,
                pages: c.pages.slice()
            })),
            hidden: SettingsPageRegistry.hiddenPages.slice()
        })
    }

    function save(snapshot): void {
        // The internal data registry still has the historical page 28 so its
        // existing arrangement sanitizer remains reusable. Persist 28 as an
        // implementation-only hidden index to stop it being re-added as a
        // missing "More" page. The public registry facade filters it out, so
        // users never see it in navigation or Arrange.
        const hidden = (Array.isArray(snapshot.hidden) ? snapshot.hidden : [])
            .filter(index => index !== root.retiredTlpPageIndex)
        hidden.push(root.retiredTlpPageIndex)

        Config.setNestedValue("settingsUi.categories", JSON.stringify({
            version: root.layoutSchemaVersion,
            groups: snapshot.groups,
            hidden: hidden
        }))
    }

    function migrateLegacyPageIndices(): void {
        // SettingsPageHost also calls this during Component.onCompleted, before
        // Config can be ready. Never turn that early empty state into a write.
        if (!Config.ready)
            return

        const raw = Config.options?.settingsUi?.categories ?? ""
        if (typeof raw !== "string" || raw.length === 0)
            return

        let saved
        try {
            saved = JSON.parse(raw)
        } catch (e) {
            return
        }

        const sourceVersion = Array.isArray(saved) ? 1 : Number(saved?.version ?? 2)
        if (!Array.isArray(saved) && sourceVersion >= root.layoutSchemaVersion)
            return

        const groups = Array.isArray(saved)
            ? saved
            : (Array.isArray(saved?.groups) ? saved.groups : null)
        if (!groups)
            return

        const hidden = Array.isArray(saved?.hidden) ? saved.hidden : []
        let hasLegacyTlpIndex = false
        let hasCurrentTlpIndex = false
        const inspectIndex = index => {
            if (index === 27)
                hasLegacyTlpIndex = true
            else if (index === root.retiredTlpPageIndex)
                hasCurrentTlpIndex = true
        }

        for (const group of groups) {
            if (!group || !Array.isArray(group.pages))
                continue
            group.pages.forEach(inspectIndex)
        }
        hidden.forEach(inspectIndex)

        // Before Orbit existed, fork layouts could use 27 for the standalone
        // Battery/TLP page. In those pre-v3 layouts, 27 with no 28 is the old
        // TLP page. Drop it; SettingsPageRegistryData will then surface the new
        // Orbit page as a missing page, while the public registry filters only
        // the retired TLP page 28.
        const dropPreOrbitTlp = sourceVersion < 3
            && hasLegacyTlpIndex && !hasCurrentTlpIndex
        const keepPage = index => index !== root.retiredTlpPageIndex
            && !(dropPreOrbitTlp && index === 27)

        const migratedGroups = groups.map(group => {
            if (!group || typeof group.label !== "string")
                return group
            return ({
                label: group.label,
                pages: (Array.isArray(group.pages) ? group.pages : []).filter(keepPage)
            })
        })
        const migratedHidden = hidden.filter(keepPage)

        // v5 gives Overview a first-class Shell home. v4 could only discover
        // the newly appended page as “More”, so remove that generated placement
        // and insert it into whichever saved group best matches the default Shell
        // peers. This also survives renamed/custom Shell group labels.
        if (sourceVersion < 5
                && !migratedHidden.includes(root.overviewPageIndex)) {
            for (const group of migratedGroups) {
                if (!group || !Array.isArray(group.pages))
                    continue
                group.pages = group.pages.filter(
                    index => index !== root.overviewPageIndex)
            }

            const defaultShell = SettingsPageRegistry.defaultCategories.find(
                category => category.pages.includes(root.overviewPageIndex))
            const shellPeers = defaultShell?.pages?.filter(
                index => index !== root.overviewPageIndex) ?? [2, 26, 5, 22, 23, 16]
            let targetIndex = -1
            let bestScore = -1
            for (let i = 0; i < migratedGroups.length; i++) {
                const pages = migratedGroups[i]?.pages ?? []
                let score = 0
                for (const peer of shellPeers)
                    if (pages.includes(peer))
                        score++
                if (score > bestScore) {
                    bestScore = score
                    targetIndex = i
                }
            }

            if (targetIndex >= 0) {
                const pages = migratedGroups[targetIndex].pages
                const panelsIndex = pages.indexOf(5)
                pages.splice(panelsIndex >= 0 ? panelsIndex + 1 : pages.length,
                    0, root.overviewPageIndex)
            }
        }

        // v6 appends Code Workflow without shifting historical indices.
        // Saved layouts would otherwise discover page 30 under a generated More
        // group. Find the group that already owns the Reference peers and insert
        // Code Workflow before them.
        if (sourceVersion < 6
                && !migratedHidden.includes(root.codeWorkflowPageIndex)) {
            for (const group of migratedGroups) {
                if (!group || !Array.isArray(group.pages))
                    continue
                group.pages = group.pages.filter(
                    index => index !== root.codeWorkflowPageIndex)
            }

            const defaults = SettingsPageRegistry.defaultCategories.find(
                category => category.pages.includes(root.codeWorkflowPageIndex))
            const peers = defaults?.pages?.filter(
                index => index !== root.codeWorkflowPageIndex) ?? [9, 13]

            let targetIndex = -1
            let bestScore = -1
            for (let i = 0; i < migratedGroups.length; i++) {
                const pages = migratedGroups[i]?.pages ?? []
                let score = 0
                for (const peer of peers)
                    if (pages.includes(peer))
                        score++
                if (score > bestScore) {
                    bestScore = score
                    targetIndex = i
                }
            }

            if (targetIndex >= 0) {
                const pages = migratedGroups[targetIndex].pages
                let insertIndex = pages.length
                for (const peer of peers) {
                    const peerIndex = pages.indexOf(peer)
                    if (peerIndex >= 0)
                        insertIndex = Math.min(insertIndex, peerIndex)
                }
                pages.splice(insertIndex, 0, root.codeWorkflowPageIndex)
            }
        }

        // Old stock navigation should adopt the six intent-based groups.
        // Compare only page order: translated labels can differ by locale.
        // Explicitly rearranged/hidden pages and renamed groups are preserved.
        const previousStock = [
            [0],
            [4, 25, 3, 14],
            [2, 26, 5, 29, 22, 23, 16, 10, 11, 20],
            [1, 24, 7, 6, 12, 15, 8, 17],
            [30, 9, 13]
        ]
        const stockPages = previousStock.every((pages, index) => {
            const actual = migratedGroups[index]?.pages ?? []
            const visibleStock = pages.filter(page => !migratedHidden.includes(page))
            return actual.length === visibleStock.length
                && actual.every((page, offset) => page === visibleStock[offset])
        })
        const stockLabels = [
            Translation.tr("Essentials"), Translation.tr("Appearance"),
            Translation.tr("Shell"), Translation.tr("System"),
            Translation.tr("Reference")
        ]
        const stockGroupNames = migratedGroups.every((group, index) =>
            group?.label === stockLabels[index])
        const untouchedStock = migratedGroups.length === previousStock.length
            && stockPages && stockGroupNames
            && migratedHidden.every(page => page === root.retiredTlpPageIndex)

        if (sourceVersion < 7 && untouchedStock) {
            root.save({
                groups: SettingsPageRegistry.defaultCategories.map(group => ({
                    label: group.label, pages: group.pages.slice()
                })),
                hidden: migratedHidden
            })
            return
        }

        root.save({ groups: migratedGroups, hidden: migratedHidden })
    }

    function removePage(snapshot, categoryIndex: int, pageIndex: int, pageIdx: int): int {
        if (categoryIndex === -1) {
            const hiddenIndex = snapshot.hidden.indexOf(pageIdx)
            if (hiddenIndex < 0)
                return -1
            snapshot.hidden.splice(hiddenIndex, 1)
            return pageIdx
        }

        const pages = snapshot.groups[categoryIndex]?.pages
        if (!pages)
            return -1
        let actual = pageIndex
        if (actual < 0 || actual >= pages.length || pages[actual] !== pageIdx)
            actual = pages.indexOf(pageIdx)
        if (actual < 0)
            return -1
        return pages.splice(actual, 1)[0]
    }

    function movePage(sourceCategory: int, sourceIndex: int, pageIdx: int,
                      targetCategory: int, targetIndex: int): bool {
        if (!SettingsPageRegistry.categories[targetCategory])
            return false

        const state = root.snapshot()
        const page = root.removePage(state, sourceCategory, sourceIndex, pageIdx)
        if (page < 0)
            return false

        const target = state.groups[targetCategory]?.pages
        if (!target)
            return false
        target.splice(Math.max(0, Math.min(targetIndex, target.length)), 0, page)
        root.save(state)
        return true
    }

    function hidePage(categoryIndex: int, pageIndex: int, pageIdx: int): bool {
        if (categoryIndex < 0)
            return false
        const state = root.snapshot()
        const page = root.removePage(state, categoryIndex, pageIndex, pageIdx)
        if (page < 0)
            return false
        if (!state.hidden.includes(page))
            state.hidden.push(page)
        root.save(state)
        return true
    }

    function bestRestoreCategory(pageIdx: int, groups): int {
        const defaults = SettingsPageRegistry.defaultCategories
        let peers = []
        for (let i = 0; i < defaults.length; i++) {
            if (defaults[i].pages.includes(pageIdx)) {
                peers = defaults[i].pages
                break
            }
        }

        let bestIndex = groups.length > 0 ? 0 : -1
        let bestScore = -1
        for (let i = 0; i < groups.length; i++) {
            let score = 0
            for (let j = 0; j < groups[i].pages.length; j++)
                if (peers.includes(groups[i].pages[j]))
                    score++
            if (score > bestScore) {
                bestScore = score
                bestIndex = i
            }
        }
        return bestIndex
    }

    function restorePage(pageIdx: int): bool {
        const state = root.snapshot()
        const hiddenIndex = state.hidden.indexOf(pageIdx)
        if (hiddenIndex < 0)
            return false
        state.hidden.splice(hiddenIndex, 1)
        const target = root.bestRestoreCategory(pageIdx, state.groups)
        if (target < 0)
            state.groups.push({ label: Translation.tr("Essentials"), pages: [pageIdx] })
        else
            state.groups[target].pages.push(pageIdx)
        root.save(state)
        return true
    }

    function moveGroup(sourceIndex: int, insertIndex: int): bool {
        const state = root.snapshot()
        if (!state.groups[sourceIndex])
            return false
        const group = state.groups.splice(sourceIndex, 1)[0]
        let target = insertIndex
        if (insertIndex > sourceIndex)
            target--
        state.groups.splice(Math.max(0, Math.min(target, state.groups.length)), 0, group)
        root.save(state)
        return true
    }

    function renameCategory(index: int, label: string): bool {
        const trimmed = label.trim()
        if (trimmed.length === 0)
            return false
        const state = root.snapshot()
        if (!state.groups[index])
            return false
        state.groups[index].label = trimmed
        root.save(state)
        return true
    }

    function removeCategory(index: int): bool {
        const state = root.snapshot()
        if (state.groups.length <= 1 || !state.groups[index]
                || state.groups[index].pages.length > 0)
            return false
        state.groups.splice(index, 1)
        root.save(state)
        return true
    }

    function addCategory(): void {
        const state = root.snapshot()
        state.groups.push({ label: Translation.tr("New group"), pages: [] })
        root.save(state)
    }

    function reset(): void {
        Config.setNestedValue("settingsUi.categories", "")
    }
}
