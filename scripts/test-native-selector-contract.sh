#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

dispatch="$root/scripts/native-dispatch"
harness="$root/scripts/native-cutover-benchmark.sh"

[[ -x "$dispatch" ]] || fail 'native-dispatch must be executable'
[[ -x "$harness" ]] || fail 'native cutover harness must be executable'

for token in     'input-lock)'     'input-keys)'     'niri)'     'diagnostics)'     'clipboard-store)'     'mpd)'     'mpd-daemon)'     'mpd-subscribe)'     'theme)'     'desktop-icons)'
do
    grep -Fq "$token" "$dispatch"         || fail "native-dispatch missing route: $token"
done

grep -Fq 'command: [root.nativeDispatchPath, "input-lock", "--once"]'     "$root/services/KeyboardIndicators.qml"     || fail 'KeyboardIndicators probe must route through native-dispatch'
grep -Fq 'command: [root.nativeDispatchPath, "input-lock"]'     "$root/services/KeyboardIndicators.qml"     || fail 'KeyboardIndicators monitor must route through native-dispatch'
grep -Fq 'command: [root.nativeDispatchPath, "input-keys"]'     "$root/modules/onScreenKeyboard/PhysicalKeyboardFeedback.qml"     || fail 'OSK physical keyboard feedback must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "diagnostics"'     "$root/services/RuntimeDiagnostics.qml"     || fail 'RuntimeDiagnostics must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "mpd",'     "$root/services/LocalMusic.qml"     || fail 'LocalMusic MPD operations must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "mpd-daemon",'     "$root/services/LocalMusic.qml"     || fail 'LocalMusic persistent MPD daemon must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "mpd-subscribe"'     "$root/services/LocalMusic.qml"     || fail 'LocalMusic MPD idle subscription must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "niri",'     "$root/modules/settings/NiriConfig.qml"     || fail 'Niri settings must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "niri", "get-binds"'     "$root/services/deferred/NiriKeybinds.qml"     || fail 'Niri enriched keybind loader must route through native-dispatch'
grep -Fq '_applyLegacyFromEnriched'     "$root/services/deferred/NiriKeybinds.qml"     || fail 'Niri cheatsheet must derive from the selector-backed get-binds result before legacy fallback'
grep -Fq '"niri",' "$root/services/NiriService.qml"     || fail 'NiriService hot-corner query must route through native-dispatch'
grep -Fq '"niri",' "$root/services/Wallpapers.qml"     || fail 'Wallpaper Niri shadow sync must route through native-dispatch'
grep -Fq 'root.nativeDispatchPath, "niri", "persist-layout"'     "$root/modules/settings/MonitorVisibilityConfig.qml"     || fail 'monitor layout persistence must route through native-dispatch'
grep -Fq "native-dispatch' clipboard-store --filter"     "$root/services/deferred/Cliphist.qml"     || fail 'Cliphist decode filter must route through native-dispatch'
grep -Fq 'native-dispatch clipboard-store'     "$root/defaults/niri/config.d/50-startup.kdl"     || fail 'default Niri clipboard watcher must route through native-dispatch'
grep -Fq 'native-dispatch clipboard-store'     "$root/sdata/migrations/049-native-clipboard-selector.sh"     || fail 'existing clipboard watchers must migrate through native-dispatch'
grep -Fq '"$SCRIPT_DIR/../native-dispatch" theme'     "$root/scripts/colors/switchwall.sh"     || fail 'theme pipeline must route through native-dispatch'
grep -Fq 'nativeIconSyncProc' "$root/services/IconThemeService.qml"     || fail 'IconThemeService must expose native sync test path'
grep -Fq 'nativeBackendStatePath' "$root/services/IconThemeService.qml"     || fail 'IconThemeService must honor persistent trial selector state after reboot'
grep -Fq '/inir-inputd([[:space:]]|$)' "$root/scripts/inir"     || fail 'shell restart cleanup must recognize Rust input daemon'
grep -Fq '/inir-native[[:space:]]+diagnostics' "$root/scripts/inir"     || fail 'shell restart cleanup must recognize Rust diagnostics sampler'

# The trial cutover harness must remain reversible.
grep -Fq 'measure_service_mode rust' "$harness"     || fail 'cutover harness must activate and measure Rust explicitly'
grep -Fq 'INIR_NATIVE_BACKEND=python' "$harness"     || fail 'cutover harness must provide Python rollback'
grep -Fq 'BACKEND_STATE_FILE="$STATE_DIR/native-backend"' "$harness"     || fail 'cutover harness must persist selector state for Niri-spawned helpers'
grep -Fq 'MODE_FILE="$STATE_DIR/native-backend"' "$dispatch"     || fail 'native-dispatch must read persistent selector state when env is absent'
grep -Fq 'BIN_DIR_FILE="$STATE_DIR/native-bin-dir"' "$dispatch"     || fail 'native-dispatch must read persistent native binary path for Niri-spawned helpers'
grep -Fq -- '--restore' "$harness"     || fail 'cutover harness must expose --restore'

# Never remove the Python fallback while this is still a trial cutover.
for fallback in     scripts/daemon/keyboard_lock_state_daemon.py     scripts/daemon/osk_physical_key_daemon.py     scripts/runtime-diagnostics-sampler.py     scripts/local_music_mpd.py     scripts/niri-config.py     scripts/clipboard-store.py     scripts/colors/generate_colors_material.py
do
    [[ -f "$root/$fallback" ]] || fail "Python fallback missing: $fallback"
done

printf 'PASS: native runtime selector is wired and reversible\n'
