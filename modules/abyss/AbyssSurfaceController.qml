import QtQuick
import Quickshell
import "looks/AbyssBodyPlacement.js" as BodyPlacement

// One controller per output. Content and input are not inferred from pixels.
QtObject {
    id: root
    property string outputName: ""
    property var participants: ({})
    property var moduleRecords: []
    property int presentationOrder: 0
    function nextPresentationOrder(): int { return ++presentationOrder }
    readonly property var bodyPlacements: BodyPlacement.arrange(Object.keys(participants)
        .map(key => participants[key]?.placementRequest).filter(request => request !== null && request !== undefined),
        outputWidth,outputHeight,edgeInsets)
    property real outputWidth: 1920
    property real outputHeight: 1080
    property bool presented: true
    property Item presentationItem: null
    property var edgeInsets: ({left:16,top:48,right:16,bottom:16})
    // Backward-compatible single host used by isolated tests/legacy callers.
    // Production Abyss registers stable popup slots instead, allowing several
    // mature StyledPopup instances to coexist without dismissing each other.
    property var popupHost: null
    readonly property int popupCapacity: 4
    property var popupSlots: [null, null, null, null]
    property var popupHosts: ({})
    property int popupOrder: 0
    readonly property var popupEntries: popupSlots.filter(entry => entry !== null)
        .sort((a,b) => a.order-b.order)
    readonly property var activePopups: popupEntries.map(entry => entry.popup)
    readonly property var activePopup: popupEntries.length > 0
        ? popupEntries[popupEntries.length-1].popup : null
    readonly property Item popupHome: popupEntries.length > 0
        ? popupEntries[popupEntries.length-1].home : null
    readonly property bool popupsOpen: popupEntries.some(entry =>
        entry.popup?.presentationActive ?? false)
    readonly property var popupInputBounds: popupSlots.map((entry,index) => {
        if (!entry) return null
        return participants["styledPopup" + index]?.inputBounds ?? null
    }).filter(rect => rect && rect.width > 0 && rect.height > 0)
    readonly property bool popupExclusiveFocus: popupSlots.some((entry,index) => {
        if (!entry || !(entry.popup?.keyboardFocus ?? false)) return false
        const rect = participants["styledPopup" + index]?.inputBounds
        return rect && rect.width > 0 && rect.height > 0
    })
    readonly property bool popupOnDemandFocus: popupSlots.some((entry,index) => {
        if (!entry || !(entry.popup?.keyboardFocusOnDemand ?? false)) return false
        const rect = participants["styledPopup" + index]?.inputBounds
        return rect && rect.width > 0 && rect.height > 0
    })

    function _popupSlot(popup): int {
        for (let i=0; i<popupSlots.length; ++i)
            if (popupSlots[i]?.popup === popup) return i
        return -1
    }
    function _popupHost(index): var {
        return popupHosts[String(index)] ?? (index === 0 ? popupHost : null)
    }
    function _rehostPopup(index): void {
        const entry = popupSlots[index]
        const host = _popupHost(index)
        if (!entry || !host || !entry.popup?.contentItem) return
        const popup = entry.popup
        const item = popup.contentItem
        item.parent = host.contentParent
        item.x = 0
        item.y = 0
        item.width = Qt.binding(() => host.contentParent.width)
        item.height = Qt.binding(() => host.contentParent.height)
        item.visible = Qt.binding(() => popup.presentationActive)
        popup.presentationWindow = presentationItem?.QsWindow?.window ?? null
    }
    function registerPopupHost(index, host): void {
        if (index < 0 || index >= popupCapacity || !host) return
        const next = Object.assign({}, popupHosts)
        next[String(index)] = host
        popupHosts = next
        _rehostPopup(index)
    }
    function unregisterPopupHost(index, host): void {
        if (popupHosts[String(index)] !== host) return
        const entry = popupSlots[index]
        if (entry?.popup?.contentItem && entry.home
                && entry.popup.contentItem.parent === host.contentParent) {
            entry.popup.contentItem.parent = entry.home
            entry.popup.contentItem.visible = Qt.binding(() => entry.popup.presentationActive)
        }
        const next = Object.assign({}, popupHosts)
        delete next[String(index)]
        popupHosts = next
    }
    function presentPopup(popup): void {
        if (!popup || !popup.contentItem) return
        const existing = _popupSlot(popup)
        if (existing >= 0) {
            _rehostPopup(existing)
            return
        }

        let slot = -1
        for (let i=0; i<popupCapacity; ++i) {
            if (popupSlots[i] === null || popupSlots[i] === undefined) {
                slot = i
                break
            }
        }
        if (slot < 0) {
            // Four simultaneous mature popups is already beyond ordinary shell
            // use. If it happens, retract the oldest and retry without ever
            // stealing/destroying its content synchronously.
            const oldest = popupEntries[0]?.popup
            if (oldest && oldest !== popup) oldest.dismissPresentation()
            Qt.callLater(() => {
                if (popup.presentationActive && root._popupSlot(popup) < 0)
                    root.presentPopup(popup)
            })
            return
        }

        const next = popupSlots.slice()
        next[slot] = {
            popup: popup,
            home: popup.contentItem.parent,
            order: ++popupOrder
        }
        popupSlots = next
        popup.presentationWindow = presentationItem?.QsWindow?.window ?? null
        Qt.callLater(() => root._rehostPopup(slot))
    }
    function releasePopup(popup, restore = true): void {
        const slot = _popupSlot(popup)
        if (slot < 0) return
        const entry = popupSlots[slot]
        popup.presentationWindow = null
        popup._bodyHovered = false
        popup._contentHovered = false
        if (restore && popup.contentItem && entry?.home) {
            popup.contentItem.parent = entry.home
            popup.contentItem.visible = Qt.binding(() => popup.presentationActive)
        }
        const next = popupSlots.slice()
        next[slot] = null
        popupSlots = next
    }
    function dismissPopups(): void {
        activePopups.slice().reverse().forEach(popup => popup?.dismissPresentation())
    }
    function hasPopupOnEdge(edge): bool {
        return popupEntries.some(entry => (entry.popup?.presentationActive ?? false)
            && entry.popup?._attachmentEdge === edge)
    }
    onPresentedChanged: if (!presented) dismissPopups()
    property var activeDialog: null
    property Item dialogHome: null
    property var dialogHost: null
    function presentDialog(item): void {
        if (!item || !dialogHost || activeDialog === item) return
        if (activeDialog) activeDialog.dismiss()
        dialogHome = item.parent
        activeDialog = item
        item.parent = dialogHost.contentParent
        item.x = 0; item.y = 0
        item.width = Qt.binding(() => dialogHost.contentParent.width)
        item.height = Qt.binding(() => dialogHost.contentParent.height)
        item.forceActiveFocus()
    }
    function releaseDialog(item, restore = true): void {
        if (activeDialog !== item) return
        const home = dialogHome
        activeDialog = null
        dialogHome = null
        if (restore && home) {
            item.parent = home
            item.width = Qt.binding(() => home.width)
            item.height = Qt.binding(() => home.height)
        }
    }
    readonly property AbyssWaveController waves: AbyssWaveController {
        parent: root.presentationItem
        outputWidth: root.outputWidth
        outputHeight: root.outputHeight
        presented: root.presented
        records: root.records
    }
    readonly property int capacity: 40
    readonly property var records: moduleRecords.concat(Object.keys(participants)
        .map(key => participants[key]?.geometry ? Object.assign({},participants[key].geometry,{mass:participants[key].mass}) : null)
        .filter(rec => rec && rec.surface.width > 0 && rec.surface.height > 0))
    readonly property var inputBounds: Object.keys(participants)
        .map(key => participants[key]?.inputBounds)
        .filter(rect => rect && rect.width > 0 && rect.height > 0)

    function impulse(edge, along, span, strength, mass = 1, channel = "module"): void {
        waves.impulse(edge,along,span,strength,mass,channel)
    }

    function registerParticipant(key, participant): void {
        if (!key || !participant) return
        if (participants[key] && participants[key] !== participant) {
            console.error("[Abyss] duplicate participant", outputName, key)
            return
        }
        const next = Object.assign({}, participants)
        next[key] = participant
        participants = next
    }
    function unregisterParticipant(key, participant): void {
        if (participants[key] !== participant) return
        const next = Object.assign({}, participants)
        delete next[key]
        participants = next
    }
}
