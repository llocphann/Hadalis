import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root
    property bool _sortingConsumerAcquired: false

    // Debug logging gated behind QS_DEBUG env var (project convention)
    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log("[DockDrag]", ...args);
    }

    property real dockThickness: Config.options?.dock?.height ?? 60
    property bool vertical: false
    property string dockPosition: "bottom"
    property var parentWindow: null
    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool contextMenuOpen: false
    property bool requestDockShow: dockPreviewPopup.visible || contextMenuOpen || dragActive

    signal closeAllContextMenus()

    property bool _suppressNextClick: false

    function showPreviewPopup(appEntry: var, button: Item): void {
        if (Config.options?.dock?.hoverPreview === false) return
        dockPreviewPopup.show(appEntry, button)
    }

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: listView.contentWidth
    implicitHeight: listView.contentHeight

    readonly property bool dragEnabled: Config.options?.dock?.enableDragReorder ?? true
    property bool dragActive: false
    property int dragIndex: -1
    property int dropTargetIndex: -1
    property string dragAppId: ""
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurrentX: 0
    property real dragCurrentY: 0

    property bool dropSettlingActive: false
    property string dropSettleId: ""
    property int dropSettleIndex: -1
    property real dropSettleOffsetX: 0
    property real dropSettleOffsetY: 0

    readonly property real dragThreshold: 18

    function getDragDisplacement(itemIndex: int): real {
        if (!dragActive || dragIndex < 0 || dropTargetIndex < 0) return 0
        if (itemIndex === dragIndex) return 0

        const draggedItem = listView.itemAtIndex(dragIndex)
        const step = draggedItem
            ? (vertical ? draggedItem.height : draggedItem.width) + listView.spacing
            : 50 + listView.spacing

        if (dragIndex < dropTargetIndex) {
            if (itemIndex > dragIndex && itemIndex <= dropTargetIndex) {
                return -step
            }
        } else if (dragIndex > dropTargetIndex) {
            if (itemIndex >= dropTargetIndex && itemIndex < dragIndex) {
                return step
            }
        }
        return 0
    }

    function startDrag(index: int, appId: string, globalX: real, globalY: real): void {
        if (!dragEnabled) return

        dockPreviewPopup.close()
        closeAllContextMenus()

        dragIndex = index
        dragAppId = appId
        dragStartX = globalX
        dragStartY = globalY
        dragCurrentX = globalX
        dragCurrentY = globalY
        dropTargetIndex = index
        dragActive = true
        _log(`START index=${index} appId=${appId} pos=(${globalX.toFixed(0)},${globalY.toFixed(0)})`)
    }

    function updateDrag(globalX: real, globalY: real): void {
        if (!dragActive || dragIndex < 0) return
        dragCurrentX = globalX
        dragCurrentY = globalY

        const count = dockItems.length
        if (count === 0) return

        let bestIndex = dropTargetIndex
        let bestDist = Infinity

        for (let i = 0; i < count; i++) {
            const item = listView.itemAtIndex(i)
            if (!item) continue

            const midX = item.x + item.width / 2
            const midY = item.y + item.height / 2

            const dist = vertical
                ? Math.abs(globalY - midY)
                : Math.abs(globalX - midX)

            if (dist < bestDist) {
                bestDist = dist
                bestIndex = i
            }
        }

        if (bestIndex >= 0 && bestIndex < count && dockItems[bestIndex].appId === "SEPARATOR") {
            const movingForward = vertical ? (globalY > dragStartY) : (globalX > dragStartX)
            if (movingForward && bestIndex + 1 < count) bestIndex++
            else if (!movingForward && bestIndex - 1 >= 0) bestIndex--
        }

        if (dropTargetIndex !== bestIndex) {
            _log(`UPDATE dropTarget=${bestIndex} (was ${dropTargetIndex})`)
        }
        dropTargetIndex = bestIndex
    }

    function endDrag(): void {
        if (!dragActive) return

        const draggedItem = dockItems[dragIndex]
        dropSettleId = draggedItem?.uniqueId ?? dragAppId
        dropSettleIndex = dragIndex
        dropSettleOffsetX = 0
        dropSettleOffsetY = 0
        dropSettlingActive = true

        _log(`END dragIndex=${dragIndex} dropTarget=${dropTargetIndex} reorder=${dragIndex !== dropTargetIndex}`)
        if (dragIndex >= 0 && dropTargetIndex >= 0 && dragIndex !== dropTargetIndex) {
            _applyReorder(dragIndex, dropTargetIndex)
        }

        _resetDragState(false)
        dropSettleResetTimer.restart()
    }

    function cancelDrag(): void {
        _resetDragState(true)
    }

    function _resetDragState(clearDropSettle = true): void {
        dragActive = false
        dragIndex = -1
        dropTargetIndex = -1
        dragAppId = ""
        dragStartX = 0
        dragStartY = 0
        dragCurrentX = 0
        dragCurrentY = 0
        if (clearDropSettle) {
            dropSettleResetTimer.stop()
            dropSettlingActive = false
            dropSettleId = ""
            dropSettleIndex = -1
            dropSettleOffsetX = 0
            dropSettleOffsetY = 0
        }
    }

    Timer {
        id: dropSettleResetTimer
        interval: 2
        repeat: false
        onTriggered: {
            dropSettlingActive = false
            dropSettleId = ""
            dropSettleIndex = -1
            dropSettleOffsetX = 0
            dropSettleOffsetY = 0
        }
    }

    function _applyReorder(fromIdx: int, toIdx: int): void {
        const fromItem = dockItems[fromIdx]
        const toItem = dockItems[toIdx]

        if (!fromItem || !toItem) return

        const fromAppId = fromItem.originalAppId ?? fromItem.appId
        const toAppId = toItem.originalAppId ?? toItem.appId

        if (toAppId === "SEPARATOR" || fromAppId === "SEPARATOR") return

        const fromIsRunning = (fromItem.toplevels?.length ?? 0) > 0
        const toIsRunning = (toItem.toplevels?.length ?? 0) > 0
        let pinnedApps = root._normalizedPinnedApps()

        const fromIsPinned = fromItem.pinned
        const toIsPinned = toItem.pinned

        if (fromIsRunning && toIsRunning
                && (root.separatePinnedFromRunning || (!fromIsPinned && !toIsPinned))) {
            const fromRunningId = fromAppId.toLowerCase()
            const toRunningId = toAppId.toLowerCase()
            const fromRunningIdx = _runningAppOrder.indexOf(fromRunningId)
            const toRunningIdx = _runningAppOrder.indexOf(toRunningId)
            if (fromRunningIdx >= 0 && toRunningIdx >= 0) {
                const [moved] = _runningAppOrder.splice(fromRunningIdx, 1)
                const insertIdx = toRunningIdx
                _runningAppOrder.splice(insertIdx, 0, moved)
                root.rebuildDockItems()
            }
            return
        }

        if (fromIsPinned && toIsPinned) {
            const realFromIdx = pinnedApps.findIndex(p => p.toLowerCase() === fromAppId.toLowerCase())
            const realToIdx = pinnedApps.findIndex(p => p.toLowerCase() === toAppId.toLowerCase())

            if (realFromIdx >= 0 && realToIdx >= 0) {
                const [moved] = pinnedApps.splice(realFromIdx, 1)
                pinnedApps.splice(realToIdx, 0, moved)
                Config.setNestedValue("dock.pinnedApps", pinnedApps)
            }
        } else if (!fromIsPinned && toIsPinned) {
            const realToIdx = pinnedApps.findIndex(p => p.toLowerCase() === toAppId.toLowerCase())
            const insertIdx = toIdx < fromIdx ? realToIdx : realToIdx + 1
            pinnedApps.splice(insertIdx, 0, fromAppId)
            Config.setNestedValue("dock.pinnedApps", pinnedApps)
        }
    }

    property var dockItems: []
    property var toplevelsByUniqueId: ({})
    property var _runningAppOrder: []

    readonly property bool separatePinnedFromRunning: Config.options?.dock?.separatePinnedFromRunning ?? true
    onSeparatePinnedFromRunningChanged: {
        root.rebuildDockItems()
    }

    property var _cachedIgnoredRegexes: []
    property var _lastIgnoredRegexStrings: []

    function _normalizedPinnedApps(): list<var> {
        const raw = Config.options?.dock?.pinnedApps ?? []
        const seen = new Set()
        const normalized = []
        for (const value of raw) {
            const appId = String(value ?? "").trim()
            if (appId.length === 0)
                continue
            const key = appId.toLowerCase()
            if (seen.has(key))
                continue
            seen.add(key)
            normalized.push(appId)
        }
        return normalized
    }

    function _getIgnoredRegexes(): list<var> {
        const ignoredRegexStrings = Config.options?.dock?.ignoredAppRegexes ?? [];
        if (JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)) {
            const systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"];
            const allIgnored = ignoredRegexStrings.concat(systemIgnored);
            const compiled = [];
            for (const pattern of allIgnored) {
                try {
                    compiled.push(new RegExp(String(pattern), "i"));
                } catch (error) {
                    root._log(`Ignoring invalid ignoredAppRegexes pattern: ${String(pattern)}`);
                }
            }
            _cachedIgnoredRegexes = compiled;
            _lastIgnoredRegexStrings = ignoredRegexStrings.slice();
        }
        return _cachedIgnoredRegexes;
    }

    Timer {
        id: rebuildTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root.enabled)
                root._doRebuildDockItems()
        }
    }

    function rebuildDockItems() {
        if (!root.enabled)
            return
        rebuildTimer.restart()
    }

    function _toplevelLiveKey(toplevel) {
        if (!toplevel) return ""
        if (toplevel._sourceKey !== undefined && toplevel._sourceKey !== null)
            return String(toplevel._sourceKey)
        return `${toplevel.appId || ""}::${toplevel.title || ""}`
    }

    function _dockItemsEqual(oldItems, newItems): bool {
        if (oldItems.length !== newItems.length) return false
        for (let i = 0; i < oldItems.length; i++) {
            const o = oldItems[i], n = newItems[i]
            if (o.uniqueId !== n.uniqueId || o.pinned !== n.pinned || o.section !== n.section) return false
            const oTL = o.toplevels, nTL = n.toplevels
            if (oTL.length !== nTL.length) return false
            for (let j = 0; j < oTL.length; j++) {
                if (root._toplevelLiveKey(oTL[j]) !== root._toplevelLiveKey(nTL[j])) return false
                if (!!oTL[j].activated !== !!nTL[j].activated) return false
            }
        }
        return true
    }

    function _doRebuildDockItems() {
        const pinnedApps = root._normalizedPinnedApps();
        const ignoredRegexes = _getIgnoredRegexes();
        const separatePinnedFromRunning = root.separatePinnedFromRunning;

        const tmToplevels = ToplevelManager.toplevels.values;
        const sorted = CompositorService.sortedToplevels;
        const sortedHasItems = sorted && sorted.length > 0;
        const niriAuthoritative = CompositorService.isNiri;
        const allToplevels = niriAuthoritative
            ? (sorted ?? [])
            : (sortedHasItems ? sorted : tmToplevels);

        const liveToplevelCounts = new Map();
        const crossCheck = sortedHasItems && !niriAuthoritative;
        if (crossCheck) {
            for (const tl of tmToplevels) {
                const key = root._toplevelLiveKey(tl);
                liveToplevelCounts.set(key, (liveToplevelCounts.get(key) ?? 0) + 1);
            }
        }

        const runningAppsMap = new Map();
        for (const toplevel of allToplevels) {
            if (!toplevel.appId) continue;
            if (toplevel.appId === "" || toplevel.appId === "null") continue;
            if (crossCheck) {
                const key = root._toplevelLiveKey(toplevel);
                const count = liveToplevelCounts.get(key) ?? 0;
                if (count <= 0) continue;
                liveToplevelCounts.set(key, count - 1);
            }
            const effectiveId = AppSearch.resolveWindowIdentity(toplevel);
            const lowerAppId = effectiveId.toLowerCase();

            if (ignoredRegexes.some(re => re.test(effectiveId))) {
                continue;
            }

            if (!runningAppsMap.has(lowerAppId)) {
                runningAppsMap.set(lowerAppId, {
                    appId: effectiveId,
                    toplevels: [],
                    pinned: false
                });
            }
            runningAppsMap.get(lowerAppId).toplevels.push(toplevel);
        }

        const currentRunning = new Set(runningAppsMap.keys());
        const runningOrder = root._runningAppOrder.filter(appId => currentRunning.has(appId));
        for (const [lowerAppId] of runningAppsMap) {
            if (!runningOrder.includes(lowerAppId))
                runningOrder.push(lowerAppId);
        }
        root._runningAppOrder = runningOrder;

        const values = [];
        let order = 0;

        if (!separatePinnedFromRunning) {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                const runningEntry = runningAppsMap.get(lowerAppId);
                if (!runningEntry && !AppSearch.lookupDesktopEntry(appId))
                    continue;
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: runningEntry?.toplevels ?? [],
                    pinned: true,
                    originalAppId: appId,
                    section: "pinned",
                    order: order++
                });
                runningAppsMap.delete(lowerAppId);
            }

            // Unified mode intentionally has no separator. Pinned entries keep
            // their persisted order and unpinned running apps follow them as one
            // continuous list; the separator belongs only to the explicit
            // separatePinnedFromRunning mode.
            const running = Array.from(runningAppsMap.entries())
                .sort((a, b) => root._runningAppOrder.indexOf(a[0])
                    - root._runningAppOrder.indexOf(b[0]));
            for (const [lowerAppId, entry] of running) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: false,
                    originalAppId: entry.appId,
                    section: "open",
                    order: order++
                });
            }
        } else {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                if (!runningAppsMap.has(lowerAppId)) {
                    if (!AppSearch.lookupDesktopEntry(appId))
                        continue;
                    values.push({
                        uniqueId: "app-" + lowerAppId,
                        appId: lowerAppId,
                        toplevels: [],
                        pinned: true,
                        originalAppId: appId,
                        section: "pinned",
                        order: order++
                    });
                }
            }

            const hasPinnedOnly = values.length > 0;
            const hasRunning = runningAppsMap.size > 0;

            if (hasPinnedOnly && hasRunning) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }

            const sortedRunningApps = [];
            for (const [lowerAppId, entry] of runningAppsMap) {
                sortedRunningApps.push({
                    lowerAppId: lowerAppId,
                    entry: entry
                });
            }
            sortedRunningApps.sort((a, b) => {
                return root._runningAppOrder.indexOf(a.lowerAppId)
                    - root._runningAppOrder.indexOf(b.lowerAppId);
            });

            for (const {lowerAppId, entry} of sortedRunningApps) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId),
                    originalAppId: entry.appId,
                    section: "running",
                    order: order++
                });
            }
        }

        const tlMap = {}
        for (const v of values) tlMap[v.uniqueId] = v.toplevels
        root.toplevelsByUniqueId = tlMap

        if (!_dockItemsEqual(dockItems, values)) {
            dockItems = values
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        enabled: root.enabled
        function onValuesChanged() {
            root.rebuildDockItems()
        }
    }

    Connections {
        target: CompositorService
        enabled: root.enabled
        function onSortedToplevelsChanged() {
            root.rebuildDockItems()
        }
    }

    Connections {
        target: Config.options?.dock
        enabled: root.enabled
        function onPinnedAppsChanged() {
            root.rebuildDockItems()
        }
        function onIgnoredAppRegexesChanged() {
            root.rebuildDockItems()
        }
    }
    Connections {
        target: Config.options?.windows
        enabled: root.enabled
        function onAppIdentityRulesChanged() {
            root.rebuildDockItems()
        }
    }

    function syncSortingDemand(): void {
        if (root.enabled && !_sortingConsumerAcquired) {
            CompositorService.acquireSortingConsumer()
            _sortingConsumerAcquired = true
            rebuildDockItems()
        } else if (!root.enabled && _sortingConsumerAcquired) {
            rebuildTimer.stop()
            CompositorService.releaseSortingConsumer()
            _sortingConsumerAcquired = false
        }
    }

    onEnabledChanged: syncSortingDemand()
    Component.onCompleted: syncSortingDemand()
    Component.onDestruction: {
        if (_sortingConsumerAcquired)
            CompositorService.releaseSortingConsumer()
    }

    StyledListView {
        id: listView
        spacing: 2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        anchors {
            top: root.vertical ? undefined : parent.top
            bottom: root.vertical ? undefined : parent.bottom
            left: root.vertical ? parent.left : undefined
            right: root.vertical ? parent.right : undefined
        }
        implicitWidth: contentWidth
        implicitHeight: contentHeight
        interactive: false

        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        readonly property bool _animOk: Appearance.animationsEnabled && !root.dragActive

        add: Transition {
            enabled: listView._animOk
            NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: Appearance.animation.elementMoveEnter.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
        }
        remove: Transition {
            enabled: listView._animOk
            NumberAnimation { properties: "opacity,scale"; to: 0; duration: Appearance.animation.elementMoveExit.duration; easing.type: Appearance.animation.elementMoveExit.type; easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve }
        }
        displaced: Transition {}
        addDisplaced: Transition {}
        removeDisplaced: Transition {}
        move: Transition {}
        moveDisplaced: Transition {}

        model: ScriptModel {
            objectProp: "uniqueId"
            values: root.enabled ? root.dockItems : []
        }

        delegate: DockAppButton {
            id: dockDelegate
            required property var modelData
            required property int index
            appToplevel: modelData
            appListRoot: root
            vertical: root.vertical
            dockPosition: root.dockPosition
            dockThicknessOverride: root.dockThickness

            anchors.verticalCenter: !root.vertical ? parent?.verticalCenter : undefined
            anchors.horizontalCenter: root.vertical ? parent?.horizontalCenter : undefined

            topInset: 0
            bottomInset: 0
            leftInset: 0
            rightInset: 0

            readonly property bool isBeingDragged: root.dragActive && root.dragIndex === index
            readonly property bool isDropTarget: root.dragActive && root.dropTargetIndex === index && root.dragIndex !== index
            readonly property bool isDropSettling: !isBeingDragged && root.dropSettleId !== "" && root.dropSettleId === appToplevel?.uniqueId
            readonly property real dragDisplacement: root.getDragDisplacement(index)

            property real _dragOffsetX: isBeingDragged ? (root.dragCurrentX - root.dragStartX) : 0
            property real _dragOffsetY: isBeingDragged ? (root.dragCurrentY - root.dragStartY) : 0

            transform: Translate {
                id: dockDelegateTranslate
                x: dockDelegate.isBeingDragged
                    ? (root.vertical ? 0 : dockDelegate._dragOffsetX)
                    : dockDelegate.isDropSettling
                        ? (root.vertical ? 0 : root.dropSettleOffsetX)
                        : (root.vertical ? 0 : dockDelegate.dragDisplacement)
                y: dockDelegate.isBeingDragged
                    ? (root.vertical ? dockDelegate._dragOffsetY : 0)
                    : dockDelegate.isDropSettling
                        ? (root.vertical ? root.dropSettleOffsetY : 0)
                        : (root.vertical ? dockDelegate.dragDisplacement : 0)

                Behavior on x {
                    enabled: Appearance.animationsEnabled && !root.dropSettlingActive && !dockDelegate.isBeingDragged && !dockDelegate.isDropSettling
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled && !root.dropSettlingActive && !dockDelegate.isBeingDragged && !dockDelegate.isDropSettling
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
            }

            z: isBeingDragged ? 100 : 0
            dragEmphasis: isBeingDragged

            opacity: isBeingDragged ? 0.8
                   : root.dragActive ? 0.85 : 1.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Rectangle {
                id: insertionLine
                visible: dockDelegate.isDropTarget && !dockDelegate.isSeparator
                z: 50

                readonly property bool forward: root.dragIndex >= 0
                    && root.dragIndex < root.dropTargetIndex

                width: root.vertical ? (parent.width * 0.55) : 3
                height: root.vertical ? 3 : (parent.height * 0.55)
                radius: 1.5

                x: root.vertical
                    ? (parent.width - width) / 2
                    : (forward
                        ? parent.width + (listView.spacing - width) / 2
                        : -(listView.spacing + width) / 2)
                y: root.vertical
                    ? (forward
                        ? parent.height + (listView.spacing - height) / 2
                        : -(listView.spacing + height) / 2)
                    : (parent.height - height) / 2

                color: Appearance.colors.colPrimary
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                opacity: dockDelegate.isDropTarget ? 0.9 : 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            property real _pressMouseX: 0
            property real _pressMouseY: 0
            property bool _hasPressPos: false
            property bool _dragPrimed: false
            property bool _longPressTriggered: false

            downAction: event => {
                if (!root.dragEnabled || dockDelegate.isSeparator) return
                _longPressTriggered = false
                _dragPrimed = false
                _pressMouseX = event.x
                _pressMouseY = event.y
                _hasPressPos = true
                _dockPrimeTimer.restart()
            }

            moveAction: (event) => {
                if (!dockDelegate.down) return
                if (!_hasPressPos) return

                const dx = event.x - _pressMouseX
                const dy = event.y - _pressMouseY
                const dist2 = dx * dx + dy * dy

                if (_dockPrimeTimer.running && !_dragPrimed) {
                    if (dist2 > root.dragThreshold * root.dragThreshold) {
                        _dockPrimeTimer.stop()
                    }
                    return
                }

                if (_dragPrimed && !root.dragActive
                        && dist2 > root.dragThreshold * root.dragThreshold) {
                    _longPressTriggered = true
                    const listPos = dockDelegate.mapToItem(listView, _pressMouseX, _pressMouseY)
                    const appId = dockDelegate.appToplevel?.originalAppId
                        ?? dockDelegate.appToplevel?.appId ?? ""
                    root.startDrag(dockDelegate.index, appId, listPos.x, listPos.y)
                }

                if (root.dragActive && root.dragIndex === dockDelegate.index) {
                    const listPos = dockDelegate.mapToItem(listView, event.x, event.y)
                    root.updateDrag(listPos.x, listPos.y)
                }
            }

            releaseAction: () => {
                _dockPrimeTimer.stop()
                _dragPrimed = false
                if (dockDelegate._longPressTriggered) {
                    if (root.dragActive && root.dragIndex === dockDelegate.index) {
                        root.endDrag()
                    }
                    root._suppressNextClick = true
                    Qt.callLater(() => {
                        if (root._suppressNextClick)
                            root._suppressNextClick = false
                    })
                    dockDelegate._longPressTriggered = false
                }
            }

            Timer {
                id: _dockPrimeTimer
                interval: 180
                onTriggered: {
                    dockDelegate._dragPrimed = true
                }
            }

            onHoverPreviewRequested: {
                if (!root.dragActive) {
                    root.showPreviewPopup(appToplevel, this)
                }
            }
            onHoverPreviewDismissed: {
                dockPreviewPopup.close()
            }
        }
    }

    DockPreview {
        id: dockPreviewPopup
        dockHovered: root.buttonHovered
        dockPosition: root.dockPosition
        anchor.window: root.parentWindow
    }
}
