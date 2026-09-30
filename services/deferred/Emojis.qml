pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/**
 * Emojis.
 */
Singleton {
    id: root
    property string emojiScriptPath: `${Directories.scriptsPath}/emoji/emoji-data.sh`
	property string lineBeforeData: "### DATA ###"
    property list<var> list

    // Properties for fuzzy search (matching Cliphist.qml pattern)
    property bool sloppySearch: Config.options?.search?.sloppy ?? false
    property real scoreThreshold: 0.2

    property int _listRevision: 0
    property int _preparedRevision: -1
    property var _preparedEntriesCache: []

    onListChanged: {
        root._listRevision++
        root._preparedRevision = -1
        root._preparedEntriesCache = []
    }

    function _ensurePreparedEntries(): var {
        if (root._preparedRevision === root._listRevision)
            return root._preparedEntriesCache

        const source = root.list
        const prepared = new Array(source.length)
        for (let i = 0; i < source.length; ++i) {
            const entry = source[i]
            prepared[i] = {
                name: Fuzzy.prepare(`${entry}`),
                entry: entry
            }
        }
        root._preparedEntriesCache = prepared
        root._preparedRevision = root._listRevision
        return prepared
    }

    function _insertTopScored(top, candidate, limit): void {
        let low = 0
        let high = top.length
        while (low < high) {
            const mid = (low + high) >> 1
            if (candidate.score > top[mid].score)
                high = mid
            else
                low = mid + 1
        }
        top.splice(low, 0, candidate)
        if (top.length > limit)
            top.pop()
    }

    function fuzzyQuery(search: string, limit): var {
        if (root.sloppySearch) {
            const searchLower = search.toLowerCase()
            const count = Math.min(100, root.list.length)
            if (limit > 0) {
                const top = []
                for (let i = 0; i < count; ++i) {
                    const entry = root.list[i]
                    const score = Levendist.computeTextMatchScore(
                        entry.toLowerCase(), searchLower)
                    if (score > root.scoreThreshold)
                        root._insertTopScored(top,
                            { entry: entry, score: score }, limit)
                }
                return top.map(item => item.entry)
            }

            const results = new Array(count)
            let resultCount = 0
            for (let i = 0; i < count; ++i) {
                const entry = root.list[i]
                const score = Levendist.computeTextMatchScore(
                    entry.toLowerCase(), searchLower)
                if (score > root.scoreThreshold)
                    results[resultCount++] = { entry: entry, score: score }
            }
            results.length = resultCount
            results.sort((a, b) => b.score - a.score)
            return results.map(item => item.entry)
        }

        const results = Fuzzy.go(search, root._ensurePreparedEntries(), {
            all: true,
            key: "name",
            limit: limit > 0 ? limit : undefined
        })
        return results.map(r => {
            return r.obj.entry
        });
    }

    function load() {
        emojiFileView.reload()
    }

    function updateEmojis(fileContent) {
        const lines = fileContent.split("\n")
        const dataIndex = lines.indexOf(root.lineBeforeData)
        if (dataIndex === -1) {
            console.warn("No data section found in emoji script file.")
            return
        }
        const emojis = lines.slice(dataIndex + 1).filter(line => line.trim() !== "")
        root.list = emojis.map(line => line.trim())
    }

    FileView { 
        id: emojiFileView
        path: Qt.resolvedUrl(root.emojiScriptPath)
        onLoadedChanged: {
            const fileContent = emojiFileView.text()
            root.updateEmojis(fileContent)
        }
    }
}
