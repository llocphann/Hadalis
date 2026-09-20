pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    clip: true

    property bool editMode: false
    property bool presentationActive: true
    signal requestEventsDialog(var event)

    readonly property int gridSize: Math.max(8,
        Number(Config.options?.dashboard?.canvas?.gridSize ?? 24))
    readonly property bool snapEnabled:
        Config.options?.dashboard?.canvas?.snap ?? true
    readonly property bool autoAdjustSizeEnabled:
        Config.options?.dashboard?.canvas?.autoAdjustSize ?? true
    readonly property string gridStyle:
        Config.options?.dashboard?.canvas?.gridStyle ?? "dots"

    readonly property var _catalog: ({
        welcome:       { icon: "waving_hand",       label: Translation.tr("Welcome") },
        clock:         { icon: "schedule",          label: Translation.tr("Clock") },
        system:        { icon: "monitoring",        label: Translation.tr("System usage") },
        github:        { icon: "deployed_code",     label: Translation.tr("GitHub activity") },
        notifications: { icon: "notifications",     label: Translation.tr("Notifications") },
        todo:          { icon: "checklist",         label: Translation.tr("To Do") },
        media:          { icon: "music_note",        label: Translation.tr("Media player") },
        weather:        { icon: "partly_cloudy_day", label: Translation.tr("Weather") },
        calendar:       { icon: "calendar_month",    label: Translation.tr("Calendar") },
        agenda:         { icon: "event_upcoming",    label: Translation.tr("Agenda") },
        notes:          { icon: "edit_note",         label: Translation.tr("Notes") }
    })
    readonly property var _allIds: [
        "welcome", "clock", "system", "github", "notifications",
        "todo", "media", "weather", "calendar", "agenda", "notes"
    ]
    readonly property var _defaultGeometry: ({
        welcome:       { x: 0.00, y: 0.00, w: 0.30, h: 0.18, visible: true },
        clock:         { x: 0.00, y: 0.19, w: 0.30, h: 0.14, visible: true },
        system:        { x: 0.00, y: 0.34, w: 0.30, h: 0.17, visible: true },
        github:        { x: 0.00, y: 0.52, w: 0.30, h: 0.12, visible: true },
        notifications: { x: 0.31, y: 0.00, w: 0.35, h: 0.25, visible: true },
        agenda:         { x: 0.31, y: 0.26, w: 0.35, h: 0.13, visible: true },
        todo:           { x: 0.31, y: 0.40, w: 0.35, h: 0.24, visible: true },
        media:          { x: 0.67, y: 0.00, w: 0.33, h: 0.62, visible: true },
        weather:        { x: 0.67, y: 0.64, w: 0.33, h: 0.36, visible: true },
        calendar:       { x: 0.00, y: 0.65, w: 0.66, h: 0.35, visible: true },
        notes:          { x: 0.67, y: 0.77, w: 0.33, h: 0.23, visible: false }
    })

    readonly property var _widgetMap: ({
        welcome: welcomeComponent,
        clock: clockComponent,
        weather: weatherComponent,
        calendar: calendarComponent,
        media: mediaComponent,
        notifications: notificationsComponent,
        todo: todoComponent,
        system: systemComponent,
        github: githubComponent,
        agenda: agendaComponent,
        notes: notesComponent
    })

    property string selectedId: ""
    property var _preview: ({})
    property var _interaction: null
    property var _smartGuides: []
    property var _smartSnapAxes: ({ x: false, y: false })

    function _icon(id) {
        return root._catalog[id]?.icon ?? "widgets"
    }

    function _label(id) {
        return root._catalog[id]?.label ?? id
    }

    function _defaultEntry(id) {
        const g = root._defaultGeometry[id] ?? {
            x: 0.10, y: 0.10, w: 0.30, h: 0.24, visible: false
        }
        return {
            id: id,
            x: Number(g.x),
            y: Number(g.y),
            w: Number(g.w),
            h: Number(g.h),
            visible: g.visible !== false
        }
    }

    function defaultEntries() {
        const result = []
        for (const id of root._allIds)
            result.push(root._defaultEntry(id))
        return result
    }

    function _storedEntries() {
        Config.revision
        return Config.options?.dashboard?.canvas?.widgets ?? []
    }

    function _entryFor(id) {
        const stored = root._storedEntries()
        for (let i = 0; i < stored.length; ++i) {
            const entry = stored[i]
            if (String(entry?.id ?? "") === id) {
                return {
                    id: id,
                    x: Number(entry?.x ?? root._defaultEntry(id).x),
                    y: Number(entry?.y ?? root._defaultEntry(id).y),
                    w: Number(entry?.w ?? root._defaultEntry(id).w),
                    h: Number(entry?.h ?? root._defaultEntry(id).h),
                    visible: entry?.visible !== false
                }
            }
        }
        return root._defaultEntry(id)
    }

    function geometryFor(id) {
        const preview = root._preview[id]
        return preview ?? root._entryFor(id)
    }

    // Visibility is persisted state, not interaction-preview state. Keeping
    // these lists independent from _preview prevents Repeater/model churn on
    // every pointer frame while a module is moving or resizing.
    readonly property var visibleIds: root._allIds.filter(id =>
        root._entryFor(id).visible !== false)
    readonly property var hiddenIds: root._allIds.filter(id =>
        root._entryFor(id).visible === false)

    function _entriesForWrite() {
        const stored = root._storedEntries()
        const source = stored.length > 0 ? stored : root.defaultEntries()
        const result = []
        for (let i = 0; i < source.length; ++i) {
            const entry = source[i]
            result.push({
                id: String(entry?.id ?? ""),
                x: Number(entry?.x ?? 0),
                y: Number(entry?.y ?? 0),
                w: Number(entry?.w ?? 0.3),
                h: Number(entry?.h ?? 0.2),
                visible: entry?.visible !== false
            })
        }
        return result
    }

    function _persistPatch(id, patch) {
        const entries = root._entriesForWrite()
        let found = false
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].id !== id)
                continue
            entries[i] = Object.assign({}, entries[i], patch)
            found = true
            break
        }
        if (!found)
            entries.push(Object.assign({}, root._defaultEntry(id), patch))
        Config.setNestedValue("dashboard.canvas.widgets", entries)
    }

    function setWidgetVisible(id, visible) {
        if (!visible) {
            root._persistPatch(id, { visible: false })
            if (root.selectedId === id)
                root.selectedId = ""
            return
        }

        // A restored widget must join the same collision contract as drag/resize.
        // Find the nearest free placement before making it visible so "Add"
        // cannot reintroduce an overlap from stale saved geometry.
        const obstacles = []
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const otherId = String(root.visibleIds[i])
            if (otherId === id)
                continue
            obstacles.push(root._rectPixels(otherId))
        }
        const base = root._rectPixelsForGeometry(id, root._entryFor(id))
        const resolved = root._resolveNeighbour(
            base, id, obstacles, false)
        let blocked = false
        for (let i = 0; i < obstacles.length; ++i) {
            if (root._rectsOverlap(resolved, obstacles[i],
                    root.collisionGap)) {
                blocked = true
                break
            }
        }
        if (blocked)
            return

        const g = root._normalizedRect(resolved, true)
        root._persistPatch(id, {
            x: g.x, y: g.y, w: g.w, h: g.h, visible: true
        })
    }

    function resetLayout() {
        root._preview = ({})
        root._interaction = null
        root.selectedId = ""
        Config.setNestedValue("dashboard.canvas.widgets", root.defaultEntries())
    }

    function _minimumSize(id) {
        switch (id) {
        case "media": return { width: 320, height: 390 }
        case "weather": return { width: 280, height: 180 }
        case "calendar": return { width: 300, height: 210 }
        case "todo": return { width: 260, height: 140 }
        case "notifications": return { width: 260, height: 130 }
        case "notes": return { width: 240, height: 160 }
        case "agenda": return { width: 240, height: 75 }
        case "system": return { width: 260, height: 180 }
        default: return { width: 200, height: 80 }
        }
    }

    function _rectPixelsForGeometry(id, g) {
        const min = root._minimumSize(id)
        const minW = Math.min(canvas.width, min.width)
        const minH = Math.min(canvas.height, min.height)
        const w = Math.max(minW, Math.min(canvas.width,
            Number(g.w) * canvas.width))
        const h = Math.max(minH, Math.min(canvas.height,
            Number(g.h) * canvas.height))
        const x = Math.max(0, Math.min(canvas.width - w,
            Number(g.x) * canvas.width))
        const y = Math.max(0, Math.min(canvas.height - h,
            Number(g.y) * canvas.height))
        return { x: x, y: y, width: w, height: h }
    }

    function _rectPixels(id) {
        return root._rectPixelsForGeometry(id, root.geometryFor(id))
    }

    function _normalizedRect(px, visible) {
        const cw = Math.max(1, canvas.width)
        const ch = Math.max(1, canvas.height)
        return {
            x: Math.max(0, Math.min(1, px.x / cw)),
            y: Math.max(0, Math.min(1, px.y / ch)),
            w: Math.max(0, Math.min(1, px.width / cw)),
            h: Math.max(0, Math.min(1, px.height / ch)),
            visible: visible !== false
        }
    }

    function _setPreview(id, px) {
        const next = Object.assign({}, root._preview)
        const current = root.geometryFor(id)
        next[id] = root._normalizedRect(px, current.visible)
        root._preview = next
    }

    function _clearPreview(id) {
        if (root._preview[id] === undefined)
            return
        const next = Object.assign({}, root._preview)
        delete next[id]
        root._preview = next
    }

    function _snap(value) {
        if (!root.snapEnabled)
            return value
        return Math.round(value / root.gridSize) * root.gridSize
    }

    function _snapRectForCommit(id, rect, kind, edge, lockX, lockY) {
        if (!root.snapEnabled)
            return root._fitRectToCanvas(
                rect, root._minimumSizeForCanvas(id))

        const min = root._minimumSizeForCanvas(id)
        if (kind === "move") {
            return root._fitRectToCanvas({
                x: lockX ? rect.x : root._snap(rect.x),
                y: lockY ? rect.y : root._snap(rect.y),
                width: rect.width,
                height: rect.height
            }, min)
        }

        let left = rect.x
        let top = rect.y
        let right = rect.x + rect.width
        let bottom = rect.y + rect.height
        const resizeEdge = String(edge ?? "")

        if (resizeEdge.indexOf("w") >= 0 && !lockX)
            left = root._snap(left)
        if (resizeEdge.indexOf("e") >= 0 && !lockX)
            right = root._snap(right)
        if (resizeEdge.indexOf("n") >= 0 && !lockY)
            top = root._snap(top)
        if (resizeEdge.indexOf("s") >= 0 && !lockY)
            bottom = root._snap(bottom)

        left = Math.max(0, Math.min(left, right - min.width))
        right = Math.min(canvas.width, Math.max(right, left + min.width))
        top = Math.max(0, Math.min(top, bottom - min.height))
        bottom = Math.min(canvas.height, Math.max(bottom, top + min.height))

        return root._fitRectToCanvas({
            x: left,
            y: top,
            width: Math.max(1, right - left),
            height: Math.max(1, bottom - top)
        }, min)
    }

    // Material cards always keep a visible gutter even on fine grids.
    readonly property real collisionGap: Math.max(8,
        Math.min(16, Math.round(root.gridSize / 3)))
    readonly property real smartGuideThreshold: Math.max(5,
        Math.min(9, root.gridSize / 4))

    function _cloneRect(rect) {
        return {
            x: Number(rect?.x ?? 0),
            y: Number(rect?.y ?? 0),
            width: Number(rect?.width ?? 1),
            height: Number(rect?.height ?? 1)
        }
    }

    function _minimumSizeForCanvas(id) {
        const requested = root._minimumSize(id)
        return {
            width: Math.min(canvas.width, requested.width),
            height: Math.min(canvas.height, requested.height)
        }
    }

    function _fitRectToCanvas(rect, min) {
        const width = Math.max(min.width,
            Math.min(canvas.width, Number(rect.width)))
        const height = Math.max(min.height,
            Math.min(canvas.height, Number(rect.height)))
        return {
            x: Math.max(0, Math.min(canvas.width - width, Number(rect.x))),
            y: Math.max(0, Math.min(canvas.height - height, Number(rect.y))),
            width: width,
            height: height
        }
    }

    function _otherRects(activeId, baselineRects) {
        const result = []
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const id = String(root.visibleIds[i])
            if (id === activeId)
                continue
            const rect = baselineRects[id] ?? root._rectPixels(id)
            result.push({ id: id, rect: rect })
        }
        return result
    }

    function _smartAlignMove(activeId, sourceRect, baselineRects) {
        const rect = root._cloneRect(sourceRect)
        const threshold = root.smartGuideThreshold
        const others = root._otherRects(activeId, baselineRects)
        const guides = []

        let bestX = null
        let bestY = null
        const activeXs = [
            rect.x,
            rect.x + rect.width / 2,
            rect.x + rect.width
        ]
        const activeYs = [
            rect.y,
            rect.y + rect.height / 2,
            rect.y + rect.height
        ]

        for (let i = 0; i < others.length; ++i) {
            const other = others[i].rect
            const otherXs = [
                other.x,
                other.x + other.width / 2,
                other.x + other.width
            ]
            const otherYs = [
                other.y,
                other.y + other.height / 2,
                other.y + other.height
            ]

            for (let ai = 0; ai < activeXs.length; ++ai) {
                for (let oi = 0; oi < otherXs.length; ++oi) {
                    const delta = otherXs[oi] - activeXs[ai]
                    const distance = Math.abs(delta)
                    if (distance <= threshold
                            && (!bestX || distance < bestX.distance)) {
                        bestX = {
                            distance: distance,
                            delta: delta,
                            pos: otherXs[oi],
                            other: other
                        }
                    }
                }
            }

            for (let ai = 0; ai < activeYs.length; ++ai) {
                for (let oi = 0; oi < otherYs.length; ++oi) {
                    const delta = otherYs[oi] - activeYs[ai]
                    const distance = Math.abs(delta)
                    if (distance <= threshold
                            && (!bestY || distance < bestY.distance)) {
                        bestY = {
                            distance: distance,
                            delta: delta,
                            pos: otherYs[oi],
                            other: other
                        }
                    }
                }
            }
        }

        if (bestX)
            rect.x += bestX.delta
        if (bestY)
            rect.y += bestY.delta

        const fitted = root._fitRectToCanvas(
            rect, root._minimumSizeForCanvas(activeId))

        if (bestX) {
            guides.push({
                kind: "vertical",
                x: bestX.pos,
                y1: Math.min(fitted.y, bestX.other.y) - 8,
                y2: Math.max(
                    fitted.y + fitted.height,
                    bestX.other.y + bestX.other.height) + 8
            })
        }
        if (bestY) {
            guides.push({
                kind: "horizontal",
                y: bestY.pos,
                x1: Math.min(fitted.x, bestY.other.x) - 8,
                x2: Math.max(
                    fitted.x + fitted.width,
                    bestY.other.x + bestY.other.width) + 8
            })
        }

        // PowerPoint-style equal-spacing assistance. When the moving card sits
        // between two neighbours with nearly equal gaps, magnetize the final
        // few pixels and show double-ended distance arrows.
        let left = null
        let right = null
        let above = null
        let below = null
        let equalSpacingX = false
        let equalSpacingY = false
        for (let i = 0; i < others.length; ++i) {
            const other = others[i].rect
            const verticalOverlap = Math.min(
                fitted.y + fitted.height,
                other.y + other.height) - Math.max(fitted.y, other.y)
            const horizontalOverlap = Math.min(
                fitted.x + fitted.width,
                other.x + other.width) - Math.max(fitted.x, other.x)

            if (verticalOverlap > 0) {
                const otherRight = other.x + other.width
                if (otherRight <= fitted.x) {
                    const gap = fitted.x - otherRight
                    if (!left || gap < left.gap)
                        left = { rect: other, gap: gap }
                }
                if (other.x >= fitted.x + fitted.width) {
                    const gap = other.x - (fitted.x + fitted.width)
                    if (!right || gap < right.gap)
                        right = { rect: other, gap: gap }
                }
            }

            if (horizontalOverlap > 0) {
                const otherBottom = other.y + other.height
                if (otherBottom <= fitted.y) {
                    const gap = fitted.y - otherBottom
                    if (!above || gap < above.gap)
                        above = { rect: other, gap: gap }
                }
                if (other.y >= fitted.y + fitted.height) {
                    const gap = other.y - (fitted.y + fitted.height)
                    if (!below || gap < below.gap)
                        below = { rect: other, gap: gap }
                }
            }
        }

        if (left && right
                && left.gap >= root.collisionGap
                && right.gap >= root.collisionGap
                && Math.abs(left.gap - right.gap) <= threshold * 2) {
            equalSpacingX = true
            if (!bestX) {
                const delta = (right.gap - left.gap) / 2
                if (Math.abs(delta) <= threshold)
                    fitted.x = Math.max(0,
                        Math.min(canvas.width - fitted.width,
                            fitted.x + delta))
            }
            const leftGap = fitted.x
                - (left.rect.x + left.rect.width)
            const rightGap = right.rect.x
                - (fitted.x + fitted.width)
            const y = fitted.y + fitted.height / 2
            guides.push({
                kind: "spacingH",
                x1: left.rect.x + left.rect.width,
                x2: fitted.x,
                y: y,
                distance: leftGap
            })
            guides.push({
                kind: "spacingH",
                x1: fitted.x + fitted.width,
                x2: right.rect.x,
                y: y,
                distance: rightGap
            })
        }

        if (above && below
                && above.gap >= root.collisionGap
                && below.gap >= root.collisionGap
                && Math.abs(above.gap - below.gap) <= threshold * 2) {
            equalSpacingY = true
            if (!bestY) {
                const delta = (below.gap - above.gap) / 2
                if (Math.abs(delta) <= threshold)
                    fitted.y = Math.max(0,
                        Math.min(canvas.height - fitted.height,
                            fitted.y + delta))
            }
            const aboveGap = fitted.y
                - (above.rect.y + above.rect.height)
            const belowGap = below.rect.y
                - (fitted.y + fitted.height)
            const x = fitted.x + fitted.width / 2
            guides.push({
                kind: "spacingV",
                x: x,
                y1: above.rect.y + above.rect.height,
                y2: fitted.y,
                distance: aboveGap
            })
            guides.push({
                kind: "spacingV",
                x: x,
                y1: fitted.y + fitted.height,
                y2: below.rect.y,
                distance: belowGap
            })
        }

        // Diagonal center guide: visual only. It helps keep diagonal module
        // relationships obvious without constraining freeform placement.
        const cx = fitted.x + fitted.width / 2
        const cy = fitted.y + fitted.height / 2
        let diagonal = null
        for (let i = 0; i < others.length; ++i) {
            const other = others[i].rect
            const ox = other.x + other.width / 2
            const oy = other.y + other.height / 2
            const dx = ox - cx
            const dy = oy - cy
            const diagonalError = Math.abs(Math.abs(dx) - Math.abs(dy))
            const length = Math.sqrt(dx * dx + dy * dy)
            if (Math.min(Math.abs(dx), Math.abs(dy)) > 20
                    && diagonalError <= threshold
                    && (!diagonal || length < diagonal.length)) {
                diagonal = {
                    length: length,
                    x1: cx, y1: cy,
                    x2: ox, y2: oy
                }
            }
        }
        if (diagonal)
            guides.push(Object.assign({ kind: "diagonal" }, diagonal))

        root._smartGuides = guides
        root._smartSnapAxes = {
            x: bestX !== null || equalSpacingX,
            y: bestY !== null || equalSpacingY
        }
        return fitted
    }

    function _smartAlignResize(activeId, sourceRect, edge,
            baselineRects) {
        const rect = root._cloneRect(sourceRect)
        const threshold = root.smartGuideThreshold
        const others = root._otherRects(activeId, baselineRects)
        const min = root._minimumSizeForCanvas(activeId)
        const resizeEdge = String(edge ?? "")
        const guides = []
        let bestVertical = null
        let bestHorizontal = null

        if (resizeEdge.indexOf("w") >= 0
                || resizeEdge.indexOf("e") >= 0) {
            const activeX = resizeEdge.indexOf("w") >= 0
                ? rect.x : rect.x + rect.width
            for (let i = 0; i < others.length; ++i) {
                const other = others[i].rect
                const targets = [other.x, other.x + other.width]
                for (let t = 0; t < targets.length; ++t) {
                    const delta = targets[t] - activeX
                    const distance = Math.abs(delta)
                    if (distance <= threshold
                            && (!bestVertical
                                || distance < bestVertical.distance)) {
                        bestVertical = {
                            distance: distance,
                            delta: delta,
                            pos: targets[t],
                            other: other
                        }
                    }
                }
            }
        }

        if (resizeEdge.indexOf("n") >= 0
                || resizeEdge.indexOf("s") >= 0) {
            const activeY = resizeEdge.indexOf("n") >= 0
                ? rect.y : rect.y + rect.height
            for (let i = 0; i < others.length; ++i) {
                const other = others[i].rect
                const targets = [other.y, other.y + other.height]
                for (let t = 0; t < targets.length; ++t) {
                    const delta = targets[t] - activeY
                    const distance = Math.abs(delta)
                    if (distance <= threshold
                            && (!bestHorizontal
                                || distance < bestHorizontal.distance)) {
                        bestHorizontal = {
                            distance: distance,
                            delta: delta,
                            pos: targets[t],
                            other: other
                        }
                    }
                }
            }
        }

        if (bestVertical) {
            if (resizeEdge.indexOf("w") >= 0) {
                const right = rect.x + rect.width
                const left = Math.min(
                    right - min.width, rect.x + bestVertical.delta)
                rect.x = left
                rect.width = right - left
            } else {
                rect.width = Math.max(
                    min.width, rect.width + bestVertical.delta)
            }
            guides.push({
                kind: "vertical",
                x: bestVertical.pos,
                y1: Math.min(rect.y, bestVertical.other.y) - 8,
                y2: Math.max(
                    rect.y + rect.height,
                    bestVertical.other.y + bestVertical.other.height) + 8
            })
        }

        if (bestHorizontal) {
            if (resizeEdge.indexOf("n") >= 0) {
                const bottom = rect.y + rect.height
                const top = Math.min(
                    bottom - min.height, rect.y + bestHorizontal.delta)
                rect.y = top
                rect.height = bottom - top
            } else {
                rect.height = Math.max(
                    min.height, rect.height + bestHorizontal.delta)
            }
            guides.push({
                kind: "horizontal",
                y: bestHorizontal.pos,
                x1: Math.min(rect.x, bestHorizontal.other.x) - 8,
                x2: Math.max(
                    rect.x + rect.width,
                    bestHorizontal.other.x + bestHorizontal.other.width) + 8
            })
        }

        const fitted = root._fitRectToCanvas(rect, min)
        root._smartGuides = guides
        root._smartSnapAxes = {
            x: bestVertical !== null,
            y: bestHorizontal !== null
        }
        return fitted
    }

    function _snapshotVisibleRects() {
        const result = ({})
        // Always snapshot persisted geometry. Every pointer frame resolves from
        // this immutable baseline so neighbours expand back immediately when the
        // user reverses a resize while still holding the mouse button.
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const id = String(root.visibleIds[i])
            result[id] = root._cloneRect(
                root._rectPixelsForGeometry(id, root._entryFor(id)))
        }
        return result
    }

    function _rectsOverlap(a, b, gap) {
        const g = Number(gap ?? 0)
        return a.x < b.x + b.width + g
            && a.x + a.width + g > b.x
            && a.y < b.y + b.height + g
            && a.y + a.height + g > b.y
    }

    function _candidateInRegion(base, min, x0, y0, x1, y1,
            allowResize) {
        const left = Math.max(0, Number(x0))
        const top = Math.max(0, Number(y0))
        const right = Math.min(canvas.width, Number(x1))
        const bottom = Math.min(canvas.height, Number(y1))
        const availableWidth = Math.max(0, right - left)
        const availableHeight = Math.max(0, bottom - top)
        const baseWidth = Math.min(canvas.width, Number(base.width))
        const baseHeight = Math.min(canvas.height, Number(base.height))
        const requiredWidth = allowResize ? min.width : baseWidth
        const requiredHeight = allowResize ? min.height : baseHeight
        if (availableWidth + 0.001 < requiredWidth
                || availableHeight + 0.001 < requiredHeight)
            return null

        // Drag/drop and resize-with-auto-adjust-off preserve neighbour sizes.
        // Shrinking is available only during an explicit resize interaction
        // while Auto-adjust size is enabled.
        const width = allowResize
            ? Math.max(min.width, Math.min(baseWidth, availableWidth))
            : baseWidth
        const height = allowResize
            ? Math.max(min.height, Math.min(baseHeight, availableHeight))
            : baseHeight
        return {
            x: Math.max(left,
                Math.min(right - width, Number(base.x))),
            y: Math.max(top,
                Math.min(bottom - height, Number(base.y))),
            width: width,
            height: height
        }
    }

    function _candidateScore(candidate, base, obstacles) {
        if (!candidate)
            return Number.POSITIVE_INFINITY
        let overlaps = 0
        for (let i = 0; i < obstacles.length; ++i) {
            if (root._rectsOverlap(candidate, obstacles[i],
                    root.collisionGap))
                overlaps++
        }
        const dx = candidate.x - base.x
        const dy = candidate.y - base.y
        const dw = Math.max(0, base.width - candidate.width)
        const dh = Math.max(0, base.height - candidate.height)
        // A local elastic shrink is cheaper than teleporting a widget across
        // the canvas, while any remaining overlap is effectively forbidden.
        return overlaps * 1000000000
            + dx * dx + dy * dy
            + (dw * dw + dh * dh) * 0.35
    }

    function _bestSideCandidate(base, min, obstacle, obstacles,
            allowResize) {
        const gap = root.collisionGap
        const right = obstacle.x + obstacle.width
        const bottom = obstacle.y + obstacle.height
        const candidates = [
            root._candidateInRegion(base, min,
                0, 0, obstacle.x - gap, canvas.height, allowResize),
            root._candidateInRegion(base, min,
                right + gap, 0, canvas.width, canvas.height, allowResize),
            root._candidateInRegion(base, min,
                0, 0, canvas.width, obstacle.y - gap, allowResize),
            root._candidateInRegion(base, min,
                0, bottom + gap, canvas.width, canvas.height, allowResize)
        ]
        let best = null
        let bestScore = Number.POSITIVE_INFINITY
        for (let i = 0; i < candidates.length; ++i) {
            const score = root._candidateScore(
                candidates[i], base, obstacles)
            if (score < bestScore) {
                bestScore = score
                best = candidates[i]
            }
        }
        return best
    }

    function _fallbackPlacement(base, min, obstacles, allowResize) {
        const gap = root.collisionGap
        const widths = allowResize ? [
            Math.min(canvas.width, base.width),
            Math.max(min.width, Math.min(base.width, base.width * 0.82)),
            Math.max(min.width, Math.min(base.width, base.width * 0.66)),
            min.width
        ] : [Math.min(canvas.width, base.width)]
        const heights = allowResize ? [
            Math.min(canvas.height, base.height),
            Math.max(min.height, Math.min(base.height, base.height * 0.82)),
            Math.max(min.height, Math.min(base.height, base.height * 0.66)),
            min.height
        ] : [Math.min(canvas.height, base.height)]
        let best = null
        let bestScore = Number.POSITIVE_INFINITY

        for (let wi = 0; wi < widths.length; ++wi) {
            for (let hi = 0; hi < heights.length; ++hi) {
                const width = Math.min(canvas.width, widths[wi])
                const height = Math.min(canvas.height, heights[hi])
                const xs = [base.x, 0, canvas.width - width]
                const ys = [base.y, 0, canvas.height - height]
                for (let oi = 0; oi < obstacles.length; ++oi) {
                    const obstacle = obstacles[oi]
                    xs.push(obstacle.x - gap - width)
                    xs.push(obstacle.x + obstacle.width + gap)
                    ys.push(obstacle.y - gap - height)
                    ys.push(obstacle.y + obstacle.height + gap)
                }

                for (let xi = 0; xi < xs.length; ++xi) {
                    for (let yi = 0; yi < ys.length; ++yi) {
                        const candidate = root._fitRectToCanvas({
                            x: xs[xi], y: ys[yi],
                            width: width, height: height
                        }, min)
                        let blocked = false
                        for (let oi = 0; oi < obstacles.length; ++oi) {
                            if (root._rectsOverlap(candidate, obstacles[oi], gap)) {
                                blocked = true
                                break
                            }
                        }
                        if (blocked)
                            continue
                        const score = root._candidateScore(
                            candidate, base, obstacles)
                        if (score < bestScore) {
                            bestScore = score
                            best = candidate
                        }
                    }
                }
            }
        }
        return best
    }

    function _resolveNeighbour(baseRect, id, obstacles, allowResize) {
        const min = root._minimumSizeForCanvas(id)
        const base = root._fitRectToCanvas(baseRect, min)
        let current = root._cloneRect(base)

        const maxPasses = Math.max(8, obstacles.length * 4)
        for (let pass = 0; pass < maxPasses; ++pass) {
            let blocker = null
            for (let i = 0; i < obstacles.length; ++i) {
                if (root._rectsOverlap(current, obstacles[i],
                        root.collisionGap)) {
                    blocker = obstacles[i]
                    break
                }
            }
            if (!blocker)
                return current

            const next = root._bestSideCandidate(
                base, min, blocker, obstacles, allowResize)
            if (!next)
                break

            const unchanged = Math.abs(next.x - current.x) < 0.01
                && Math.abs(next.y - current.y) < 0.01
                && Math.abs(next.width - current.width) < 0.01
                && Math.abs(next.height - current.height) < 0.01
            current = next
            if (unchanged)
                break
        }

        // Complex chains can exhaust the simple side solver. Search the finite
        // set of obstacle edges before conceding; this keeps ordinary dashboard
        // layouts overlap-free without running a full grid packer every frame.
        return root._fallbackPlacement(
            base, min, obstacles, allowResize) ?? current
    }

    function _resolveLayout(activeId, activeRect, baselineRects,
            allowResize) {
        const result = ({})
        const activeMin = root._minimumSizeForCanvas(activeId)
        const fixedActive = root._fitRectToCanvas(activeRect, activeMin)
        result[activeId] = fixedActive

        const activeBase = baselineRects[activeId] ?? fixedActive
        const activeCenterX = activeBase.x + activeBase.width / 2
        const activeCenterY = activeBase.y + activeBase.height / 2
        const others = []
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const id = String(root.visibleIds[i])
            if (id === activeId)
                continue
            others.push(id)
        }
        // Resolve closest neighbours first, then propagate outward. Combined
        // with the immutable baseline this behaves like an elastic local pack:
        // nearby widgets give way first and all recover as the pointer retreats.
        others.sort((a, b) => {
            const ar = baselineRects[a]
            const br = baselineRects[b]
            const adx = (ar.x + ar.width / 2) - activeCenterX
            const ady = (ar.y + ar.height / 2) - activeCenterY
            const bdx = (br.x + br.width / 2) - activeCenterX
            const bdy = (br.y + br.height / 2) - activeCenterY
            return (adx * adx + ady * ady) - (bdx * bdx + bdy * bdy)
        })

        const obstacles = [fixedActive]
        for (let i = 0; i < others.length; ++i) {
            const id = others[i]
            const base = baselineRects[id] ?? root._rectPixels(id)
            const resolved = root._resolveNeighbour(
                base, id, obstacles, allowResize)
            result[id] = resolved
            obstacles.push(resolved)
        }
        return result
    }

    function _layoutHasOverlap(rects) {
        const ids = []
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const id = String(root.visibleIds[i])
            if (rects[id])
                ids.push(id)
        }
        for (let i = 0; i < ids.length; ++i) {
            for (let j = i + 1; j < ids.length; ++j) {
                if (root._rectsOverlap(rects[ids[i]], rects[ids[j]],
                        root.collisionGap))
                    return true
            }
        }
        return false
    }

    function _interpolateRect(from, to, t) {
        return {
            x: from.x + (to.x - from.x) * t,
            y: from.y + (to.y - from.y) * t,
            width: from.width + (to.width - from.width) * t,
            height: from.height + (to.height - from.height) * t
        }
    }

    function _resolveFeasibleLayout(activeId, startRect, desiredRect,
            baselineRects, allowResize) {
        const desired = root._resolveLayout(
            activeId, desiredRect, baselineRects, allowResize)
        if (!root._layoutHasOverlap(desired))
            return desired

        // If neighbours have reached their minimums/bounds, clamp the active
        // interaction to the last feasible point rather than allowing overlap.
        let best = root._resolveLayout(
            activeId, startRect, baselineRects, allowResize)
        let low = 0
        let high = 1
        for (let i = 0; i < 8; ++i) {
            const mid = (low + high) / 2
            const probeRect = root._interpolateRect(
                startRect, desiredRect, mid)
            const probe = root._resolveLayout(
                activeId, probeRect, baselineRects, allowResize)
            if (root._layoutHasOverlap(probe)) {
                high = mid
            } else {
                low = mid
                best = probe
            }
        }
        return best
    }

    function _applyPreviewRects(rects) {
        const next = ({})
        for (let i = 0; i < root.visibleIds.length; ++i) {
            const id = String(root.visibleIds[i])
            const px = rects[id]
            if (!px)
                continue
            next[id] = root._normalizedRect(
                px, root._entryFor(id).visible)
        }
        root._preview = next
    }

    function _persistPreviewLayout() {
        const entries = root._entriesForWrite()
        const indexById = ({})
        for (let i = 0; i < entries.length; ++i)
            indexById[entries[i].id] = i

        for (let i = 0; i < root._allIds.length; ++i) {
            const id = String(root._allIds[i])
            const g = root._preview[id]
            if (g === undefined)
                continue
            const patch = { x: g.x, y: g.y, w: g.w, h: g.h }
            const index = indexById[id]
            if (index === undefined) {
                indexById[id] = entries.length
                entries.push(Object.assign({}, root._defaultEntry(id), patch))
            } else {
                entries[index] = Object.assign({}, entries[index], patch)
            }
        }
        Config.setNestedValue("dashboard.canvas.widgets", entries)
    }

    function beginMove(id, point) {
        root._preview = ({})
        root._smartGuides = []
        root._smartSnapAxes = ({ x: false, y: false })
        root.selectedId = id
        root._interaction = {
            id: id,
            kind: "move",
            startPoint: point,
            startRect: root._rectPixels(id),
            baselineRects: root._snapshotVisibleRects()
        }
    }

    function beginResize(id, edge, point) {
        root._preview = ({})
        root._smartGuides = []
        root._smartSnapAxes = ({ x: false, y: false })
        root.selectedId = id
        root._interaction = {
            id: id,
            kind: "resize",
            edge: edge,
            startPoint: point,
            startRect: root._rectPixels(id),
            baselineRects: root._snapshotVisibleRects()
        }
    }

    function updateInteraction(point) {
        const state = root._interaction
        if (!state)
            return

        const dx = point.x - state.startPoint.x
        const dy = point.y - state.startPoint.y
        const start = state.startRect
        const min = root._minimumSizeForCanvas(state.id)
        let left = start.x
        let top = start.y
        let right = start.x + start.width
        let bottom = start.y + start.height

        if (state.kind === "move") {
            left = start.x + dx
            top = start.y + dy
            left = Math.max(0, Math.min(canvas.width - start.width, left))
            top = Math.max(0, Math.min(canvas.height - start.height, top))

            // A dragged module is temporarily lifted out of the packed layout.
            // Only the selected module follows the pointer; neighbours stay
            // completely stable until drop, when the insertion is resolved once.
            const guided = root._smartAlignMove(state.id, {
                x: left, y: top,
                width: start.width, height: start.height
            }, state.baselineRects)
            root._setPreview(state.id, guided)
            return
        }

        const edge = String(state.edge ?? "")
        if (edge.indexOf("w") >= 0)
            left = start.x + dx
        if (edge.indexOf("e") >= 0)
            right = start.x + start.width + dx
        if (edge.indexOf("n") >= 0)
            top = start.y + dy
        if (edge.indexOf("s") >= 0)
            bottom = start.y + start.height + dy

        left = Math.max(0, Math.min(left, right - min.width))
        right = Math.min(canvas.width, Math.max(right, left + min.width))
        top = Math.max(0, Math.min(top, bottom - min.height))
        bottom = Math.min(canvas.height, Math.max(bottom, top + min.height))

        if (right - left < min.width) {
            if (edge.indexOf("w") >= 0)
                left = right - min.width
            else
                right = left + min.width
        }
        if (bottom - top < min.height) {
            if (edge.indexOf("n") >= 0)
                top = bottom - min.height
            else
                bottom = top + min.height
        }

        left = Math.max(0, left)
        top = Math.max(0, top)
        right = Math.min(canvas.width, right)
        bottom = Math.min(canvas.height, bottom)

        const desired = root._smartAlignResize(state.id, {
            x: left, y: top,
            width: Math.max(1, right - left),
            height: Math.max(1, bottom - top)
        }, edge, state.baselineRects)
        const resolved = root._resolveFeasibleLayout(
            state.id, start, desired, state.baselineRects,
            root.autoAdjustSizeEnabled)
        root._applyPreviewRects(resolved)
    }

    function finishInteraction(commit) {
        const state = root._interaction
        if (!state)
            return

        if (!commit) {
            // End direct manipulation first so geometry Behaviors animate the
            // selected module smoothly back to its persisted rect.
            root._interaction = null
            root._preview = ({})
            root._smartGuides = []
            root._smartSnapAxes = ({ x: false, y: false })
            return
        }

        if (Object.keys(root._preview).length === 0) {
            root._interaction = null
            root._smartGuides = []
            root._smartSnapAxes = ({ x: false, y: false })
            return
        }

        const activeGeometry = root._preview[state.id]
        if (activeGeometry !== undefined) {
            const currentRect = root._rectPixelsForGeometry(
                state.id, activeGeometry)
            const snappedRect = root._snapRectForCommit(
                state.id, currentRect, state.kind, state.edge,
                root._smartSnapAxes.x, root._smartSnapAxes.y)
            // Drop is the insertion point: resolve neighbours exactly once
            // after continuous pointer tracking has ended.
            const allowResize = state.kind === "resize"
                && root.autoAdjustSizeEnabled
            const resolved = root._resolveFeasibleLayout(
                state.id, state.startRect, snappedRect,
                state.baselineRects, allowResize)

            // Pointer tracking ends before the final target is published. The
            // selected module and any displaced neighbours therefore settle into
            // their snapped positions with the same spatial animation.
            root._interaction = null
            root._smartGuides = []
            root._smartSnapAxes = ({ x: false, y: false })
            root._applyPreviewRects(resolved)
            root._persistPreviewLayout()

            // Keep the resolved preview alive through this event-loop turn so
            // Config propagation cannot briefly expose the old persisted rect.
            // Clearing on the next turn makes the target handoff visually
            // continuous instead of flashing back for one frame.
            Qt.callLater(() => {
                if (root._interaction === null)
                    root._preview = ({})
            })
        } else {
            root._interaction = null
            root._preview = ({})
            root._smartGuides = []
            root._smartSnapAxes = ({ x: false, y: false })
        }
    }

    function _cycleGridSize() {
        const sizes = [16, 24, 32, 48, 64]
        const current = root.gridSize
        let index = sizes.indexOf(current)
        index = index < 0 ? 0 : (index + 1) % sizes.length
        Config.setNestedValue("dashboard.canvas.gridSize", sizes[index])
    }

    function _cycleGridStyle() {
        const styles = ["dots", "lines", "cross"]
        const current = styles.indexOf(root.gridStyle)
        Config.setNestedValue("dashboard.canvas.gridStyle",
            styles[(current < 0 ? 0 : current + 1) % styles.length])
    }

    onEditModeChanged: {
        if (!editMode) {
            root.finishInteraction(false)
            root._smartGuides = []
            root._smartSnapAxes = ({ x: false, y: false })
            root.selectedId = ""
        }
    }
    onPresentationActiveChanged: if (!presentationActive) root.editMode = false

    Component { id: welcomeComponent; DashWelcome {} }
    Component { id: clockComponent; DashClock {} }
    Component { id: weatherComponent; DashWeather {} }
    Component {
        id: calendarComponent
        DashCalendar {
            onRequestEventsDialog: event => root.requestEventsDialog(event)
        }
    }
    Component {
        id: mediaComponent
        DashMedia {
            presentationActive: root.presentationActive
        }
    }
    Component { id: notificationsComponent; DashNotifications {} }
    Component { id: todoComponent; DashTodo {} }
    Component { id: systemComponent; DashSystem {} }
    Component { id: githubComponent; DashGithub {} }
    Component { id: notesComponent; DashNotes {} }
    Component {
        id: agendaComponent
        DashAgenda {
            onRequestEventsDialog: event => root.requestEventsDialog(event)
        }
    }

    Item {
        id: canvas
        anchors.fill: parent
        clip: true

        DashboardEditGrid {
            anchors.fill: parent
            visible: root.editMode
            opacity: root.editMode ? 1 : 0
            gridSize: root.gridSize
            gridStyle: root.gridStyle
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                }
            }
        }

        DashboardAlignmentGuides {
            anchors.fill: parent
            z: 70
            visible: root.editMode && root._smartGuides.length > 0
            guides: root._smartGuides
        }

        Repeater {
            // Keep delegate identity stable for the whole Dashboard lifetime.
            // A JS-array model derived from _preview would recreate delegates
            // during pointer updates and look like cards were blinking/chopping.
            model: root._allIds

            delegate: Item {
                id: cardWrap
                required property var modelData
                readonly property var px: root._rectPixels(String(modelData))
                visible: root.geometryFor(String(modelData)).visible !== false
                readonly property bool selected:
                    root.editMode && root.selectedId === String(modelData)
                readonly property bool directlyManipulated:
                    selected && root._interaction !== null
                readonly property bool floating:
                    directlyManipulated && root._interaction?.kind === "move"
                readonly property bool animateGeometry:
                    root.editMode && !directlyManipulated

                x: px.x
                y: px.y
                width: px.width
                height: px.height
                z: floating ? 50 : (selected ? 30 : 1)

                Behavior on x {
                    enabled: Appearance.animationsEnabled
                        && cardWrap.animateGeometry
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve:
                            Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                        && cardWrap.animateGeometry
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve:
                            Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                        && cardWrap.animateGeometry
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve:
                            Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on height {
                    enabled: Appearance.animationsEnabled
                        && cardWrap.animateGeometry
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve:
                            Appearance.animation.elementResize.bezierCurve
                    }
                }

                scale: floating ? 1.012 : 1
                transformOrigin: Item.Center
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                    }
                }

                Item {
                    id: cardViewport
                    anchors.fill: parent
                    clip: true

                    Loader {
                        anchors.fill: parent
                        sourceComponent: root._widgetMap[String(cardWrap.modelData)] ?? null
                        active: cardWrap.visible
                        enabled: !root.editMode
                        opacity: root.editMode ? 0.92 : 1
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.editMode
                    color: selected
                        ? ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, 0.10)
                        : ColorUtils.applyAlpha(Appearance.colors.colLayer1Hover, 0.06)
                    radius: Appearance.rounding.normal
                    border.width: selected ? 2 : 1
                    border.color: selected
                        ? Appearance.colors.colPrimary
                        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.72)
                    z: 10
                }

                MouseArea {
                    id: moveArea
                    anchors.fill: parent
                    enabled: root.editMode
                    hoverEnabled: root.editMode
                    preventStealing: true
                    z: 20
                    cursorShape: root.editMode
                        ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                        : Qt.ArrowCursor
                    onPressed: mouse => {
                        const p = moveArea.mapToItem(canvas, mouse.x, mouse.y)
                        root.beginMove(String(cardWrap.modelData), p)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = moveArea.mapToItem(canvas, mouse.x, mouse.y)
                        root.updateInteraction(p)
                    }
                    onReleased: root.finishInteraction(true)
                    onCanceled: root.finishInteraction(false)
                }

                RippleButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    visible: cardWrap.selected && root._interaction === null
                    z: 40
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    onClicked: root.setWidgetVisible(String(cardWrap.modelData), false)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: Translation.tr("Hide from dashboard") }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    visible: cardWrap.selected && root._interaction !== null
                    z: 41
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2
                    implicitWidth: sizeText.implicitWidth + 14
                    implicitHeight: 24
                    StyledText {
                        id: sizeText
                        anchors.centerIn: parent
                        text: Math.round(cardWrap.width) + " × " + Math.round(cardWrap.height)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer2
                    }
                }

                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "n"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "s"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "e"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "w"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "nw"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "ne"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "sw"; cardItem: cardWrap }
                ResizeHandle { widgetId: String(cardWrap.modelData); edge: "se"; cardItem: cardWrap }
            }
        }

    }

    component ResizeHandle: Rectangle {
        id: handle
        required property string widgetId
        required property string edge
        required property Item cardItem

        readonly property bool horizontal:
            edge === "n" || edge === "s"
        readonly property bool vertical:
            edge === "e" || edge === "w"
        readonly property bool corner: edge.length === 2

        visible: root.editMode && root.selectedId === widgetId
        z: 60
        width: corner ? 8 : (horizontal ? 24 : 6)
        height: corner ? 8 : (vertical ? 24 : 6)
        radius: corner ? 2 : Appearance.rounding.full
        color: Appearance.colors.colPrimary
        border.width: 0
        border.color: "transparent"

        x: {
            if (edge.indexOf("w") >= 0)
                return -width / 2
            if (edge.indexOf("e") >= 0)
                return cardItem.width - width / 2
            return cardItem.width / 2 - width / 2
        }
        y: {
            if (edge.indexOf("n") >= 0)
                return -height / 2
            if (edge.indexOf("s") >= 0)
                return cardItem.height - height / 2
            return cardItem.height / 2 - height / 2
        }

        MouseArea {
            id: resizeMouse
            anchors.fill: parent
            anchors.margins: -4
            enabled: handle.visible
            preventStealing: true
            cursorShape: {
                if (!handle.visible)
                    return Qt.ArrowCursor
                if (handle.edge === "n" || handle.edge === "s")
                    return Qt.SizeVerCursor
                if (handle.edge === "e" || handle.edge === "w")
                    return Qt.SizeHorCursor
                if (handle.edge === "nw" || handle.edge === "se")
                    return Qt.SizeFDiagCursor
                return Qt.SizeBDiagCursor
            }
            onPressed: mouse => {
                const p = resizeMouse.mapToItem(canvas, mouse.x, mouse.y)
                root.beginResize(handle.widgetId, handle.edge, p)
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                const p = resizeMouse.mapToItem(canvas, mouse.x, mouse.y)
                root.updateInteraction(p)
            }
            onReleased: root.finishInteraction(true)
            onCanceled: root.finishInteraction(false)
        }
    }
}
