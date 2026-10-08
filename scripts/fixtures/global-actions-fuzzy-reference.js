.pragma library
// Frozen pre-optimization query scorer; caller supplies the same catalog.
    function fuzzyQuery(query, allActions) {
        if (!query || query.trim() === "") return allActions
        const q = query.toLowerCase().trim()
        const scored = allActions.map(action => {
            let score = 0
            const name = (action.name ?? "").toLowerCase()
            const desc = (action.description ?? "").toLowerCase()
            const id = (action.id ?? "").toLowerCase()
            const kw = (action.keywords ?? []).join(" ").toLowerCase()
            // Exact id match
            if (id === q) score += 100
            // Starts with
            if (name.startsWith(q)) score += 60
            if (id.startsWith(q)) score += 50
            // Contains
            if (name.includes(q)) score += 30
            if (desc.includes(q)) score += 15
            if (id.includes(q)) score += 20
            if (kw.includes(q)) score += 10
            // Per-word matching for multi-word queries
            const words = q.split(/\s+/)
            if (words.length > 1) {
                const combined = `${name} ${desc} ${id} ${kw}`
                const matchCount = words.filter(w => combined.includes(w)).length
                score += matchCount * 8
            }
            return { action, score }
        }).filter(item => item.score > 0)
        scored.sort((a, b) => b.score - a.score)
        return scored.map(item => item.action)
    }
