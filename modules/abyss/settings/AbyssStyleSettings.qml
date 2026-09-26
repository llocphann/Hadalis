import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 16

    SettingsCardSection {
        expanded: true
        icon: "water"
        settingsTaskSection: "abyss"
        title: "Abyss Style"

        SettingsGroup {
            SettingsNote {
                icon: "water"
                text: "The screen edge is the shell. Panels grow inward from one liquid perimeter."
            }
            ContentSubsectionLabel {
                text: "Performance"
            }
            ConfigSelectionArray {
                currentValue: Config.options?.abyss?.quality ?? "balanced"
                options: [
                    {
                        displayName: "Performance",
                        icon: "speed",
                        value: "performance"
                    },
                    {
                        displayName: "Balanced",
                        icon: "tune",
                        value: "balanced"
                    },
                    {
                        displayName: "Quality",
                        icon: "auto_awesome",
                        value: "quality"
                    }
                ]

                onSelected: value => Config.setNestedValue("abyss.quality", value)
            }
            SettingsNote {
                icon: "info"
                text: "Performance keeps a palette surface. Balanced adds wallpaper glass. Quality allows refraction and a restrained settle."
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "opacity"
        settingsTaskSection: "abyss"
        title: "Surface"

        SettingsGroup {
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 65
                stepSize: 1
                text: "Glass opacity"
                to: 100
                value: (Config.options?.abyss?.surface?.opacity ?? 0.91) * 100

                onMoved: Config.setNestedValue("abyss.surface.opacity", value / 100)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 0
                stepSize: 1
                text: "Surface tension"
                to: 100
                value: (Config.options?.abyss?.surface?.tension ?? 0.5) * 100

                onMoved: Config.setNestedValue("abyss.surface.tension", value / 100)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 4
                stepSize: 1
                text: "Connection softness"
                to: 48
                value: Config.options?.abyss?.surface?.softness ?? 24

                onMoved: Config.setNestedValue("abyss.surface.softness", value)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 0
                stepSize: 1
                text: "Surface highlight"
                to: 100
                value: (Config.options?.abyss?.effects?.surfaceHighlight ?? 0.45) * 100

                onMoved: Config.setNestedValue("abyss.effects.surfaceHighlight", value / 100)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                enabled: (Config.options?.abyss?.quality ?? "balanced") !== "performance"
                from: 0
                stepSize: 1
                text: "Glow"
                to: 30
                value: (Config.options?.abyss?.effects?.glow?.strength ?? 0.08) * 100

                onMoved: Config.setNestedValue("abyss.effects.glow.strength", value / 100)
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "animation"
        settingsTaskSection: "abyss"
        title: "Motion"

        SettingsGroup {
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 0
                stepSize: 1
                text: "Motion intensity"
                to: 100
                value: (Config.options?.abyss?.motion?.intensity ?? 0.6) * 100

                onMoved: Config.setNestedValue("abyss.motion.intensity", value / 100)
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "motion_photos_off"
                checked: Config.options?.performance?.reduceAnimations ?? false
                text: "Reduce animations (all families)"

                onToggledByUser: checked => Config.setNestedValue("performance.reduceAnimations", checked)
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "blur_on"
        settingsTaskSection: "abyss"
        title: "Refraction & Glass"

        SettingsGroup {
            SettingsNote {
                icon: "image"
                text: "Glass follows the selected static wallpaper. Videos and GIFs use the palette surface."
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "blur_on"
                checked: Config.options?.abyss?.effects?.blur?.enabled ?? true
                enabled: (Config.options?.abyss?.quality ?? "balanced") !== "performance"
                text: "Wallpaper blur"

                onToggledByUser: checked => Config.setNestedValue("abyss.effects.blur.enabled", checked)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                enabled: (Config.options?.abyss?.effects?.blur?.enabled ?? true) && (Config.options?.abyss?.quality ?? "balanced") !== "performance"
                from: 0
                stepSize: 1
                text: "Blur radius"
                to: 24
                value: Config.options?.abyss?.effects?.blur?.radius ?? 10

                onMoved: Config.setNestedValue("abyss.effects.blur.radius", value)
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "waves"
                checked: Config.options?.abyss?.effects?.refraction?.enabled ?? false
                enabled: Config.options?.abyss?.quality === "quality"
                text: "Refraction (Quality)"

                onToggledByUser: checked => Config.setNestedValue("abyss.effects.refraction.enabled", checked)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                enabled: Config.options?.abyss?.quality === "quality" && (Config.options?.abyss?.effects?.refraction?.enabled ?? false)
                from: 0
                stepSize: 1
                text: "Refraction strength"
                to: 16
                value: Config.options?.abyss?.effects?.refraction?.strength ?? 6

                onMoved: Config.setNestedValue("abyss.effects.refraction.strength", value)
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "crop_free"
        settingsTaskSection: "abyss"
        title: "Perimeter"

        SettingsGroup {
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 3
                stepSize: 1
                text: "Edge thickness"
                to: 24
                value: Config.options?.abyss?.perimeter?.thickness ?? 8

                onMoved: Config.setNestedValue("abyss.perimeter.thickness", value)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 12
                stepSize: 1
                text: "Workspace corner radius"
                to: 64
                value: Config.options?.abyss?.perimeter?.radius ?? 34

                onMoved: Config.setNestedValue("abyss.perimeter.radius", value)
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "fullscreen"
                checked: Config.options?.abyss?.perimeter?.visibleInFullscreen ?? false
                text: "Visible during fullscreen"

                onToggledByUser: checked => Config.setNestedValue("abyss.perimeter.visibleInFullscreen", checked)
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "dock_to_bottom"
        settingsTaskSection: "abyss"
        title: "Bar & Dock"

        SettingsGroup {
            ContentSubsectionLabel {
                text: "Bar edge"
            }
            ConfigSelectionArray {
                currentValue: (Config.options?.bar?.vertical ? 2 : 0) + (Config.options?.bar?.bottom ? 1 : 0)
                options: [
                    {
                        displayName: "Top",
                        value: 0
                    },
                    {
                        displayName: "Bottom",
                        value: 1
                    },
                    {
                        displayName: "Left",
                        value: 2
                    },
                    {
                        displayName: "Right",
                        value: 3
                    }
                ]

                onSelected: value => Config.setNestedValues({
                        "bar.vertical": value >= 2,
                        "bar.bottom": value % 2 === 1
                    })
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "toolbar"
                checked: Config.options?.bar?.autoHide?.enable ?? false
                text: "Auto-hide bar"

                onToggledByUser: checked => Config.setNestedValue("bar.autoHide.enable", checked)
            }
            BarModuleOrderEditor {
                verticalPreset: Config.options?.bar?.vertical ?? false
            }
            AbyssOutputSelector {
                configPath: "bar.screenList"
                title: "Bar outputs"
            }
            ContentSubsectionLabel {
                text: "Dock edge"
            }
            ConfigSelectionArray {
                currentValue: Config.options?.dock?.position ?? "bottom"
                options: [
                    {
                        displayName: "Top",
                        value: "top"
                    },
                    {
                        displayName: "Bottom",
                        value: "bottom"
                    },
                    {
                        displayName: "Left",
                        value: "left"
                    },
                    {
                        displayName: "Right",
                        value: "right"
                    }
                ]

                onSelected: value => Config.setNestedValue("dock.position", value)
            }
            WindowDialogSlider {
                Layout.fillWidth: true
                from: 52
                stepSize: 1
                text: "Dock depth"
                to: 100
                value: Config.options?.dock?.height ?? 70

                onMoved: Config.setNestedValue("dock.height", value)
            }
            AbyssOutputSelector {
                configPath: "dock.screenList"
                title: "Dock outputs"
            }
            ConfigSwitch {
                autoToggle: false
                buttonIcon: "keep"
                checked: Config.options?.dock?.pinnedOnStartup ?? false
                text: "Pin dock"

                onToggledByUser: checked => Config.setNestedValues({
                        "dock.pinnedOnStartup": checked,
                        "dock.hoverToReveal": !checked
                    })
            }
        }
    }
    SettingsCardSection {
        expanded: true
        icon: "side_navigation"
        settingsTaskSection: "abyss"
        title: "Panels"

        SettingsGroup {
            SettingsNote {
                icon: "settings"
                text: "Choose active Abyss surfaces in Modules. Lock, session and specialist flows keep their shared controls."
            }
            AbyssOutputSelector {
                configPath: "sidebar.screenList"
                title: "Sidebar outputs"
            }
            AbyssOutputSelector {
                configPath: "notifications.screenList"
                title: "Notification outputs"
            }
            AbyssOutputSelector {
                configPath: "osd.screenList"
                title: "OSD outputs"
            }
        }
    }
}
