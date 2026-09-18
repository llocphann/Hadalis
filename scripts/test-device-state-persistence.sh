#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
persist="$root/modules/common/Persistent.qml"
service="$root/services/DeviceStatePersistence.qml"
network="$root/services/Network.qml"
bluetooth="$root/services/BluetoothStatus.qml"
audio="$root/services/Audio.qml"
qmldir="$root/services/qmldir"
shell="$root/shell.qml"

fail() {
    printf 'FAIL: device-state persistence contract: %s\n' "$1" >&2
    exit 1
}

for f in "$persist" "$service" "$network" "$bluetooth" "$audio" "$qmldir" "$shell"; do
    [[ -f "$f" ]] || fail "missing ${f#$root/}"
done

grep -Fq 'import Quickshell' "$service" \
    || fail 'Singleton service must import Quickshell'

for token in     'property JsonObject deviceState: JsonObject {'     'property bool wifiKnown: false'     'property bool bluetoothKnown: false'     'property bool micKnown: false'; do
    grep -Fq "$token" "$persist" || fail "Persistent schema missing: $token"
done

grep -Fq 'singleton DeviceStatePersistence 1.0 DeviceStatePersistence.qml' "$qmldir"     || fail 'DeviceStatePersistence must be registered'
grep -Fq 'property var _deviceStatePersistence: DeviceStatePersistence' "$shell"     || fail 'device state restore must be startup-resident, not panel-lazy'

grep -Fq 'property bool wifiStateKnown: false' "$network"     || fail 'Network must distinguish real radio state from declaration default'
grep -Fq 'root.wifiStateKnown = true' "$network"     || fail 'Network must mark Wi-Fi state known only after nmcli observation'
grep -Fq 'onExited: root.update()' "$network"     || fail 'Wi-Fi writes must refresh observed state'

grep -Fq 'function setEnabled(value: bool): void' "$bluetooth"     || fail 'BluetoothStatus needs an explicit restore setter'
grep -Fq 'function toggle(): void' "$bluetooth"     || fail 'BluetoothStatus toggle API must remain available'

grep -Fq 'property bool micStateKnown: false' "$audio"     || fail 'Audio must distinguish verified mic state from declaration default'
grep -Fq 'property int micStateRevision: 0' "$audio"     || fail 'Audio must expose confirmed mic refresh generations'
grep -Fq 'function setMicMuted(muted: bool): void' "$audio"     || fail 'Audio needs an explicit mic restore setter'
grep -Fq 'root.micStateRevision += 1' "$audio"     || fail 'confirmed wpctl mic observations must advance the revision'

for token in     'if (!state.wifiKnown)'     'if (!state.bluetoothKnown)'     'if (!state.micKnown)'     'Network.enableWifi(state.wifiEnabled)'     'BluetoothStatus.setEnabled(state.bluetoothEnabled)'     'Audio.setMicMuted(state.micMuted)'     'state.wifiEnabled = Network.wifiEnabled'     'state.bluetoothEnabled = BluetoothStatus.enabled'     'state.micMuted = Audio.micMuted'; do
    grep -Fq "$token" "$service" || fail "restore/observe contract missing: $token"
done

printf 'device-state persistence guards: ok\n'
