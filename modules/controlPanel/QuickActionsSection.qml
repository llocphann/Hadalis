pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

PanelSurface {
    id: root
    islandSkin: (Config.options?.controlPanel?.style ?? "panel") === "island"
    Layout.fillWidth: true
    implicitHeight: actionsGrid.implicitHeight + 16
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool regaliaEverywhere: Appearance.regaliaEverywhere

    elevation: 1
    radiusOverride: islandSkin ? -1 : (inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal)

    AngelPartialBorder { targetRadius: root.radiusOverride; coverage: 0.45; visible: Appearance.angelEverywhere && !root.islandSkin }

    GridLayout {
        id: actionsGrid
        anchors.fill: parent
        anchors.margins: root.regaliaEverywhere ? Appearance.regalia.tilePadding
            : root.compactMode ? 6 : 8
        columns: 4
        rowSpacing: root.regaliaEverywhere ? Appearance.regalia.controlGap
            : root.compactMode ? 4 : 6
        columnSpacing: rowSpacing

        // Row 1: Audio
        ActionTile {
            icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
            accessibleName: Audio.sink?.audio?.muted ? Translation.tr("Unmute audio") : Translation.tr("Mute audio")
            active: !(Audio.sink?.audio?.muted ?? false)
            onClicked: Audio.toggleMute()
        }

        ActionTile {
            icon: Audio.micMuted ? "mic_off" : "mic"
            accessibleName: Audio.micMuted ? Translation.tr("Unmute microphone") : Translation.tr("Mute microphone")
            active: !Audio.micMuted
            onClicked: Audio.toggleMicMute()
        }

        ActionTile {
            icon: "notifications"
            accessibleName: Notifications.silent ? Translation.tr("Unmute notifications") : Translation.tr("Mute notifications")
            active: !Notifications.silent
            onClicked: Notifications.silent = !Notifications.silent
        }

        ActionTile {
            icon: "dark_mode"
            accessibleName: Appearance.m3colors.darkmode ? Translation.tr("Switch to light mode") : Translation.tr("Switch to dark mode")
            active: Appearance.m3colors.darkmode
            onClicked: Appearance.toggleDarkMode()
        }

        // Row 2: Connectivity & System
        ActionTile {
            icon: Network.wifiEnabled ? "wifi" : "wifi_off"
            accessibleName: Network.wifiEnabled ? Translation.tr("Disable Wi-Fi") : Translation.tr("Enable Wi-Fi")
            active: Network.wifiEnabled
            onClicked: Network.toggleWifi()
        }

        ActionTile {
            visible: BluetoothStatus.available
            icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            accessibleName: BluetoothStatus.enabled ? Translation.tr("Disable Bluetooth") : Translation.tr("Enable Bluetooth")
            active: BluetoothStatus.enabled
            onClicked: BluetoothStatus.toggle()
        }

        ActionTile {
            icon: "coffee"
            accessibleName: Idle.inhibit ? Translation.tr("Allow sleep") : Translation.tr("Keep awake")
            active: Idle.inhibit
            onClicked: Idle.toggleInhibit()
        }

        ActionTile {
            icon: "sports_esports"
            accessibleName: GameMode.active ? Translation.tr("Disable game mode") : Translation.tr("Enable game mode")
            active: GameMode.active
            onClicked: GameMode.toggle()
        }

        // Row 3: Tools
        ActionTile {
            icon: "screenshot_monitor"
            accessibleName: Translation.tr("Take screenshot")
            onClicked: {
                GlobalStates.controlPanelOpen = false
                // Resolve action/mode explicitly — a bare regionSelectorOpen=true
                // inherits whatever a previous record/lens use left behind.
                GlobalStates.openRegionScreenshot()
            }
        }

        ActionTile {
            icon: "settings"
            accessibleName: Translation.tr("Open settings")
            onClicked: {
                GlobalStates.controlPanelOpen = false
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
            }
        }

        ActionTile {
            icon: "lock"
            accessibleName: Translation.tr("Lock screen")
            onClicked: {
                GlobalStates.controlPanelOpen = false
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
            }
        }

        ActionTile {
            icon: "power_settings_new"
            accessibleName: Translation.tr("Open power menu")
            iconColor: Appearance.angelEverywhere ? Appearance.colors.colError
                     : root.inirEverywhere ? Appearance.inir.colError
                     : root.auroraEverywhere ? Appearance.colors.colError
                     : Appearance.colors.colError
            onClicked: {
                GlobalStates.controlPanelOpen = false
                GlobalStates.sessionOpen = true
            }
        }
    }

    component ActionTile: Rectangle {
        id: tile
        property string icon
        required property string accessibleName
        property bool active: false
        property color iconColor: active
            ? (root.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
             : Appearance.cookieEverywhere ? Appearance.colors.colOnPrimaryContainer
             : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
             : root.inirEverywhere ? Appearance.inir.colOnPrimary
             : root.auroraEverywhere ? Appearance.colors.colOnPrimary
             : Appearance.colors.colOnPrimary)
            : (root.regaliaEverywhere ? Appearance.regalia.onColor
             : Appearance.angelEverywhere ? Appearance.angel.colText
             : root.inirEverywhere ? Appearance.inir.colText
             : root.auroraEverywhere ? Appearance.colors.colOnSurface
             : Appearance.colors.colOnLayer1)
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: root.compactMode ? 30 : 36
        radius: root.regaliaEverywhere ? Appearance.regalia.controlRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : root.inirEverywhere ? Appearance.inir.roundingSmall
            : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.rounding.small
        
        color: root.regaliaEverywhere ? "transparent"
            : tileMouseArea.containsMouse
                ? (active
                    ? (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimaryHover, 0.35)
                     : root.inirEverywhere ? Appearance.inir.colPrimaryHover
                     : root.auroraEverywhere ? Appearance.colors.colPrimaryHover
                     : Appearance.colors.colPrimaryHover)
                    : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                     : root.inirEverywhere ? Appearance.inir.colLayer2Hover
                     : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                     : Appearance.colors.colLayer2Hover))
                : (active
                    ? (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.45)
                     : root.inirEverywhere ? Appearance.inir.colPrimary
                     : root.auroraEverywhere ? Appearance.colors.colPrimary
                     : Appearance.colors.colPrimary)
                    : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : root.inirEverywhere ? Appearance.inir.colLayer2
                     : root.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer2))

        border.width: Appearance.angelEverywhere ? 0 : (root.inirEverywhere ? 1 : Appearance.zzzEverywhere ? 1 : 0)
        border.color: Appearance.angelEverywhere ? "transparent"
            : root.inirEverywhere ? (active ? Appearance.inir.colPrimary : Appearance.inir.colBorderSubtle)
            : Appearance.zzzEverywhere ? Appearance.zzz.hairline : "transparent"

        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        AngelPartialBorder { targetRadius: parent.radius; coverage: 0.4; borderColor: active ? Appearance.angel.colPrimary : Appearance.angel.colBorderSubtle }

        RegaliaControlFace {
            anchors.fill: parent
            visible: root.regaliaEverywhere
            fillColor: tile.active ? Appearance.regalia.primaryPlate : Appearance.regalia.controlPlate
            radius: tile.radius
            hovered: tileMouseArea.containsMouse
            pressed: tileMouseArea.pressed
            selected: tile.active
        }

        Loader {
            anchors.centerIn: parent
            width: root.compactMode ? 24 : 28
            height: width
            active: Appearance.cookieEverywhere && tile.visible
            sourceComponent: CookieFace {
                role: "badge"
                selected: tile.active
                color: tile.active
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer2
            }
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        MaterialSymbol {
            z: 1
            anchors.centerIn: parent
            text: tile.icon
            iconSize: root.compactMode ? 16 : 18
            color: tile.iconColor

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: tileMouseArea.activeFocus
            color: "transparent"
            radius: tile.radius
            border.width: 2
            border.color: Appearance.zzzEverywhere ? Appearance.zzz.accent
                : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : root.inirEverywhere ? Appearance.inir.colPrimary
                : Appearance.colors.colPrimary
            z: 2
        }

        MouseArea {
            id: tileMouseArea
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: tile.accessibleName
            Accessible.focusable: true
            Accessible.onPressAction: tile.clicked()
            Keys.onPressed: event => {
                if (event.isAutoRepeat
                        || (event.key !== Qt.Key_Return
                            && event.key !== Qt.Key_Enter
                            && event.key !== Qt.Key_Space))
                    return
                tile.clicked()
                event.accepted = true
            }
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
