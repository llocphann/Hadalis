pragma ComponentBehavior: Bound

import qs
import qs.modules.sidebarRight.notepad

// Sidebar Left intentionally delegates the full Quick Notes experience to the
// same presentation used by Dashboard. Keep this wrapper only for Sidebar
// lifecycle behavior so visual/editor changes remain single-source.
QuickNotesView {
    id: root

    preferredHeight: 210
    surfaceLocalTabSelection: true
    showZettelkastenActions: true
    margin: 0

    Connections {
        target: GlobalStates

        function onSidebarLeftOpenChanged(): void {
            if (GlobalStates.sidebarLeftOpen)
                return
            root.flushPendingSave()
            root.releaseEditorFocus()
        }
    }
}
