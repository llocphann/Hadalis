import QtQuick

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
