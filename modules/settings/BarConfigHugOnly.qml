import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Public Classic Bar settings facade. The legacy BarConfig implementation is
// kept intact for compatibility, while retired surface choices are removed from
// the user-facing page. Runtime config is normalized to Hug by
// SettingsPageRegistry before this page is materialized.
BarConfig {
    id: root

    // Never gate the whole page on the post-construction compatibility pass.
    // SettingsPageHost may expose this Loader before the zero-delay Timer runs;
    // keeping opacity at 0 in that window made a successfully loaded Bar page
    // indistinguishable from an empty page. The pass below only hides retired
    // controls and is safe to apply after the page is already visible.

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
        onTriggered: root._applyHugOnlyUi(root)
    }

    SettingsCardSection {
        settingsTaskSection: "appearance"
        visible: root.isIiActive && root.activeSection === "appearance"
        expanded: true
        icon: "border_outer"
        title: Translation.tr("Screen Edge")

        SettingsGroup {
            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Screen edge width (px)")
                value: Config.options?.appearance?.screenEdge?.width ?? 10
                from: 1
                to: 32
                stepSize: 1
                onValueChanged: Config.setNestedValue("appearance.screenEdge.width", value)
            }

            SettingsNote {
                icon: "info"
                text: Translation.tr("The screen edge stays visible on the desktop and maximized windows. True fullscreen and lock screen hide it.")
            }
        }
    }
}
