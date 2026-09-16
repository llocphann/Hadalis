pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    signal closeRequested()

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape) return
        root.closeRequested()
        event.accepted = true
    }

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    // Use MprisController.displayPlayers - centralized filtering
    readonly property var meaningfulPlayers: MprisController.displayPlayers
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.normal
    property real screenX: 0
    property real screenY: 0
    
    // Cache to prevent flickering during track transitions
    property var _playerCache: []
    property bool _cacheValid: false
    readonly property var _visiblePlayers: root._cacheValid ? root._playerCache : (root.meaningfulPlayers ?? [])

    function _samePlayerOrder(a, b): bool {
        if ((a?.length ?? 0) !== (b?.length ?? 0)) return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    function focusInitialControl(): bool {
        let fallback = null
        for (let i = 0; i < playerRepeater.count; i++) {
            const delegate = playerRepeater.itemAt(i)
            if (!delegate)
                continue
            if (!fallback)
                fallback = delegate
            if (delegate.isActive) {
                delegate.focusPrimaryControl()
                return true
            }
        }
        if (fallback) {
            fallback.focusPrimaryControl()
            return true
        }
        return false
    }

    onMeaningfulPlayersChanged: {
        const nextPlayers = root.meaningfulPlayers ?? []
        const count = nextPlayers.length
        if (count > 0) {
            if (!root._cacheValid || !root._samePlayerOrder(nextPlayers, root._playerCache))
                root._playerCache = [...nextPlayers];
            root._cacheValid = true;
            cacheInvalidateTimer.stop();
        } else if (root._cacheValid && root._playerCache.length > 0) {
            // Keep cache during transitions
            cacheInvalidateTimer.restart();
        }
    }

    Timer {
        id: cacheInvalidateTimer
        interval: 2200
        onTriggered: {
            if ((root.meaningfulPlayers?.length ?? 0) === 0 && (Mpris.players.values?.length ?? 0) === 0) {
                root._cacheValid = false;
            }
        }
    }

    implicitWidth: widgetWidth
    implicitHeight: playerColumn.implicitHeight

    ColumnLayout {
        id: playerColumn
        anchors.fill: parent
        spacing: 8

        Repeater {
            id: playerRepeater
            model: ScriptModel {
                values: root._visiblePlayers
            }
            delegate: Item {
                id: playerDelegate
                required property MprisPlayer modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: root.widgetWidth
                implicitHeight: root.widgetHeight + (isActive && root._visiblePlayers.length > 1 ? 4 : 0)
                
                readonly property bool isActive: modelData === root.activePlayer
                readonly property string selectorLabel: {
                    const title = StringUtils.cleanMusicTitle(modelData?.trackTitle) || ""
                    const artist = modelData?.trackArtist ?? ""
                    if (title.length > 0 && artist.length > 0) return `${title} — ${artist}`
                    return title || artist || modelData?.dbusName || Translation.tr("Unknown player")
                }

                function focusPrimaryControl(): void {
                    playerControl.focusPrimaryControl()
                }
                
                Rectangle {
                    visible: root._visiblePlayers.length > 1
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 0
                    anchors.topMargin: Appearance.sizes.elevationMargin
                    anchors.bottomMargin: Appearance.sizes.elevationMargin
                    width: 3
                    radius: 2
                    color: isActive
                        ? (Appearance.zzzEverywhere ? Appearance.zzz.accent
                            : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : (Appearance.zzzEverywhere ? Appearance.zzz.bg3
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer2 : Appearance.colors.colLayer2)
                    
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: 150 }
                    }
                }
                
                PlayerControl {
                    id: playerControl
                    anchors.fill: parent
                    anchors.leftMargin: root._visiblePlayers.length > 1
                        ? Appearance.sizes.elevationMargin : 0
                    player: modelData
                    visualizerPoints: []
                    radius: root.popupRounding
                    screenX: root.screenX + playerDelegate.x + playerControl.x
                    screenY: root.screenY + playerDelegate.y + playerControl.y
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: root._visiblePlayers.length > 1
                        ? Appearance.sizes.elevationMargin : 0
                    visible: playerSelector.activeFocus
                    color: "transparent"
                    radius: root.popupRounding
                    border.width: 2
                    border.color: Appearance.zzzEverywhere ? Appearance.zzz.accent
                        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colPrimary
                        : Appearance.colors.colPrimary
                    z: 2
                }
                
                MouseArea {
                    id: playerSelector
                    anchors.fill: parent
                    visible: !isActive && root._visiblePlayers.length > 1
                    activeFocusOnTab: visible
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Switch media player") + ": " + selectorLabel
                    Accessible.focusable: visible
                    Keys.onPressed: event => {
                        if (event.isAutoRepeat
                                || (event.key !== Qt.Key_Return
                                    && event.key !== Qt.Key_Enter
                                    && event.key !== Qt.Key_Space))
                            return
                        event.accepted = true
                        MprisController.setActivePlayer(modelData)
                        playerControl.focusPrimaryControl()
                    }
                    onClicked: MprisController.setActivePlayer(modelData)
                    cursorShape: Qt.PointingHandCursor
                    z: 3
                }
            }
        }

        // No player placeholder - only show if truly no players after debounce
        Item {
            id: placeholderItem
            readonly property bool _noPlayers: (root.meaningfulPlayers?.length ?? 0) === 0 && (Mpris.players.values?.length ?? 0) === 0
            readonly property bool _cacheEmpty: !root._cacheValid || root._playerCache.length === 0
            visible: _cacheEmpty && _noPlayers
            Layout.fillWidth: true
            implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
            implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

            StyledRectangularShadow {
                target: placeholderBackground
            }

            Rectangle {
                id: placeholderBackground
                anchors.centerIn: parent
                width: Math.min(implicitWidth,
                    Math.max(0, parent.width - Appearance.sizes.elevationMargin))
                color: Appearance.zzzEverywhere ? Appearance.zzz.bg0
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colLayer1
                    : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupSurface
                     : Appearance.colors.colLayer0
                radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.roundingNormal : root.popupRounding
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                border.width: Appearance.zzzEverywhere ? 1 : (Appearance.angelEverywhere ? 0 : ((Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0))
                Behavior on border.width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                border.color: Appearance.zzzEverywhere ? Appearance.zzz.borderColor
                            : Appearance.angelEverywhere ? "transparent"
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colBorder
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colPopupBorder
                            : "transparent"
                Behavior on border.color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                property real padding: 20

                AngelPartialBorder { targetRadius: placeholderBackground.radius; coverage: 0.5 }
                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                ColumnLayout {
                    id: placeholderLayout
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - parent.padding * 2)

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: Translation.tr("No active player")
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.angelEverywhere ? Appearance.angel.colText
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colText
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                            : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : (Appearance.inirEverywhere && Appearance.inir) ? Appearance.inir.colTextSecondary
                            : (Appearance.auroraEverywhere && Appearance.aurora) ? Appearance.aurora.colTextSecondary
                            : Appearance.colors.colSubtext
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
