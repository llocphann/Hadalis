pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

// Session-level device/privacy state.
// Persist continuously instead of only at shutdown so an unclean reboot or power
// loss still restores the last confirmed state from the previous session.
Singleton {
    id: root

    property bool _wifiTracking: false
    property bool _wifiRestoring: false

    property bool _bluetoothTracking: false
    property bool _bluetoothRestoring: false

    property bool _micTracking: false
    property bool _micRestoring: false
    property int _micRestoreRevision: -1

    readonly property int restoreTimeoutMs: 5000

    function _state() {
        return Persistent.states?.deviceState ?? null
    }

    function _tryInitWifi(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !Network.wifiStateKnown
                || root._wifiTracking || root._wifiRestoring)
            return

        if (!state.wifiKnown) {
            state.wifiEnabled = Network.wifiEnabled
            state.wifiKnown = true
            root._wifiTracking = true
            return
        }

        if (Network.wifiEnabled === state.wifiEnabled) {
            root._wifiTracking = true
            return
        }

        root._wifiRestoring = true
        Network.enableWifi(state.wifiEnabled)
        wifiRestoreTimeout.restart()
    }

    function _observeWifi(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !Network.wifiStateKnown)
            return

        if (root._wifiRestoring) {
            if (Network.wifiEnabled === state.wifiEnabled) {
                root._wifiRestoring = false
                root._wifiTracking = true
                wifiRestoreTimeout.stop()
            }
            return
        }

        if (!root._wifiTracking) {
            root._tryInitWifi()
            return
        }

        state.wifiEnabled = Network.wifiEnabled
        state.wifiKnown = true
    }

    function _tryInitBluetooth(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !BluetoothStatus.available
                || root._bluetoothTracking || root._bluetoothRestoring)
            return

        if (!state.bluetoothKnown) {
            state.bluetoothEnabled = BluetoothStatus.enabled
            state.bluetoothKnown = true
            root._bluetoothTracking = true
            return
        }

        if (BluetoothStatus.enabled === state.bluetoothEnabled) {
            root._bluetoothTracking = true
            return
        }

        root._bluetoothRestoring = true
        BluetoothStatus.setEnabled(state.bluetoothEnabled)
        bluetoothRestoreTimeout.restart()
    }

    function _observeBluetooth(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !BluetoothStatus.available)
            return

        if (root._bluetoothRestoring) {
            if (BluetoothStatus.enabled === state.bluetoothEnabled) {
                root._bluetoothRestoring = false
                root._bluetoothTracking = true
                bluetoothRestoreTimeout.stop()
            }
            return
        }

        if (!root._bluetoothTracking) {
            root._tryInitBluetooth()
            return
        }

        state.bluetoothEnabled = BluetoothStatus.enabled
        state.bluetoothKnown = true
    }

    function _tryInitMic(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !Audio.micStateKnown
                || root._micTracking || root._micRestoring)
            return

        if (!state.micKnown) {
            state.micMuted = Audio.micMuted
            state.micKnown = true
            root._micTracking = true
            return
        }

        if (Audio.micMuted === state.micMuted) {
            root._micTracking = true
            return
        }

        root._micRestoring = true
        root._micRestoreRevision = Audio.micStateRevision
        Audio.setMicMuted(state.micMuted)
        micRestoreTimeout.restart()
    }

    function _observeMic(): void {
        const state = root._state()
        if (!state || !Persistent.ready || !Audio.micStateKnown)
            return

        if (root._micRestoring) {
            if (Audio.micStateRevision <= root._micRestoreRevision)
                return

            root._micRestoring = false
            root._micTracking = true
            micRestoreTimeout.stop()

            // If the backend rejected the restore, preserve the previous desired
            // value instead of learning the failed transient state. A later
            // explicit/runtime change will still become the new preference.
            if (Audio.micMuted !== state.micMuted)
                console.warn("[DeviceStatePersistence] microphone mute restore did not converge")
            return
        }

        if (!root._micTracking) {
            root._tryInitMic()
            return
        }

        state.micMuted = Audio.micMuted
        state.micKnown = true
    }

    function _tryInitAll(): void {
        root._tryInitWifi()
        root._tryInitBluetooth()
        root._tryInitMic()
    }

    Connections {
        target: Persistent
        function onReadyChanged(): void {
            if (Persistent.ready)
                Qt.callLater(() => root._tryInitAll())
        }
    }

    Connections {
        target: Network
        function onWifiStateKnownChanged(): void { root._tryInitWifi() }
        function onWifiEnabledChanged(): void { root._observeWifi() }
    }

    Connections {
        target: BluetoothStatus
        function onAvailableChanged(): void { root._tryInitBluetooth() }
        function onEnabledChanged(): void { root._observeBluetooth() }
    }

    Connections {
        target: Audio
        function onMicStateKnownChanged(): void { root._tryInitMic() }
        function onMicStateRevisionChanged(): void { root._observeMic() }
        function onInputDevicesChanged(): void {
            const state = root._state()
            if (root._micTracking && state?.micKnown && state.micMuted)
                Audio.setMicMuted(true)
        }
    }

    Timer {
        id: wifiRestoreTimeout
        interval: root.restoreTimeoutMs
        repeat: false
        onTriggered: {
            if (!root._wifiRestoring) return
            root._wifiRestoring = false
            root._wifiTracking = true
            console.warn("[DeviceStatePersistence] Wi-Fi restore timed out; keeping persisted preference for next startup")
        }
    }

    Timer {
        id: bluetoothRestoreTimeout
        interval: root.restoreTimeoutMs
        repeat: false
        onTriggered: {
            if (!root._bluetoothRestoring) return
            root._bluetoothRestoring = false
            root._bluetoothTracking = true
            console.warn("[DeviceStatePersistence] Bluetooth restore timed out; keeping persisted preference for next startup")
        }
    }

    Timer {
        id: micRestoreTimeout
        interval: root.restoreTimeoutMs
        repeat: false
        onTriggered: {
            if (!root._micRestoring) return
            root._micRestoring = false
            root._micTracking = true
            console.warn("[DeviceStatePersistence] microphone mute restore timed out; keeping persisted preference for next startup")
        }
    }

    Component.onCompleted: {
        if (Persistent.ready)
            Qt.callLater(() => root._tryInitAll())
    }
}
