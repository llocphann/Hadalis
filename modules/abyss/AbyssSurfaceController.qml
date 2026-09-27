import QtQuick

// One controller per output. Content and input are not inferred from pixels.
QtObject {
    id: root
    property string outputName: ""
    property var participants: ({})
    property var moduleRecords: []
    readonly property int capacity: 40
    readonly property var records: moduleRecords.concat(Object.keys(participants)
        .map(key => participants[key]?.geometry)
        .filter(rec => rec && rec.surface.width > 0 && rec.surface.height > 0))
    readonly property var inputBounds: Object.keys(participants)
        .map(key => participants[key]?.inputBounds)
        .filter(rect => rect && rect.width > 0 && rect.height > 0)

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
