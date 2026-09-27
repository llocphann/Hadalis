import QtQuick
import Quickshell

// One controller per output. Content and input are not inferred from pixels.
QtObject {
    id: root
    property string outputName: ""
    property var participants: ({})
    property var moduleRecords: []
    property real outputWidth: 1920
    property real outputHeight: 1080
    property bool presented: true
    property Item presentationItem: null
    property var edgeInsets: ({left:16,top:48,right:16,bottom:16})
    property var popupHost: null
    property var activePopup: null
    property Item popupHome: null
    function presentPopup(popup): void {
        if (!popup || !popupHost || !popup.contentItem || activePopup === popup) return
        if (activePopup) activePopup.dismissPresentation()
        popupHome = popup.contentItem.parent
        activePopup = popup
        const item = popup.contentItem
        item.parent = popupHost.contentParent
        item.x = 0; item.y = 0
        item.width = Qt.binding(() => popupHost.contentParent.width)
        item.height = Qt.binding(() => popupHost.contentParent.height)
        item.visible = Qt.binding(() => popup.presentationActive)
        popup.presentationWindow = presentationItem?.QsWindow?.window ?? null
    }
    function releasePopup(popup, restore = true): void {
        if (activePopup !== popup) return
        const home = popupHome
        activePopup = null; popupHome = null
        popup.presentationWindow = null
        popup._bodyHovered = false; popup._contentHovered = false
        if (restore && popup.contentItem) {
            popup.contentItem.parent = home
            popup.contentItem.visible = Qt.binding(() => popup.presentationActive)
        }
    }
    onPresentedChanged: if (!presented && activePopup) activePopup.dismissPresentation()
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
