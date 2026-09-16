import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    readonly property bool sourceAvailable: !!Audio.source?.audio

    name: Translation.tr("Audio input")
    statusText: !root.sourceAvailable
        ? Translation.tr("Unavailable")
        : toggled ? Translation.tr("Enabled") : Translation.tr("Muted")
    toggled: root.sourceAvailable && !Audio.micMuted
    buttonIcon: root.toggled ? "mic" : "mic_off"
    mainAction: () => {
        Audio.toggleMicMute()
    }

    altAction: () => {
        root.openMenu()
    }

    StyledToolTip {
        text: Translation.tr("Audio input | Right-click for volume mixer & device selector")
    }
}
