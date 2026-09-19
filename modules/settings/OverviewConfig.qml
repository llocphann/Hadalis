import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root

    settingsPageIndex: 29
    settingsPageName: Translation.tr("Overview")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        settingsTaskSection: "overview"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "overview_key"
        title: Translation.tr("Overview")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Workspace hover")

                SettingsSwitch {
                    buttonIcon: "hovering"
                    text: Translation.tr("Open Overview when hovering a workspace")
                    checked: Config.options?.overview?.workspaceHover?.enable ?? true
                    onCheckedChanged: Config.setNestedValue(
                        "overview.workspaceHover.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Use the Bar workspace buttons as the Overview trigger")
                    }
                }

                ConfigRow {
                    uniform: true

                    ConfigSpinBox {
                        icon: "timer"
                        text: Translation.tr("Open delay (ms)")
                        value: Config.options?.overview?.workspaceHover?.delayMs ?? 280
                        from: 0
                        to: 1200
                        stepSize: 20
                        enabled: Config.options?.overview?.workspaceHover?.enable ?? true
                        onValueChanged: Config.setNestedValue(
                            "overview.workspaceHover.delayMs", value)
                    }

                    ConfigSpinBox {
                        icon: "timer_off"
                        text: Translation.tr("Close delay (ms)")
                        value: Config.options?.overview?.workspaceHover?.closeDelayMs ?? 220
                        from: 0
                        to: 1200
                        stepSize: 20
                        enabled: Config.options?.overview?.workspaceHover?.enable ?? true
                        onValueChanged: Config.setNestedValue(
                            "overview.workspaceHover.closeDelayMs", value)
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable workspace Overview")
                checked: Config.options?.overview?.enable ?? true
                onCheckedChanged: Config.setNestedValue("overview.enable", checked)
                StyledToolTip {
                    text: Translation.tr("Show the workspace Overview popup from Bar workspace hover")
                }
            }
            SettingsSwitch {
                buttonIcon: "dashboard"
                text: Translation.tr("Dashboard panel")
                checked: Config.options?.overview?.dashboard?.enable ?? false
                onCheckedChanged:
                    Config.setNestedValue("overview.dashboard.enable", checked)
                StyledToolTip { text: Translation.tr("Show a control center dashboard below workspace previews") }
            }
            SettingsSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Dashboard: Quick toggles")
                checked: Config.options?.overview?.dashboard?.showToggles ?? true
                onCheckedChanged: Config.setNestedValue("overview.dashboard.showToggles", checked)
                visible: Config.options?.overview?.dashboard?.enable ?? false
            }
            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Dashboard: Media player")
                checked: Config.options?.overview?.dashboard?.showMedia ?? true
                onCheckedChanged: Config.setNestedValue("overview.dashboard.showMedia", checked)
                visible: Config.options?.overview?.dashboard?.enable ?? false
            }
            SettingsSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Dashboard: Volume slider")
                checked: Config.options?.overview?.dashboard?.showVolume ?? true
                onCheckedChanged: Config.setNestedValue("overview.dashboard.showVolume", checked)
                visible: Config.options?.overview?.dashboard?.enable ?? false
            }
            SettingsSwitch {
                buttonIcon: "cloud"
                text: Translation.tr("Dashboard: Weather")
                checked: Config.options?.overview?.dashboard?.showWeather ?? true
                onCheckedChanged: Config.setNestedValue("overview.dashboard.showWeather", checked)
                visible: Config.options?.overview?.dashboard?.enable ?? false
            }
            SettingsSwitch {
                buttonIcon: "memory"
                text: Translation.tr("Dashboard: System stats")
                checked: Config.options?.overview?.dashboard?.showSystem ?? true
                onCheckedChanged: Config.setNestedValue("overview.dashboard.showSystem", checked)
                visible: Config.options?.overview?.dashboard?.enable ?? false
            }
            ContentSubsection {
                title: Translation.tr("All-apps grid")

                SettingsSwitch {
                    buttonIcon: "apps"
                    text: Translation.tr("Show all-apps grid")
                    checked: Config.options?.overview?.allAppsGrid ?? false
                    enabled: !(Config.options?.overview?.dashboard?.enable ?? false)
                    onCheckedChanged: Config.setNestedValue("overview.allAppsGrid", checked)
                    StyledToolTip {
                        text: Translation.tr("Replace workspace previews with a scrollable grid of all installed applications")
                    }
                }

                ConfigSelectionArray {
                    currentValue: Config.options?.overview?.allAppsGridMode ?? "minimal"
                    enabled: (Config.options?.overview?.allAppsGrid ?? false) && !(Config.options?.overview?.dashboard?.enable ?? false)
                    onSelected: (newValue) => {
                        Config.setNestedValue("overview.allAppsGridMode", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Alphabetical (A-Z)"), icon: "sort_by_alpha", value: "minimal" },
                        { displayName: Translation.tr("By category"), icon: "folder", value: "folder" }
                    ]
                }
            }
            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Center icons")
                checked: Config.options.overview.centerIcons
                onCheckedChanged: {
                    Config.setNestedValue("overview.centerIcons", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Center app icons in the launcher grid")
                }
            }
            SettingsSwitch {
                buttonIcon: "preview"
                text: Translation.tr("Show window previews")
                checked: Config.options?.overview?.showPreviews !== false
                onCheckedChanged: {
                    Config.setNestedValue("overview.showPreviews", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Display thumbnail previews of windows in the overview")
                }
            }
            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Scale (%)")
                value: Config.options.overview.scale * 100
                from: 1
                to: 100
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("overview.scale", value / 100);
                }
                StyledToolTip {
                    text: Translation.tr("Scale of workspace previews in the overview")
                }
            }
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "splitscreen_bottom"
                    text: Translation.tr("Rows")
                    value: Config.options.overview.rows
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("overview.rows", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of rows in the app launcher grid")
                    }
                }
                ConfigSpinBox {
                    icon: "splitscreen_right"
                    text: Translation.tr("Columns")
                    value: Config.options.overview.columns
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("overview.columns", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of columns in the app launcher grid")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Wallpaper background")

                SettingsSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Enable wallpaper blur")
                    checked: !Config.options.overview || Config.options.overview.backgroundBlurEnable !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.backgroundBlurEnable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to the overview background")
                    }
                }

                ConfigSpinBox {
                    icon: "loupe"
                    text: Translation.tr("Wallpaper blur radius")
                    value: Config.options.overview && Config.options.overview.backgroundBlurRadius !== undefined
                           ? Config.options.overview.backgroundBlurRadius
                           : 22
                    from: 0
                    to: 100
                    stepSize: 1
                    enabled: !Config.options.overview || Config.options.overview.backgroundBlurEnable !== false
                    onValueChanged: {
                        Config.setNestedValue("overview.backgroundBlurRadius", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Intensity of the wallpaper blur")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Wallpaper dim (%)")
                    value: Config.options.overview && Config.options.overview.backgroundDim !== undefined
                           ? Config.options.overview.backgroundDim
                           : 35
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("overview.backgroundDim", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Darkness of the wallpaper behind overview")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay scrim dim (%)")
                    value: Config.options.overview && Config.options.overview.scrimDim !== undefined
                           ? Config.options.overview.scrimDim
                           : 35
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("overview.scrimDim", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Additional darkness for better contrast")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Positioning")

                SettingsSwitch {
                    buttonIcon: "dashboard_customize"
                    text: Translation.tr("Respect bar area (never overlap)")
                    checked: !Config.options.overview || Config.options.overview.respectBar !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.respectBar", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Prevent overview from covering the system bar area")
                    }
                }

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "vertical_align_top"
                        text: Translation.tr("Extra top margin (px)")
                        value: Config.options.overview && Config.options.overview.topMargin !== undefined
                               ? Config.options.overview.topMargin
                               : 0
                        from: 0
                        to: 400
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("overview.topMargin", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Space reserved at the top of the screen")
                        }
                    }
                    ConfigSpinBox {
                        icon: "vertical_align_bottom"
                        text: Translation.tr("Extra bottom margin (px)")
                        value: Config.options.overview && Config.options.overview.bottomMargin !== undefined
                               ? Config.options.overview.bottomMargin
                               : 0
                        from: 0
                        to: 400
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("overview.bottomMargin", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Space reserved at the bottom of the screen")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Layout & gaps")

                ConfigSpinBox {
                    icon: "open_in_full"
                    text: Translation.tr("Max panel width (%) of screen")
                    value: Config.options.overview && Config.options.overview.maxPanelWidthRatio !== undefined
                           ? Math.round(Config.options.overview.maxPanelWidthRatio * 100)
                           : 100
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("overview.maxPanelWidthRatio", value / 100);
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum width of the overview panel as screen percentage")
                    }
                }

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "grid_3x3"
                        text: Translation.tr("Workspace gap (px)")
                        value: Config.options.overview && Config.options.overview.workspaceSpacing !== undefined
                               ? Config.options.overview.workspaceSpacing
                               : 5
                        from: 0
                        to: 80
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("overview.workspaceSpacing", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Horizontal gap between workspace previews")
                        }
                    }
                    ConfigSpinBox {
                        icon: "view_comfy_alt"
                        text: Translation.tr("Window tile gap (px)")
                        value: Config.options.overview && Config.options.overview.windowTileMargin !== undefined
                               ? Config.options.overview.windowTileMargin
                               : 6
                        from: 0
                        to: 80
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("overview.windowTileMargin", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Gap between windows inside a workspace preview")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Icons")

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "format_size"
                        text: Translation.tr("Min icon size (px)")
                        value: Config.options.overview && Config.options.overview.iconMinSize !== undefined
                               ? Config.options.overview.iconMinSize
                               : 0
                        from: 0
                        to: 512
                        stepSize: 2
                        onValueChanged: {
                            Config.setNestedValue("overview.iconMinSize", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Minimum size for app icons")
                        }
                    }
                    ConfigSpinBox {
                        icon: "format_overline"
                        text: Translation.tr("Max icon size (px)")
                        value: Config.options.overview && Config.options.overview.iconMaxSize !== undefined
                               ? Config.options.overview.iconMaxSize
                               : 0
                        from: 0
                        to: 512
                        stepSize: 2
                        onValueChanged: {
                            Config.setNestedValue("overview.iconMaxSize", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Maximum size for app icons")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Behaviour")

                SettingsSwitch {
                    buttonIcon: "workspaces"
                    text: Translation.tr("Switch to dedicated workspace when opening Overview")
                    checked: Config.options.overview && Config.options.overview.switchToWorkspaceOnOpen
                    onCheckedChanged: {
                        Config.setNestedValue("overview.switchToWorkspaceOnOpen", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Automatically switch to a specific workspace when overview opens")
                    }
                }

                ConfigSpinBox {
                    icon: "looks_one"
                    text: Translation.tr("Workspace number (1-based)")
                    enabled: Config.options.overview && Config.options.overview.switchToWorkspaceOnOpen
                    value: Config.options.overview && Config.options.overview.switchWorkspaceIndex !== undefined
                           ? Config.options.overview.switchWorkspaceIndex
                           : 1
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("overview.switchWorkspaceIndex", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Index of the workspace to switch to")
                    }
                }
                ConfigSpinBox {
                    icon: "swap_vert"
                    text: Translation.tr("Wheel steps per workspace (Overview)")
                    value: Config.options.overview && Config.options.overview.scrollWorkspaceSteps !== undefined
                           ? Config.options.overview.scrollWorkspaceSteps
                           : 2
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("overview.scrollWorkspaceSteps", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("How many workspaces to scroll per mouse wheel detent")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "overview_key"
                    text: Translation.tr("Keep Overview open when clicking windows")
                    checked: !Config.options.overview || Config.options.overview.keepOverviewOpenOnWindowClick !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.keepOverviewOpenOnWindowClick", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Don't close overview when clicking on a window preview")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "close_fullscreen"
                    text: Translation.tr("Close Overview after moving window")
                    checked: !Config.options.overview || Config.options.overview.closeAfterWindowMove !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.closeAfterWindowMove", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Close overview automatically after dropping a window to a new workspace")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "looks_one"
                    text: Translation.tr("Show workspace numbers")
                    checked: !Config.options.overview || Config.options.overview.showWorkspaceNumbers !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.showWorkspaceNumbers", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Overlay large numbers on workspace previews")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Animation")

                SettingsSwitch {
                    buttonIcon: "motion_play"
                    text: Translation.tr("Enable focus animation")
                    checked: !Config.options.overview || Config.options.overview.focusAnimationEnable !== false
                    onCheckedChanged: {
                        Config.setNestedValue("overview.focusAnimationEnable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Animate the focus rectangle when navigating with keyboard")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Focus animation duration (ms)")
                    enabled: !Config.options.overview || Config.options.overview.focusAnimationEnable !== false
                    value: Config.options.overview && Config.options.overview.focusAnimationDurationMs !== undefined
                           ? Config.options.overview.focusAnimationDurationMs
                           : 180
                    from: 0
                    to: 1000
                    stepSize: 10
                    onValueChanged: {
                        Config.setNestedValue("overview.focusAnimationDurationMs", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Speed of the focus rectangle animation")
                    }
                }
            }
        }
    }
}
