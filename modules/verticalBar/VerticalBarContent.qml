import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
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
    readonly property string nativeBlurTopology: Appearance.blurTopology.unsupported
    readonly property bool nativeBlurActive: !root.isIslands
        && Appearance.useCompositorBlur("bar", root.nativeBlurTopology)
        && root.nativeBlurAllowed
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
    readonly property bool cardStyleEverywhere: false
    readonly property color separatorColor: Appearance.colors.colOutlineVariant
    readonly property bool gameModeMinimal: Appearance.gameModeMinimal

    readonly property string barAppearance: Config.options?.bar?.appearanceStyle ?? "classic"
    readonly property bool isIslands: root.barAppearance === "islands"

    // Bar Settings owns one canonical module-visibility object for every edge.
    // Keep vertical presentation compact, but never fork visibility state by
    // orientation again (the old iNiR vertical bar only listened to taskbar).
    function moduleEnabled(name: string, fallback: bool): bool {
        const value = Config.options?.bar?.modules?.[name]
        return value === undefined || value === null ? fallback : Boolean(value)
    }

    readonly property bool leftSidebarButtonEnabled: root.moduleEnabled("leftSidebarButton", true)
    readonly property bool activeWindowEnabled: root.moduleEnabled("activeWindow", true)
        && !root.taskbarEnabled
    readonly property bool taskbarEnabled: root.moduleEnabled("taskbar", false)
    readonly property bool resourcesEnabled: root.moduleEnabled("resources", false)
    readonly property bool mediaEnabled: root.moduleEnabled("media", true)
    readonly property bool workspacesEnabled: root.moduleEnabled("workspaces", true)
    readonly property bool clockEnabled: root.moduleEnabled("clock", true)
    readonly property bool utilButtonsEnabled: root.moduleEnabled("utilButtons", false)
    readonly property bool batteryEnabled: root.moduleEnabled("battery", true)
    readonly property bool weatherEnabled: root.moduleEnabled("weather", true)
        && (Config.options?.bar?.weather?.enable ?? false)
    readonly property bool sysTrayEnabled: root.moduleEnabled("sysTray", true)
    readonly property bool rightSidebarButtonEnabled: root.moduleEnabled("rightSidebarButton", true)

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.separatorColor
    }

    // Detached Float/Card shadow is retired; VerticalBar.qml owns the one
    // inward Hug shadow shared with Screen Edge and horizontal Bar.
    Loader {
        active: false
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }

    // Background
    Rectangle {
        id: barBackground
        readonly property bool floatingStyle: false

        anchors {
            fill: parent
            margins: 0
        }
        // Hug background is structural connected chrome. Fullscreen/GameMode
        // may disable effects, but the native Bar surface stays mapped. Niri
        // covers the Top-layer surface during fullscreen and reveals it on exit.
        visible: !root.isIslands
        color: Appearance.colors.colLayer0
        radius: 0
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
                visible: root.leftSidebarButtonEnabled
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: (Appearance.sizes.baseVerticalBarWidth - implicitWidth) / 2 + Appearance.sizes.hyprlandGapsOut
                colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            Item {
                id: activeWindowCompact
                visible: root.activeWindowEnabled
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: root.leftSidebarButtonEnabled ? 0 : Appearance.rounding.screenRounding
                implicitWidth: 30
                implicitHeight: 30
                readonly property var activeWindow: ToplevelManager.activeToplevel
                readonly property bool hovered: activeWindowHover.hovered

                HoverHandler {
                    id: activeWindowHover
                }

                SmartAppIcon {
                    anchors.centerIn: parent
                    icon: String(activeWindowCompact.activeWindow?.appId ?? "")
                    fallback: "window"
                    iconSize: 20
                }

                StyledToolTip {
                    text: {
                        const appName = String(activeWindowCompact.activeWindow?.appId ?? Translation.tr("Desktop"))
                        const title = String(activeWindowCompact.activeWindow?.title ?? "")
                        return title.length > 0 && title !== appName
                            ? appName + "\n" + title : appName
                    }
                }
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

        // Keep the compact clock near the top of the middle stack when the
        // vertical taskbar is enabled, without forcing Clock/Battery visible.
        Bar.BarGroup {
            id: clockGroupTop
            vertical: true
            padding: 8
            visible: root.taskbarEnabled
                && (root.clockEnabled || (root.batteryEnabled && Battery.available))

            VerticalClockWidget {
                visible: root.clockEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: root.clockEnabled
            }

            VerticalDateWidget {
                visible: root.clockEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: root.clockEnabled && root.batteryEnabled && Battery.available
            }

            BatteryIndicator {
                visible: root.batteryEnabled && Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        Bar.BarGroup {
            id: resourcesGroup
            vertical: true
            padding: 8
            visible: root.resourcesEnabled || root.mediaEnabled

            Resources {
                visible: root.resourcesEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: root.resourcesEnabled && root.mediaEnabled
            }

            VerticalMedia {
                visible: root.mediaEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        HorizontalBarSeparator {
            visible: (Config.options?.bar?.borderless ?? false)
                && (clockGroupTop.visible || resourcesGroup.visible)
                && middleCenterGroup.visible
        }

        Bar.BarGroup {
            id: middleCenterGroup
            vertical: true
            padding: 6
            visible: root.workspacesEnabled

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
            visible: root.taskbarEnabled
                && (Config.options?.bar?.borderless ?? false)
                && middleCenterGroup.visible
        }

        // Taskbar (apps in bar) — vertical mode
        Bar.BarGroup {
            id: taskbarGroup
            vertical: true
            padding: 4
            visible: root.taskbarEnabled

            Bar.BarTaskbar {
                vertical: true
                parentWindow: root.QsWindow.window
                Layout.fillWidth: true
                Layout.fillHeight: false
                maximumHeight: Math.max(80, root.height
                    - (clockGroupTop.visible ? clockGroupTop.height : 0)
                    - (resourcesGroup.visible ? resourcesGroup.height : 0)
                    - (middleCenterGroup.visible ? middleCenterGroup.height : 0)
                    - (clockGroup.visible ? clockGroup.height : 0)
                    - (utilButtonsGroup.visible ? utilButtonsGroup.height : 0)
                    - middleSection.spacing * 7
                    - 140)
            }
        }

        HorizontalBarSeparator {
            visible: (Config.options?.bar?.borderless ?? false)
                && !root.taskbarEnabled
                && middleCenterGroup.visible
                && clockGroup.visible
        }

        // When taskbar is NOT active: clock/date stays in its original position.
        Bar.BarGroup {
            id: clockGroup
            vertical: true
            padding: 8
            visible: !root.taskbarEnabled
                && (root.clockEnabled || (root.batteryEnabled && Battery.available))

            VerticalClockWidget {
                visible: root.clockEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: root.clockEnabled
            }

            VerticalDateWidget {
                visible: root.clockEnabled
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: root.clockEnabled && root.batteryEnabled && Battery.available
            }

            BatteryIndicator {
                visible: root.batteryEnabled && Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        Bar.BarGroup {
            id: utilButtonsGroup
            vertical: true
            padding: 4
            visible: root.utilButtonsEnabled

            Bar.UtilButtons {
                vertical: true
                Layout.alignment: Qt.AlignHCenter
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

            Bar.BarGroup {
                id: weatherGroup
                vertical: true
                padding: 4
                visible: root.weatherEnabled
                Layout.alignment: Qt.AlignHCenter

                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 34
                    implicitHeight: 46
                    buttonText: Translation.tr("Weather")
                    buttonRadius: Appearance.rounding.full
                    colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active
                    onClicked: {
                        GlobalStates.sidebarRightRequestedWidget = "weather"
                        GlobalStates.openSidebarRight(root.screen?.name ?? "")
                    }
                    altAction: event => Weather.forceRefresh()

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            fill: 0
                            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Weather")
                    }
                }
            }

            Bar.SysTray {
                visible: root.sysTrayEnabled
                vertical: true
                Layout.fillWidth: true
                Layout.fillHeight: false
                invertSide: Config?.options.bar.bottom
            }

            RippleButton { // Right sidebar button
                id: rightSidebarButton
                visible: root.rightSidebarButtonEnabled

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
