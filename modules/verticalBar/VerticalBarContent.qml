import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar as Bar

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property alias backgroundItem: barBackground
    property bool nativeBlurAllowed: true
    readonly property string nativeBlurTopology: Appearance.blurTopology.roundedRectangle
    readonly property bool nativeBlurActive: !root.isIslands
        && Appearance.useCompositorBlur("bar", root.nativeBlurTopology)
        && root.nativeBlurAllowed
        && (Config.options?.bar?.showBackground ?? true)
        && !root.gameModeMinimal

    property Item barContextMenuSource: null
    property rect barContextMenuRect: Qt.rect(0, 0, 1, 1)

    function openBarContextMenu(clickX, clickY, mouseArea) {
        root.barContextMenuSource = mouseArea
        root.barContextMenuRect = Qt.rect(clickX, clickY, 1, 1)
        barContextMenu.requestOpen()
    }

    Bar.BarContextMenu {
        id: barContextMenu
        anchorItem: root.barContextMenuSource ?? root
        anchorRect: root.barContextMenuRect
        anchorHovered: root.barContextMenuSource?.hovered ?? false
        closeOnHoverLost: true

        model: [
            {
                iconName: "browse_activity",
                monochromeIcon: true,
                text: Translation.tr("Mission Center"),
                action: () => {
                    Session.launchTaskManager()
                },
            },
            { type: "separator" },
            {
                iconName: "settings",
                monochromeIcon: true,
                text: Translation.tr("Settings"),
                action: () => {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                },
            },
        ]
    }
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    readonly property color separatorColor: Appearance.colors.colOutlineVariant
    readonly property bool gameModeMinimal: Appearance.gameModeMinimal

    readonly property string barAppearance: Config.options?.bar?.appearanceStyle ?? "classic"
    readonly property bool isIslands: root.barAppearance === "islands"

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.separatorColor
    }

    // Background shadow for supported floating/card styles.
    Loader {
        active: (Config.options?.bar?.showBackground ?? true) && !root.gameModeMinimal
            && !root.isIslands
            && ((Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3)
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }

    // Background
    Rectangle {
        id: barBackground
        // Floating style: cornerStyle 1 (floating) or 3 (card) - NOT 0 (hug)
        // Aurora style forces floating appearance but hug mode should still work
        readonly property bool floatingStyle: (Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3

        anchors {
            fill: parent
            // Only add margins for floating styles, NOT for hug mode (cornerStyle 0)
            margins: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        }
        visible: (Config.options?.bar?.showBackground ?? true) && !root.gameModeMinimal && !root.isIslands
        color: root.cardStyleEverywhere
            ? Appearance.colors.colLayer1
            : ((Config.options?.bar?.cornerStyle ?? 0) === 3
                ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        radius: floatingStyle
            ? ((Config.options?.bar?.cornerStyle ?? 0) === 3
                ? Appearance.rounding.normal : Appearance.rounding.windowRounding)
            : 0
        // No Behavior on the base radius — the per-corner radii below own the
        // corners, and a second interceptor on radius is unsupported (Qt warn).

        topLeftRadius: radius
        bottomLeftRadius: radius
        topRightRadius: radius
        bottomRightRadius: radius
        Behavior on topRightRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on topLeftRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.width: floatingStyle ? 1 : 0
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.color: Appearance.colors.colLayer0Border
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        clip: true

    }

    FocusedScrollMouseArea { // Top section | scroll to change brightness
        id: barTopSectionMouseArea
        anchors.top: parent.top
        implicitHeight: topSectionColumnLayout.implicitHeight
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth

        onScrollDown: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        onScrollUp: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.toggleSidebarLeft(root.screen?.name ?? "");
            else if (event.button === Qt.RightButton)
                root.openBarContextMenu(event.x, event.y, barTopSectionMouseArea)
        }

        ColumnLayout { // Content
            id: topSectionColumnLayout
            anchors.fill: parent
            spacing: 10

            Bar.LeftSidebarButton { // Left sidebar button
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: (Appearance.sizes.baseVerticalBarWidth - implicitWidth) / 2 + Appearance.sizes.hyprlandGapsOut
                colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            Item {
                Layout.fillHeight: true
            }
            
        }
    }

    Column { // Middle section
        id: middleSection
        anchors.centerIn: parent
        spacing: 4

        // When taskbar is active: clock/date moves up to where resources was
        Bar.BarGroup {
            id: clockGroupTop
            vertical: true
            padding: 8
            visible: Config.options?.bar?.modules?.taskbar ?? false

            VerticalClockWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {}

            VerticalDateWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: Battery.available
            }

            BatteryIndicator {
                visible: Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        Bar.BarGroup {
            id: resourcesGroup
            vertical: true
            padding: 8
            // Hide resources when taskbar is active to free vertical space
            visible: !(Config.options?.bar?.modules?.taskbar ?? false)
            Resources {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
            HorizontalBarSeparator {}

            VerticalMedia {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

    HorizontalBarSeparator {
            visible: Config.options?.bar?.borderless ?? false
        }

        Bar.BarGroup {
            id: middleCenterGroup
            vertical: true
            padding: 6

            Bar.Workspaces {
                id: workspacesWidget
                vertical: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.toggleOverview(root.screen?.name ?? "");
                        }
                    }
                }
            }
        }

        HorizontalBarSeparator {
            visible: (Config.options?.bar?.modules?.taskbar ?? false) && (Config.options?.bar?.borderless ?? false)
        }

        // Taskbar (apps in bar) — vertical mode
        Bar.BarGroup {
            id: taskbarGroup
            vertical: true
            padding: 4
            visible: Config.options?.bar?.modules?.taskbar ?? false

            Bar.BarTaskbar {
                vertical: true
                parentWindow: root.QsWindow.window
                Layout.fillWidth: true
                Layout.fillHeight: false
                maximumHeight: Math.max(80, root.height
                    - (clockGroupTop.visible ? clockGroupTop.height : 0)
                    - middleCenterGroup.height
                    - (clockGroup.visible ? clockGroup.height : 0)
                    - middleSection.spacing * 6
                    - 140)
            }
        }

        HorizontalBarSeparator {
            visible: Config.options?.bar?.borderless ?? false
        }

        // When taskbar is NOT active: clock/date stays in its original position
        Bar.BarGroup {
            id: clockGroup
            vertical: true
            padding: 8
            visible: !(Config.options?.bar?.modules?.taskbar ?? false)
            
            VerticalClockWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {}

            VerticalDateWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: Battery.available
            }

            BatteryIndicator {
                visible: Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
        }
    }

    FocusedScrollMouseArea { // Bottom section | scroll to change volume
        id: barBottomSectionMouseArea

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        implicitHeight: bottomSectionColumnLayout.implicitHeight
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth
        
        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.toggleSidebarRight(root.screen?.name ?? "");
            } else if (event.button === Qt.RightButton) {
                root.openBarContextMenu(event.x, event.y, barBottomSectionMouseArea)
            }
        }

        ColumnLayout {
            id: bottomSectionColumnLayout
            anchors.fill: parent
            spacing: 4

            Item { 
                Layout.fillWidth: true
                Layout.fillHeight: true 
            }

            Bar.SysTray {
                vertical: true
                Layout.fillWidth: true
                Layout.fillHeight: false
                invertSide: Config?.options.bar.bottom
            }

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                Layout.bottomMargin: Appearance.rounding.screenRounding
                Layout.fillHeight: false

                implicitHeight: indicatorsColumnLayout.implicitHeight + 4 * 2
                implicitWidth: indicatorsColumnLayout.implicitWidth + 6 * 2

                buttonRadius: Appearance.rounding.full
                colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: GlobalStates.sidebarRightOpen
                    && GlobalStates.sidebarRightPresentationOutput === (root.screen?.name ?? "")
                property color colText: toggled
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                onPressed: {
                    GlobalStates.toggleSidebarRight(root.screen?.name ?? "");
                }

                ColumnLayout {
                    id: indicatorsColumnLayout
                    anchors.centerIn: parent
                    property real realSpacing: 6
                    spacing: 0

                    Revealer {
                        vertical: true
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.bottomMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: Audio.micMuted
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.topMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Loader {
                        active: CompositorService.isHyprland
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                        sourceComponent: Bar.HyprlandXkbIndicator {
                            vertical: true
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.bottomMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Bar.NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                    MaterialSymbol {
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.activeIcon
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }
        }
    }
}
