import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    readonly property bool sinkAvailable: !!Audio.sink?.audio

    name: Translation.tr("Audio output")
    statusText: !root.sinkAvailable
        ? Translation.tr("Unavailable")
        : toggled ? Translation.tr("Unmuted") : Translation.tr("Muted")
    toggled: root.sinkAvailable && !Audio.sink.audio.muted
    buttonIcon: root.toggled ? "volume_up" : "volume_off"
    mainAction: () => {
        Audio.toggleMute()
    }

    altAction: () => {
        root.openMenu()
    }

    StyledToolTip {
        text: Translation.tr("Audio output | Right-click for volume mixer & device selector")
    }
}
