#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/hadalis"
state_file="$state_root/equalizer_state.json"
state_candidate="$state_root/equalizer_state.next.json"
preset_name="hadalis_live_eq"

mkdir -p "$state_root"

emit_default_state() {
    printf '%s\n' '{"gains":[0,0,0,0,0,0,0,0,0,0],"preset":"Flat"}'
}

case "$cmd" in
    get)
        if [[ -s "$state_file" ]]; then
            cat "$state_file"
        else
            emit_default_state
        fi
        ;;

    apply)
        backend="${2:-}"
        preset="${3:-Custom}"
        shift 3 || true

        if [[ "$backend" != "native" && "$backend" != "flatpak" ]]; then
            printf 'invalid backend\n' >&2
            exit 64
        fi
        if [[ "$#" -ne 10 ]]; then
            printf 'expected ten band gains\n' >&2
            exit 64
        fi
        if [[ "$preset" == *:* || "$preset" == *$'\n'* || "$preset" == *$'\r'* ]]; then
            printf 'invalid preset label\n' >&2
            exit 64
        fi

        if [[ "$backend" == "flatpak" ]]; then
            preset_dir="$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output"
        else
            preset_dir="${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/output"
        fi
        mkdir -p "$preset_dir"
        preset_file="$preset_dir/$preset_name.json"

        rm -f "$state_candidate"
        python3 - "$state_candidate" "$preset_file" "$preset" "$@" <<'PY'
import json
import math
import os
import pathlib
import sys
import tempfile

state_path = pathlib.Path(sys.argv[1])
preset_path = pathlib.Path(sys.argv[2])
preset_label = sys.argv[3]
raw_gains = sys.argv[4:]

if len(raw_gains) != 10:
    raise SystemExit(64)

gains = []
for raw in raw_gains:
    value = float(raw)
    if not math.isfinite(value):
        raise SystemExit(64)
    gains.append(max(-12.0, min(12.0, value)))

# Keep the 10 user controls at the same anchor indices used by Serpantinum,
# while feeding EasyEffects' 32-band parametric equalizer.
slider_map = {
    0: 0,
    1: 3,
    2: 6,
    3: 9,
    4: 12,
    5: 15,
    6: 18,
    7: 21,
    8: 24,
    9: 27,
}
frequencies = [
    31, 40, 50, 63, 80, 100, 125, 160,
    200, 250, 315, 400, 500, 630, 800, 1000,
    1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300,
    8000, 10000, 12500, 16000, 20000, 22000, 24000, 24000,
]

bands = {}
gain_by_backend_index = {backend_index: gains[dsp_index]
                         for dsp_index, backend_index in slider_map.items()}
for index in range(32):
    bands[f"band{index}"] = {
        "frequency": frequencies[index],
        "gain": gain_by_backend_index.get(index, 0.0),
        "mode": "Bell",
        "mute": False,
        "q": 1.0,
        "solo": False,
        "width": 1.0,
        "slope": "x1",
    }

document = {
    "output": {
        "blocklist": [],
        "plugins_order": ["equalizer"],
        "equalizer": {
            "bypass": False,
            "input-gain": 0.0,
            "output-gain": 0.0,
            "left": bands,
            "right": bands,
            "mode": "IIR",
            "num-bands": 32,
            "split-channels": False,
        },
    }
}
state = {"gains": gains, "preset": preset_label}

def atomic_json_write(path: pathlib.Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=4)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)

atomic_json_write(preset_path, document)
atomic_json_write(state_path, state)
PY

        sock="${XDG_RUNTIME_DIR:-}/EasyEffectsServer"
        [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$sock" ]] || exit 65
        command -v python3 >/dev/null 2>&1 || exit 127
        if python3 - "$sock" "$preset_name" <<'PY'
import socket
import sys

socket_path = sys.argv[1]
preset = sys.argv[2]
client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client.settimeout(3.0)
try:
    client.connect(socket_path)
    client.sendall(f"load_preset:output:{preset}\n".encode("utf-8"))
finally:
    client.close()
PY
        then
            mv -f "$state_candidate" "$state_file"
        else
            status=$?
            rm -f "$state_candidate"
            exit "$status"
        fi
        ;;

    *)
        printf 'usage: %s {get|apply backend preset gain...}\n' "$0" >&2
        exit 64
        ;;
esac
