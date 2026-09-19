#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
service="$runtime_root/services/deferred/EqualizerService.qml"
backend="$runtime_root/services/deferred/EasyEffects.qml"
helper="$runtime_root/scripts/equalizer-control.sh"
panel="$runtime_root/modules/mediaControls/EqualizerPanel.qml"
player="$runtime_root/modules/mediaControls/PlayerControl.qml"

python3 - "$service" "$backend" "$helper" "$panel" "$player" <<'PY'
import pathlib
import sys

service = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
backend = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
helper = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
panel = pathlib.Path(sys.argv[4]).read_text(encoding="utf-8")
player = pathlib.Path(sys.argv[5]).read_text(encoding="utf-8")

def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise SystemExit(f"FAIL: {source} missing contract token: {token}")

def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise SystemExit(f"FAIL: {source} contains retired/unsafe token: {token}")

# Deferred lifecycle: Media presentation is still the only consumer.
for token in (
    "property bool enabled: false",
    "function registerConsumer()",
    "function unregisterConsumer()",
    "target: root.enabled ? EasyEffects : null",
    "EasyEffects.fetchAvailability()",
    "function startBackend()",
):
    require(service, token, "EqualizerService")

# The fixed ten-band facade and Serpantinum preset curves remain the public UI contract.
for token in (
    "readonly property var dspFrequencies:",
    "[31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]",
    '"Bass":    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2]',
    '"Treble":  [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6]',
    "function setDspBandGain(index, gain)",
    "function applyDspPreset(name)",
    'Quickshell.shellPath("scripts/equalizer-control.sh")',
    'EasyEffects.nativeInstalled ? "native" : "flatpak"',
    '"command -v python3 >/dev/null 2>&1"',
):
    require(service, token, "EqualizerService")

# Runtime compatibility fix: Hadalis must no longer depend on channel-scoped
# EasyEffects local-server properties, which are version-dependent.
for token in (
    "get_property:output:equalizer:0:left:",
    "get_property:output:equalizer:0:right:",
    "set_property:output:equalizer:0:left:",
    "set_property:output:equalizer:0:right:",
    "malformed-band-response",
    "id: bandRefreshProc",
):
    forbid(service, token, "EqualizerService")

# State is accepted only as ten finite clamped values and published after a
# successful apply, so failed backend loads cannot pretend that DSP changed.
for token in (
    "function _normalizeGains(values)",
    "values.length !== root.dspFrequencies.length",
    "Math.max(root.dspMinimumBandGain",
    "property var _pendingGains: []",
    "const normalized = root._normalizeGains(root._pendingGains)",
    'root.error = "dsp-apply-failed"',
):
    require(service, token, "EqualizerService")

# Helper mirrors Serpantinum's 10 -> 32 mapping and only commits persisted state
# after EasyEffects accepts the generic preset-load command. The local server is
# reached directly with Python AF_UNIX so missing socat cannot disable DSP.
for token in (
    'preset_name="hadalis_live_eq"',
    "slider_map = {",
    "0: 0,",
    "1: 3,",
    "2: 6,",
    "3: 9,",
    "4: 12,",
    "5: 15,",
    "6: 18,",
    "7: 21,",
    "8: 24,",
    "9: 27,",
    '"num-bands": 32',
    '"split-channels": False',
    'plugins_order": ["equalizer"]',
    "socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)",
    'client.sendall(f"load_preset:output:{preset}\\n".encode("utf-8"))',
    'mv -f "$state_candidate" "$state_file"',
):
    require(helper, token, "equalizer-control.sh")

load_pos = helper.index('client.sendall(f"load_preset:output:{preset}\\n"')
state_commit_pos = helper.index('mv -f "$state_candidate" "$state_file"')
if state_commit_pos < load_pos:
    raise SystemExit("FAIL: Equalizer state is persisted before backend preset load succeeds")

forbid(helper, "socat", "equalizer-control.sh")

for token in (
    '$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output',
    '${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/output',
    "command -v python3",
):
    require(helper, token, "equalizer-control.sh")

# UI owns only facade calls. It must not contain backend/socket/preset-file logic.
# The persistent trace must use actual rendered handle centers, not a second
# gain-to-y approximation that can drift away from the circles.
for token in (
    "EqualizerService.registerConsumer()",
    "EqualizerService.unregisterConsumer()",
    "model: EqualizerService.dspBands",
    "EqualizerService.setDspBandGain(",
    "function applyPresetWithLightning(name): void",
    "EqualizerService.applyDspPreset(name)",
    "root.triggerPresetSweep()",
    "property real eqLightningHighlight: 0.0",
    "property real eqPresetSweepProgress: -0.12",
    "function triggerPresetSweep(): void",
    "id: presetSweepAnim",
    'property: "eqPresetSweepProgress"',
    "const sweepTail = 0.22",
    "const sweepLead = 0.035",
    "id: lightningCanvas",
    "id: bandRepeater",
    "function lightningPoint()",
    "handleItem.mapToItem(",
    "bandRepeater.itemAt(i)",
    "ctx.lineWidth = 5.5",
    "ctx.lineWidth = 2.4",
    "ctx.lineWidth = 1.0",
    "uniformCellWidths: true",
    "implicitHeight: 24",
):
    require(panel, token, "EqualizerPanel")
for token in ("EasyEffectsServer", "socat", "equalizer-control.sh", "load_preset:output:"):
    forbid(panel, token, "EqualizerPanel")

# Compact media transport controls intentionally keep accessible buttonText but
# no hover popups for Previous / Play-Pause / Next.
for token in (
    'buttonText: Translation.tr("Previous")',
    'buttonText: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")',
    'buttonText: Translation.tr("Next")',
):
    require(player, token, "PlayerControl")
for token in (
    'StyledToolTip { text: Translation.tr("Previous") }',
    'StyledToolTip { text: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play") }',
    'StyledToolTip { text: Translation.tr("Next") }',
):
    forbid(player, token, "PlayerControl")

# Existing EasyEffects native/Flatpak ownership remains unchanged.
for token in (
    'command: ["/usr/bin/env", "flatpak", "ps", "--columns=application"]',
    'l.trim() === "com.github.wwmm.easyeffects"',
    'Quickshell.execDetached(["/usr/bin/env", "easyeffects", "--service-mode"])',
    'Quickshell.execDetached(["/usr/bin/env", "flatpak", "run", "com.github.wwmm.easyeffects", "--service-mode"])',
):
    require(backend, token, "EasyEffects")

print("PASS: Media DSP uses version-compatible preset loading, Serpantinum lightning, and compact transport UI")
PY
