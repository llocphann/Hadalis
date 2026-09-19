import QtQuick
import qs.services
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
                || text === Translation.tr("Float shadow")
                || text === Translation.tr("Show background")) {
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
            ConfigRow {
                uniform: true

                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Screen edge width (px)")
                    value: Config.options?.appearance?.screenEdge?.width ?? 10
                    from: 1
                    to: 32
                    stepSize: 1
                    onValueChanged: Config.setNestedValue(
                        "appearance.screenEdge.width", value)
                }

                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Corner radius (px)")
                    value: Config.options?.appearance?.screenEdge?.radius ?? 25
                    from: 0
                    to: 96
                    stepSize: 1
                    onValueChanged: Config.setNestedValue(
                        "appearance.screenEdge.radius", value)
                }
            }

            SettingsSwitch {
                buttonIcon: "shadow"
                text: Translation.tr("Screen edge shadow")
                checked: Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
                onCheckedChanged: Config.setNestedValue(
                    "appearance.screenEdge.physicalShadow.enabled", checked)
            }

            ConfigRow {
                uniform: true

                ConfigSpinBox {
                    icon: "blur_on"
                    text: Translation.tr("Shadow size (px)")
                    value: Config.options?.appearance?.screenEdge?.physicalShadow?.size ?? 15
                    from: 0
                    to: 32
                    stepSize: 1
                    enabled: Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
                    opacity: enabled ? 1 : 0.5
                    onValueChanged: Config.setNestedValue(
                        "appearance.screenEdge.physicalShadow.size", value)
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Shadow opacity (%)")
                    value: Math.round(
                        (Config.options?.appearance?.screenEdge?.physicalShadow?.opacity ?? 0.70) * 100)
                    from: 0
                    to: 100
                    stepSize: 2
                    enabled: Config.options?.appearance?.screenEdge?.physicalShadow?.enabled ?? true
                    opacity: enabled ? 1 : 0.5
                    onValueChanged: Config.setNestedValue(
                        "appearance.screenEdge.physicalShadow.opacity", value / 100)
                }
            }

            SettingsNote {
                icon: "info"
                text: Translation.tr("The screen edge stays visible on the desktop and maximized windows. True fullscreen and lock screen hide it.")
            }
        }
    }
}
