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
    // Item.visible alone is insufficient for popout lifecycle: an item's local
    // visible flag can remain true while its presentation window is closed.
    // Gate CAVA by the actual Quickshell window so the shared subscription is
    // released as soon as this surface is no longer presented.
    readonly property bool presentationActive: root.QsWindow.window?.visible ?? false
    readonly property bool visualizerActive: root.presentationActive
        && root.visible
        && root._visiblePlayers.length > 0
        && MprisController.isPlaying

    // Keep the bar-attached media popup feature-parity with the dock/global
    // media surface. PlayerControl already owns the WaveVisualizer; the bar
    // popup only needs to provide the same live CAVA point stream instead of
    // the historical empty array.
    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
        // Match the Serpantinum visualizer density while keeping Hadalis'
        // shared CAVA service and per-consumer sample negotiation.
        sampleCount: 64
    }

    property list<real> visualizerPoints: cavaProcess.points
    readonly property real visualizerMaxValue: Math.max(1, cavaProcess.normalizationCeiling)

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
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colLayer2
                    
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
                    visualizerPoints: root.visualizerPoints
                    visualizerMaxValue: root.visualizerMaxValue
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
                    border.color: Appearance.colors.colPrimary
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

        EqualizerPanel {
            Layout.fillWidth: true
            implicitWidth: root.widgetWidth
            active: root.presentationActive && root.visible
        }

    }
}
