#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="$(cd -- "$script_dir/.." && pwd)"
service="$runtime_root/services/deferred/EqualizerService.qml"

python3 - "$service" <<'PY'
import pathlib
import sys

service = pathlib.Path(sys.argv[1])
text = service.read_text(encoding="utf-8")

required = [
    "property bool enabled: false",
    "target: root.enabled ? EasyEffects : null",
    "function _retryStaleTransportProbe(generation)",
    "Qt.callLater(() => {",
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"FAIL: EqualizerService contract marker missing: {marker}")

probe_start = text.index("id: transportProbe")
probe_end = text.index("id: presetScanProc", probe_start)
probe = text[probe_start:probe_end]

stale_branch = """if (generation !== root._lifecycleGeneration) {
                root._retryStaleTransportProbe(generation)
                return
            }"""
if probe.count(stale_branch) < 2:
    raise SystemExit(
        "FAIL: stale Equalizer transport completions do not retry the current lifecycle generation"
    )

if "if (!root.enabled)\n                return" not in probe:
    raise SystemExit("FAIL: disabled Equalizer transport completion is not ignored")

preset_scan_start = text.index("id: presetScanProc")
preset_scan_end = text.index("id: activePresetProc", preset_scan_start)
preset_scan_block = text[preset_scan_start:preset_scan_end]
if 'if (root.error === "preset-scan-failed")\n                root.error = ""' not in preset_scan_block:
    raise SystemExit("FAIL: successful preset scan does not clear its recovered error")

preset_query_start = text.index("id: activePresetProc")
preset_query_end = text.index("id: bandRefreshProc", preset_query_start)
preset_query_block = text[preset_query_start:preset_query_end]
if 'if (root.error === "preset-query-failed")\n                root.error = ""' not in preset_query_block:
    raise SystemExit("FAIL: successful preset query does not clear its recovered error")

band_refresh_start = text.index("id: bandRefreshProc")
band_refresh_end = text.index("id: applyPresetProc", band_refresh_start)
band_refresh_block = text[band_refresh_start:band_refresh_end]
empty_value_guard = "if (values.some(value => value.trim().length === 0))"
value_parse = "const leftGain = Number(values[0])"
if empty_value_guard not in band_refresh_block:
    raise SystemExit("FAIL: empty Equalizer band fields can still coerce to numeric zero")
if band_refresh_block.index(empty_value_guard) > band_refresh_block.index(value_parse):
    raise SystemExit("FAIL: Equalizer band fields are validated only after numeric coercion")

apply_start = text.index("function applyPreset(")
apply_end = text.index("function setBandGain(", apply_start)
apply_block = text[apply_start:apply_end]

for marker in [
    "if (!root._canMutate())",
    'preset.includes(":")',
    r'preset.includes("\n")',
    r'preset.includes("\r")',
    '"sh", "load_preset:output:" + preset]',
]:
    if marker not in apply_block:
        raise SystemExit(
            f"FAIL: Equalizer preset protocol/input guard missing: {marker}"
        )

band_start = text.index("function setBandGain(")
band_end = text.index("function reset(", band_start)
band_block = text[band_start:band_end]

for marker in [
    "if (!root._canMutate())",
    "Math.floor(bandIndex) !== bandIndex",
    "!isFinite(requestedGain)",
    "bandIndex < 0 || bandIndex >= root.bands.length",
    "root.bands[bandIndex]?.synced !== true",
    "Math.max(root.minimumBandGain, Math.min(root.maximumBandGain, requestedGain))",
    '"sh", String(bandIndex), String(clampedGain)]',
]:
    if marker not in band_block:
        raise SystemExit(
            f"FAIL: Equalizer band protocol/input guard missing: {marker}"
        )

print(
    "PASS: Equalizer lifecycle, recovery, parsing, and protocol inputs remain guarded"
)
PY
