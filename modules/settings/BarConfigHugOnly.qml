import QtQuick
import qs.modules.common

// Public Classic Bar settings facade. The legacy BarConfig implementation is
// kept intact for compatibility, while retired surface choices are removed from
// the user-facing page. Runtime config is normalized to Hug by
// SettingsPageRegistry before this page is materialized.
BarConfig {
    id: root

    property bool _hugUiReady: false
    opacity: root._hugUiReady ? 1 : 0

    function _applyHugOnlyUi(item): void {
        if (!item)
            return

        const title = String(item.title ?? "")
        const text = String(item.text ?? "")

        if (title === Translation.tr("Corner style")
                || text === Translation.tr("Float shadow")) {
            item.visible = false
            return
        }

        if (text === Translation.tr("Classic is the only bar appearance. Position and corner style change its geometry without switching renderer families.")) {
            item.text = Translation.tr("Classic Bar uses the Hug surface. Position only changes which screen edge it hugs.")
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
