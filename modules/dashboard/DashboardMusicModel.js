.pragma library

function folder(value) {
    return String(value ?? "").replace(/^\/+|\/+$/g, "")
}

function trackFolder(track) {
    if (track?.folder !== undefined) return folder(track.folder)
    const uri = String(track?.uri ?? "")
    return folder(uri.substring(0, Math.max(0, uri.lastIndexOf("/"))))
}

function labels(track) {
    const raw = Array.isArray(track?.genre) ? track.genre : [track?.genre ?? ""]
    const values = new Set()
    for (const value of raw) for (const token of String(value).split(";")) {
        const label = token.trim()
        if (label.length > 0) values.add(label)
    }
    return values.size > 0 ? Array.from(values) : [""]
}

function genres(tracks) {
    const values = new Map()
    for (const track of tracks ?? []) {
        if (!track) continue
        for (const label of labels(track)) values.set(label, (values.get(label) ?? 0) + 1)
    }
    return Array.from(values, ([key, count]) => ({key, count}))
        .sort((a, b) => a.key.localeCompare(b.key))
}

function contents(tracks, path) {
    const current = folder(path), prefix = current ? current + "/" : ""
    const children = new Map(), files = []
    for (const track of tracks ?? []) {
        if (!track) continue
        const parent = trackFolder(track)
        if (parent === current) {
            files.push({kind: "track", track, name: String(track.title || track.uri || "")})
            continue
        }
        if (current && !parent.startsWith(prefix)) continue
        const rest = parent.substring(prefix.length), name = rest.split("/")[0]
        if (!name) continue
        const child = prefix + name
        if (!children.has(child)) children.set(child, {kind: "folder", name, path: child, count: 0})
        children.get(child).count++
    }
    return Array.from(children.values()).sort((a, b) => a.name.localeCompare(b.name)).concat(files)
}

function roots(tracks) {
    const entries = contents(tracks, "")
    const directories = entries.filter(entry => entry.kind === "folder")
    if (entries.some(entry => entry.kind === "track"))
        directories.unshift({kind: "folder", name: "Music library", path: "", count: entries.filter(entry => entry.kind === "track").length})
    return directories
}

function results(tracks, mode, genre, path) {
    if (mode === "genre") {
        const selected = new Set(Array.isArray(genre) ? genre : [genre])
        return (tracks ?? []).filter(track => track && labels(track).some(label => selected.has(label)))
            .map(track => ({kind: "track", track, name: String(track.title || track.uri || "")}))
    }
    if (mode !== "folder") return []
    if (!Array.isArray(path)) return contents(tracks, path)
    const entries = new Map()
    for (const current of path) for (const entry of contents(tracks, current))
        if (!entries.has(key(entry))) entries.set(key(entry), entry)
    return Array.from(entries.values())
}

function parent(path) {
    const value = folder(path)
    return value.substring(0, Math.max(0, value.lastIndexOf("/")))
}

function matching(tracks, query) {
    const text=String(query ?? "").trim().toLowerCase()
    if (!text) return tracks ?? []
    return (tracks ?? []).filter(track => track &&
        [track.title,track.artist,track.album,track.folder].map(value=>String(value ?? "").toLowerCase()).join(" ").includes(text))
}

function key(entry) {
    return entry.kind === "folder" ? "d:"+entry.path : "t:"+String(entry.track?.uri ?? entry.track?.path ?? "")
}

function select(entries, selected, anchor, index, control, shift) {
    const entry=entries[index]
    if (!entry) return {keys:selected,anchor}
    if (shift && anchor>=0) {
        const keys=new Set(control ? selected : [])
        for (const value of entries.slice(Math.min(anchor,index),Math.max(anchor,index)+1)) keys.add(key(value))
        return {keys:Array.from(keys),anchor}
    }
    const keys=new Set(control ? selected : []), value=key(entry)
    if(control && keys.has(value)) keys.delete(value)
    else keys.add(value)
    return {keys:Array.from(keys),anchor:index}
}

// Genre names and folder paths include the empty string (unknown/root).
function selectValues(values, selected, anchor, index, control, shift) {
    if (index < 0 || index >= values.length) return {keys:selected, anchor}
    if (shift && anchor >= 0 && anchor < values.length) {
        const keys = new Set(control ? selected : [])
        for (const value of values.slice(Math.min(anchor,index), Math.max(anchor,index)+1)) keys.add(value)
        return {keys:Array.from(keys), anchor}
    }
    const keys = new Set(control ? selected : []), value = values[index]
    if (control && keys.has(value)) keys.delete(value)
    else keys.add(value)
    return {keys:Array.from(keys), anchor:index}
}

function selectedTracks(tracks, keys) {
    const selected=new Set(keys), folders=keys.filter(value=>value.startsWith("d:")).map(value=>value.substring(2))
    const seen=new Set()
    return (tracks ?? []).filter(track => {
        if (!track) return false
        const uri=String(track.uri ?? track.path ?? ""), path=trackFolder(track)
        if (seen.has(uri) || !(selected.has("t:"+uri) || folders.some(value=>path===value || path.startsWith(value+"/")))) return false
        seen.add(uri)
        return true
    })
}
