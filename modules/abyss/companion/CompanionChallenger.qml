import QtQuick

// Only the hidden Octo's tentacles appear during the outgoing Aqua's action.
// No second body, input region or independent presentation clock is created.
Item {
    id:root
    required property var turns
    required property var actor
    readonly property bool active:turns.pulling
    Binding {target:root.actor;property:"tentacleGrip";value:root.active}
    Binding {target:root.actor;property:"gripProgress";value:root.turns.progress}
}
