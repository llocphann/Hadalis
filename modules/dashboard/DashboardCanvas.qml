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
    property bool showStandaloneEditButton: false
    signal requestEventsDialog(var event)

    readonly property int gridSize: Math.max(8,
        Number(Config.options?.dashboard?.canvas?.gridSize ?? 24))
    readonly property bool snapEnabled:
        Config.options?.dashboard?.canvas?.snap ?? true
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

    readonly property var visibleIds: root._allIds.filter(id =>
        root.geometryFor(id).visible !== false)
    readonly property var hiddenIds: root._allIds.filter(id =>
        root.geometryFor(id).visible === false)

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
        root._persistPatch(id, { visible: visible })
        if (!visible && root.selectedId === id)
            root.selectedId = ""
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
        default: return { width: 200, height: 80 }
        }
    }

    function _rectPixels(id) {
        const g = root.geometryFor(id)
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

    function beginMove(id, point) {
        root.selectedId = id
        root._interaction = {
            id: id,
            kind: "move",
            startPoint: point,
            startRect: root._rectPixels(id)
        }
    }

    function beginResize(id, edge, point) {
        root.selectedId = id
        root._interaction = {
            id: id,
            kind: "resize",
            edge: edge,
            startPoint: point,
            startRect: root._rectPixels(id)
        }
    }

    function updateInteraction(point) {
        const state = root._interaction
        if (!state)
            return

        const dx = point.x - state.startPoint.x
        const dy = point.y - state.startPoint.y
        const start = state.startRect
        const requestedMin = root._minimumSize(state.id)
        const min = {
            width: Math.min(canvas.width, requestedMin.width),
            height: Math.min(canvas.height, requestedMin.height)
        }
        let left = start.x
        let top = start.y
        let right = start.x + start.width
        let bottom = start.y + start.height

        if (state.kind === "move") {
            left = root._snap(start.x + dx)
            top = root._snap(start.y + dy)
            left = Math.max(0, Math.min(canvas.width - start.width, left))
            top = Math.max(0, Math.min(canvas.height - start.height, top))
            root._setPreview(state.id, {
                x: left, y: top,
                width: start.width, height: start.height
            })
            return
        }

        const edge = String(state.edge ?? "")
        if (edge.indexOf("w") >= 0)
            left = root._snap(start.x + dx)
        if (edge.indexOf("e") >= 0)
            right = root._snap(start.x + start.width + dx)
        if (edge.indexOf("n") >= 0)
            top = root._snap(start.y + dy)
        if (edge.indexOf("s") >= 0)
            bottom = root._snap(start.y + start.height + dy)

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

        root._setPreview(state.id, {
            x: left, y: top,
            width: Math.max(1, right - left),
            height: Math.max(1, bottom - top)
        })
    }

    function finishInteraction(commit) {
        const state = root._interaction
        if (!state)
            return
        const id = state.id
        if (commit && root._preview[id] !== undefined) {
            const g = root._preview[id]
            root._persistPatch(id, {
                x: g.x, y: g.y, w: g.w, h: g.h
            })
        }
        root._clearPreview(id)
        root._interaction = null
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

        Repeater {
            model: root.visibleIds

            delegate: Item {
                id: cardWrap
                required property var modelData
                readonly property var px: root._rectPixels(String(modelData))
                readonly property bool selected:
                    root.editMode && root.selectedId === String(modelData)

                x: px.x
                y: px.y
                width: px.width
                height: px.height
                z: selected ? 30 : 1

                Item {
                    id: cardViewport
                    anchors.fill: parent
                    clip: true

                    Loader {
                        anchors.fill: parent
                        sourceComponent: root._widgetMap[String(cardWrap.modelData)] ?? null
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
                    hoverEnabled: true
                    preventStealing: true
                    z: 20
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
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

        Rectangle {
            id: editToolbar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            visible: root.editMode
            z: 100
            width: Math.min(parent.width - 20,
                Math.max(360, toolbarColumn.implicitWidth + 20))
            height: toolbarColumn.implicitHeight + 16
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant

            StyledRectangularShadow { target: editToolbar }

            ColumnLayout {
                id: toolbarColumn
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: root.selectedId.length > 0
                            ? Translation.tr("Editing %1").arg(root._label(root.selectedId))
                            : Translation.tr("Edit widgets")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }

                    EditToolButton {
                        iconName: root.snapEnabled ? "grid_on" : "grid_off"
                        tooltipText: root.snapEnabled
                            ? Translation.tr("Snap to grid: on")
                            : Translation.tr("Snap to grid: off")
                        toggled: root.snapEnabled
                        onClicked: Config.setNestedValue(
                            "dashboard.canvas.snap", !root.snapEnabled)
                    }
                    EditToolButton {
                        iconName: root.gridStyle === "lines"
                            ? "grid_4x4"
                            : (root.gridStyle === "cross"
                                ? "add" : "drag_indicator")
                        tooltipText: Translation.tr("Grid style: %1 — click to cycle")
                            .arg(root.gridStyle)
                        onClicked: root._cycleGridStyle()
                    }
                    EditToolButton {
                        iconName: "grid_view"
                        tooltipText: Translation.tr("Grid size: %1px — click to cycle")
                            .arg(root.gridSize)
                        onClicked: root._cycleGridSize()
                    }
                    EditToolButton {
                        iconName: "restart_alt"
                        tooltipText: Translation.tr("Reset dashboard layout")
                        onClicked: root.resetLayout()
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.hiddenIds.length > 0
                    spacing: 6

                    Repeater {
                        model: root.hiddenIds
                        delegate: RippleButton {
                            required property var modelData
                            implicitHeight: 30
                            implicitWidth: addRow.implicitWidth + 16
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colLayer2
                            onClicked: root.setWidgetVisible(String(modelData), true)

                            RowLayout {
                                id: addRow
                                anchors.centerIn: parent
                                spacing: 5
                                MaterialSymbol {
                                    text: root._icon(String(modelData))
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledText {
                                    text: root._label(String(modelData))
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnLayer2
                                }
                                MaterialSymbol {
                                    text: "add"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colPrimary
                                }
                            }
                        }
                    }
                }
            }
        }

        RippleButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            visible: root.showStandaloneEditButton
            z: 110
            implicitWidth: 40
            implicitHeight: 40
            buttonRadius: root.editMode
                ? Appearance.rounding.normal : Appearance.rounding.full
            colBackground: root.editMode
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colLayer2
            onClicked: root.editMode = !root.editMode
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.editMode ? "done" : "edit"
                iconSize: Appearance.font.pixelSize.larger
                color: root.editMode
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colOnLayer2
            }
            StyledToolTip {
                text: root.editMode
                    ? Translation.tr("Done")
                    : Translation.tr("Edit widgets")
            }
        }
    }

    component EditToolButton: RippleButton {
        id: tool
        property alias iconName: toolIcon.text
        property string tooltipText: ""
        implicitWidth: 34
        implicitHeight: 34
        buttonRadius: Appearance.rounding.full
        colBackground: toggled
            ? Appearance.colors.colPrimaryContainer
            : Appearance.colors.colLayer2
        contentItem: MaterialSymbol {
            id: toolIcon
            anchors.centerIn: parent
            iconSize: Appearance.font.pixelSize.normal
            color: tool.toggled
                ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnLayer2
        }
        StyledToolTip { text: tool.tooltipText }
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
        width: corner ? 12 : (horizontal ? 34 : 10)
        height: corner ? 12 : (vertical ? 34 : 10)
        radius: corner ? 3 : Appearance.rounding.full
        color: Appearance.colors.colPrimary
        border.width: 1
        border.color: Appearance.colors.colOnPrimary

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
            preventStealing: true
            cursorShape: {
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
