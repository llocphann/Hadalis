import QtQuick

AnchorPublisher {
    id: root

    required property var perimeterContext
    property int extraRefreshToken: 0

    outputName: String(perimeterContext?.outputName ?? "")
    slotId: String(perimeterContext?.slotId ?? "")
    instanceId: String(perimeterContext?.instanceId ?? "")
    moduleId: String(perimeterContext?.moduleId ?? "")
    referenceItem: perimeterContext?.slotItem ?? null
    referenceRect: perimeterContext?.slotRect ?? Qt.rect(0, 0, 0, 0)
    refreshToken: Number(perimeterContext?.layoutRevision ?? 0)
        + root.extraRefreshToken
}
