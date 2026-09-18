import QtQuick
import qs.modules.common

// Quick settings facade for the Hug-only Classic Bar policy. The legacy page
// remains loadable for config compatibility, but alternate corner styles are no
// longer user-facing.
QuickConfig {
    id: root

    // Do not gate the whole page on this post-construction compatibility pass.
    // SettingsPageHost can expose a ready Loader before a zero-delay Timer fires;
    // hiding the entire page in that window makes a valid Quick page look blank.
    // The pass only hides the retired Bar-style card, so it is safe to run after
    // the page has already become visible.

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
        onTriggered: root._applyHugOnlyUi(root)
    }
}
