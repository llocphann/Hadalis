// Pure compositor-state projection. No drag/preview state lives in these records.
function buildWindowItems(wins, workspaces, firstSlot, shown) {
    if (!Array.isArray(wins) || !Array.isArray(workspaces)
            || !wins.length || !workspaces.length || shown <= 0)
        return []
    const slots = {}
    workspaces.forEach((ws, i) => { if (ws) slots[ws.id] = i })
    const end = Math.min(firstSlot + shown - 1, workspaces.length - 1)
    const collected = [], count = {}, max = {}, seen = new Set()
    for (const window of wins) {
        if (!window || seen.has(window.id)) continue
        const slot = slots[window.workspace_id]
        if (slot === undefined || slot < firstSlot || slot > end) continue
        seen.add(window.id)
        const pos = window.layout?.pos_in_scrolling_layout ?? [1, 1]
        const grid = max[slot] ?? {maxCol: 1, maxRow: 1}
        grid.maxCol = Math.max(grid.maxCol, pos[0] || 1)
        grid.maxRow = Math.max(grid.maxRow, pos[1] || 1)
        max[slot] = grid
        count[slot] = (count[slot] || 0) + 1
        collected.push({window: window, slot: slot})
    }
    const index = {}
    return collected.map(entry => {
        const slot = entry.slot, ordinal = index[slot] || 0
        index[slot] = ordinal + 1
        return {
            id: entry.window.id, window: entry.window,
            workspaceNumber: slot + 1, workspaceSlot: slot,
            indexInWorkspace: ordinal, windowCount: count[slot],
            maxCol: max[slot].maxCol, maxRow: max[slot].maxRow
        }
    })
}

// The model exposes only stable primitive IDs. Delegates resolve the latest
// record by ID; a reordered/rebuilt record cannot transfer another app's icon.
function findWindowRecord(records, windowId) {
    return records.find(record => record.id === windowId) ?? null
}
