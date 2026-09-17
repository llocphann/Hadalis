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

    readonly property bool thinkFanManaged:
        ThinkFanService.stateKnown && ThinkFanService.profile === "managed"
    readonly property bool thinkFanCanApply:
        ThinkFanService.stateKnown
        && ThinkFanService.serviceInstalled
        && !ThinkFanService.busy
        && (root.thinkFanManaged || ThinkFanService.available)

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

    SettingsCardSection {
        settingsTaskSection: "modules"
        visible: root.isIiActive && root.activeSection === "modules"
        expanded: true
        icon: "mode_fan"
        title: Translation.tr("System Monitor & Thermals")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "mode_fan"
                text: Translation.tr("ThinkFan managed control")
                description: Translation.tr("Use ThinkFan for fan control instead of firmware control. Changing profile may require administrator authorization.")
                autoToggle: false
                checked: root.thinkFanManaged
                enabled: root.thinkFanCanApply
                onToggledByUser: nextChecked => ThinkFanService.applyProfile(
                    nextChecked ? "managed" : "firmware")
            }

            SettingsNote {
                icon: ThinkFanService.serviceInstalled ? "thermostat" : "info"
                warning: ThinkFanService.stateKnown
                    && (!ThinkFanService.serviceInstalled
                        || ThinkFanService.statusReason.length > 0)
                text: !ThinkFanService.stateKnown
                    ? Translation.tr("Checking ThinkFan status…")
                    : !ThinkFanService.serviceInstalled
                        ? Translation.tr("thinkfan.service is unavailable; system monitoring remains available without fan controls.")
                    : ThinkFanService.busy
                        ? Translation.tr("Applying fan control profile…")
                    : root.thinkFanManaged
                        ? Translation.tr("ThinkFan is managing the fan. Changes here are reflected immediately in System Monitor.")
                        : ThinkFanService.available
                            ? Translation.tr("Firmware controls the fan. Changes here are reflected immediately in System Monitor.")
                            : Translation.tr("ThinkFan is unavailable; firmware control remains active.")
            }
        }
    }
}