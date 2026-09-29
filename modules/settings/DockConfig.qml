import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    function movePinnedApp(fromIndex: int, delta: int): void {
        const values = [...(Config.options?.dock?.pinnedApps ?? [])]
        const toIndex = fromIndex + delta
        if (fromIndex < 0 || fromIndex >= values.length
                || toIndex < 0 || toIndex >= values.length)
            return
        const moved = values.splice(fromIndex, 1)[0]
        values.splice(toIndex, 0, moved)
        Config.setNestedValue("dock.pinnedApps", values)
    }

    function pinnedAppLabel(appId: string): string {
        return AppSearch.lookupDesktopEntry(appId)?.name ?? appId
    }

    function pinnedAppIcon(appId: string): string {
        const entry = AppSearch.lookupDesktopEntry(appId)
        const icon = entry?.icon || AppSearch.guessIcon(appId)
        const resolved = IconThemeService.smartIconName(icon, appId)
        if (resolved.startsWith("/") || resolved.startsWith("file://"))
            return resolved.startsWith("file://") ? resolved : `file://${resolved}`
        return Quickshell.iconPath(resolved, "application-x-executable")
    }

    settingsPageIndex: embedded ? 2 : 22
    settingsPageName: Translation.tr("Dock")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "call_to_action"
        title: Translation.tr("Dock")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.dock.enable
                onCheckedChanged: {
                    Config.setNestedValue("dock.enable", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Show the application dock")
                }
            }

            SettingsNote {
                icon: "dock_to_bottom"
                text: Config.options?.panelFamily === "abyss" ? "The Dock shares the Abyss Screen Edge surface." : Translation.tr("Dock uses the Panel surface style.")
            }

            ConfigRow {
                uniform: true
                ContentSubsection {
                    title: Translation.tr("Dock position")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.position ?? "bottom"
                        onSelected: newValue => {
                            Config.setNestedValue('dock.position', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: "top" },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                        ]
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Reveal behavior")
                    tooltip: Translation.tr("When the dock shows. Hover hides it until you reach the screen edge; Empty workspace keeps it visible on an empty desktop.")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.hoverToReveal ?? true
                        onSelected: newValue => {
                            Config.setNestedValue('dock.hoverToReveal', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Hover"), icon: "highlight_mouse_cursor", value: true },
                            { displayName: Translation.tr("Empty workspace"), icon: "desktop_windows", value: false }
                        ]
                    }
                    SettingsSwitch {
                        buttonIcon: "desktop_windows"
                        text: Translation.tr("Show on desktop")
                        enabled: !(Config.options?.dock?.hoverToReveal ?? true)
                        checked: Config.options?.dock?.showOnDesktop ?? true
                        onCheckedChanged: Config.setNestedValue('dock.showOnDesktop', checked)
                        StyledToolTip {
                            text: Translation.tr("Show dock when no window is focused (Empty workspace mode only)")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "keep"
                        text: Translation.tr("Pinned on startup")
                        enabled: !(Config.options?.dock?.hoverToReveal ?? true)
                        checked: Config.options.dock.pinnedOnStartup
                        onCheckedChanged: {
                            Config.setNestedValue("dock.pinnedOnStartup", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Keep dock visible at all times (Empty workspace mode only)")
                        }
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "dashboard"
                text: Translation.tr("Show Dashboard icon")
                checked: Config.options?.dock?.showDashboardButton ?? true
                onCheckedChanged:
                    Config.setNestedValue("dock.showDashboardButton", checked)
                StyledToolTip {
                    text: Translation.tr("Show the Dashboard / Overview launcher button in the Dock")
                }
            }

            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Tint app icons")
                checked: Config.options.dock.monochromeIcons
                onCheckedChanged: {
                    Config.setNestedValue("dock.monochromeIcons", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to dock app icons")
                }
            }
            SettingsSwitch {
                buttonIcon: "widgets"
                visible: Config.options?.panelFamily !== "abyss"
                text: Translation.tr("Show dock background")
                checked: Config.options.dock.showBackground
                onCheckedChanged: Config.setNestedValue("dock.showBackground", checked)
                StyledToolTip {
                    text: Translation.tr("Show a background behind the dock")
                }
            }

            SettingsSwitch {
                buttonIcon: "splitscreen"
                text: Translation.tr("Separate pinned from running")
                checked: Config.options?.dock?.separatePinnedFromRunning ?? true
                onCheckedChanged: Config.setNestedValue('dock.separatePinnedFromRunning', checked)
                StyledToolTip {
                    text: Translation.tr("Show pinned-only apps on the left, running apps on the right with a separator")
                }
            }

            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Notification badges")
                checked: Config.options?.dock?.notificationBadge ?? true
                onCheckedChanged: Config.setNestedValue('dock.notificationBadge', checked)
                StyledToolTip {
                    text: Translation.tr("Show the number of pending notifications on each app icon")
                }
            }

            ContentSubsection {
                title: Translation.tr("Pinned app order")

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Pinned apps follow this order in the Dock. Running-only apps keep their open order.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: Config.options?.dock?.pinnedApps ?? []

                        delegate: Rectangle {
                            id: pinnedAppDelegate
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1Base
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 8

                                IconImage {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    source: root.pinnedAppIcon(String(pinnedAppDelegate.modelData))
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: root.pinnedAppLabel(String(pinnedAppDelegate.modelData))
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: String(pinnedAppDelegate.modelData)
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }
                                }

                                RippleButton {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    enabled: pinnedAppDelegate.index > 0
                                    pointingHandCursor: enabled
                                    Accessible.name: Translation.tr("Move earlier")
                                    onClicked: root.movePinnedApp(pinnedAppDelegate.index, -1)
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "arrow_upward"
                                        iconSize: 18
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledToolTip { text: Translation.tr("Move earlier") }
                                }

                                RippleButton {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    enabled: pinnedAppDelegate.index
                                        < (Config.options?.dock?.pinnedApps?.length ?? 0) - 1
                                    pointingHandCursor: enabled
                                    Accessible.name: Translation.tr("Move later")
                                    onClicked: root.movePinnedApp(pinnedAppDelegate.index, 1)
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "arrow_downward"
                                        iconSize: 18
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledToolTip { text: Translation.tr("Move later") }
                                }
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Appearance")

                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Dock height (px)")
                    value: Config.options.dock.height ?? 60
                    from: 40
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("dock.height", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Height of the dock container")
                    }
                }

                ConfigSpinBox {
                    icon: "aspect_ratio"
                    text: Translation.tr("Icon size (px)")
                    value: Config.options.dock.iconSize ?? 35
                    from: 20
                    to: 60
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("dock.iconSize", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of application icons in the dock")
                    }
                }

                ConfigSpinBox {
                    icon: {
                        const pos = Config.options?.dock?.position ?? "bottom"
                        switch (pos) {
                            case "top": return "vertical_align_top"
                            case "left": return "align_horizontal_left"
                            case "right": return "align_horizontal_right"
                            default: return "vertical_align_bottom"
                        }
                    }
                    text: Translation.tr("Hover reveal region size (px)")
                    value: Config.options.dock.hoverRegionHeight ?? 2
                    from: 1
                    to: 20
                    stepSize: 1
                    enabled: Config.options.dock.hoverToReveal
                    onValueChanged: {
                        Config.setNestedValue("dock.hoverRegionHeight", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of the invisible area at screen edge that triggers dock reveal")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Window indicators")

                SettingsSwitch {
                    buttonIcon: "my_location"
                    text: Translation.tr("Smart indicator (highlight focused window)")
                    checked: Config.options.dock.smartIndicator !== false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.smartIndicator", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("When multiple windows of the same app are open, highlight which one is focused")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "more_horiz"
                    text: Translation.tr("Show dots for inactive apps")
                    checked: Config.options.dock.showAllWindowDots !== false
                    onCheckedChanged: {
                        Config.setNestedValue("dock.showAllWindowDots", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a dot per window even for apps that aren't currently focused")
                    }
                }

                ConfigSpinBox {
                    icon: "filter_5"
                    text: Translation.tr("Maximum indicator dots")
                    value: Config.options.dock.maxIndicatorDots ?? 5
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("dock.maxIndicatorDots", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Limit the number of open window dots shown below an app icon")
                    }
                }
            }

        }
    }

}
