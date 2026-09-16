import QtQuick
import qs.modules.common

// Quick settings facade for the Hug-only Classic Bar policy. The legacy page
// remains loadable for config compatibility, but alternate corner styles are no
// longer user-facing.
QuickConfig {
    id: root

    property bool _hugUiReady: false
    opacity: root._hugUiReady ? 1 : 0

    function _applyHugOnlyUi(item): void {
        if (!item)
            return

        if (String(item.title ?? "") === Translation.tr("Bar style")) {
            item.visible = false
            return
        }

        const children = item.children ?? []
        for (let i = 0; i < children.length; i++)
            root._applyHugOnlyUi(children[i])
    }

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: {
            root._applyHugOnlyUi(root)
            root._hugUiReady = true
        }
    }
}
