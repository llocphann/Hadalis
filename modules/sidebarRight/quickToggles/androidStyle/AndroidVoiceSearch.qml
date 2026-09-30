import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import qs.services

AndroidQuickToggleButton {
    id: root

    Component.onCompleted: VoiceSearch.ensureInitialized()

    toggled: VoiceSearch.running
    // Must stay clickable in edit mode without a configured backend, otherwise
    // the toggle can never be unpinned.
    enabled: root.editMode || VoiceSearch.hasBackend

    name: Translation.tr("Voice Search")
    statusText: {
        if (!VoiceSearch.hasBackend) return VoiceSearch.backendLabel
        if (VoiceSearch.transcribing) return Translation.tr("Transcribing...")
        if (VoiceSearch.recording) return Translation.tr("Listening...")
        return VoiceSearch.backendLabel
    }
    buttonIcon: VoiceSearch.running ? "hearing" : "keyboard_voice"

    StyledToolTip {
        text: Translation.tr("Voice search | %1").arg(VoiceSearch.backendLabel)
    }

    mainAction: () => {
        VoiceSearch.toggle()
    }
}
