#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/hadalis"
state_file="$state_root/equalizer_state.json"
state_candidate="$state_root/equalizer_state.next.json"

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

        sock="${XDG_RUNTIME_DIR:-}/EasyEffectsServer"
        [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$sock" ]] || exit 65
        command -v python3 >/dev/null 2>&1 || exit 127

        rm -f "$state_candidate"
        if python3 - "$sock" "$state_candidate" "$backend" "$preset" "$@" <<'PY'
import copy
import json
import math
import os
import pathlib
import socket
import sys
import tempfile

socket_path = sys.argv[1]
state_path = pathlib.Path(sys.argv[2])
backend = sys.argv[3]
preset_label = sys.argv[4]
raw_gains = sys.argv[5:]

if len(raw_gains) != 10:
    raise SystemExit(64)

gains = []
for raw in raw_gains:
    value = float(raw)
    if not math.isfinite(value):
        raise SystemExit(64)
    gains.append(max(-12.0, min(12.0, value)))

client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client.settimeout(3.0)
try:
    client.connect(socket_path)
    client.sendall(b"get_last_loaded_preset:output\n")

    response = bytearray()
    while b"\n" not in response and len(response) < 4096:
        chunk = client.recv(4096)
        if not chunk:
            break
        response.extend(chunk)

    active_preset = response.partition(b"\n")[0].decode("utf-8", errors="strict").strip()
    if not active_preset:
        print("EasyEffects has no active output preset", file=sys.stderr)
        raise SystemExit(66)
    if active_preset in {".", ".."} or "/" in active_preset or "\\" in active_preset:
        print("EasyEffects returned an unsafe active preset name", file=sys.stderr)
        raise SystemExit(66)

    home = pathlib.Path.home()

    def xdg_home(name: str, fallback: pathlib.Path) -> pathlib.Path:
        raw = os.environ.get(name, "")
        if raw:
            path = pathlib.Path(raw)
            if path.is_absolute():
                return path
        return fallback

    if backend == "flatpak":
        app_root = home / ".var/app/com.github.wwmm.easyeffects"
        preset_candidates = [
            app_root / "data/easyeffects/output" / f"{active_preset}.json",
            app_root / "config/easyeffects/output" / f"{active_preset}.json",
        ]
    else:
        data_home = xdg_home("XDG_DATA_HOME", home / ".local/share")
        config_home = xdg_home("XDG_CONFIG_HOME", home / ".config")
        preset_candidates = [
            data_home / "easyeffects/output" / f"{active_preset}.json",
            config_home / "easyeffects/output" / f"{active_preset}.json",
        ]

    preset_path = next((path for path in preset_candidates if path.is_file()), None)
    if preset_path is None:
        print(
            f'active EasyEffects preset "{active_preset}" is not a writable local preset',
            file=sys.stderr,
        )
        raise SystemExit(66)

    original_text = preset_path.read_text(encoding="utf-8")
    try:
        document = json.loads(original_text)
    except json.JSONDecodeError as error:
        print(f"active EasyEffects preset is invalid JSON: {error}", file=sys.stderr)
        raise SystemExit(66)

    output = document.get("output")
    if not isinstance(output, dict):
        print("active EasyEffects preset has no output pipeline", file=sys.stderr)
        raise SystemExit(66)

    order = output.get("plugins_order")
    if not isinstance(order, list) or not all(isinstance(item, str) for item in order):
        print("active EasyEffects preset has an invalid plugins_order", file=sys.stderr)
        raise SystemExit(66)

    eq_key = next(
        (item for item in order if item == "equalizer" or item.startswith("equalizer#")),
        None,
    )
    if eq_key is None:
        eq_key = next(
            (
                key for key in output
                if key == "equalizer" or key.startswith("equalizer#")
            ),
            None,
        )

    modern_schema = (
        preset_path == preset_candidates[0]
        or any("#" in item for item in order)
        or any(
            "#" in key
            for key in output
            if key not in {"blocklist", "plugins_order"}
        )
    )
    if eq_key is None:
        eq_key = "equalizer#0" if modern_schema else "equalizer"
        order.append(eq_key)

    equalizer = output.get(eq_key)
    if not isinstance(equalizer, dict):
        equalizer = {}
        output[eq_key] = equalizer

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
    gain_by_backend_index = {
        backend_index: gains[dsp_index]
        for dsp_index, backend_index in slider_map.items()
    }

    band_template = None
    left = equalizer.get("left")
    if isinstance(left, dict):
        for band in left.values():
            if isinstance(band, dict):
                band_template = band
                break

    if band_template is None:
        band_template = {
            "mode": "RLC (BT)" if modern_schema else "Bell",
            "mute": False,
            "q": 1.0,
            "solo": False,
            "width": 1.0,
            "slope": "x1",
        }
        if modern_schema:
            band_template["type"] = "Bell"

    bands = {}
    for index in range(32):
        band = copy.deepcopy(band_template)
        band.update({
            "frequency": frequencies[index],
            "gain": gain_by_backend_index.get(index, 0.0),
            "mute": False,
            "q": 1.0,
            "solo": False,
            "width": 1.0,
            "slope": "x1",
        })
        if modern_schema:
            band.setdefault("type", "Bell")
            band.setdefault("mode", "RLC (BT)")
        else:
            band.setdefault("mode", "Bell")
        bands[f"band{index}"] = band

    equalizer.update({
        "bypass": False,
        "left": copy.deepcopy(bands),
        "right": copy.deepcopy(bands),
        "mode": "IIR",
        "num-bands": 32,
        "split-channels": False,
    })
    output["plugins_order"] = order

    state = {"gains": gains, "preset": preset_label}

    def atomic_text_write(path: pathlib.Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(text)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(tmp_name, path)
        finally:
            if os.path.exists(tmp_name):
                os.unlink(tmp_name)

    new_text = json.dumps(document, indent=4) + "\n"
    atomic_text_write(preset_path, new_text)

    try:
        client.sendall(f"load_preset:output:{active_preset}\n".encode("utf-8"))
    except Exception:
        atomic_text_write(preset_path, original_text)
        raise

    atomic_text_write(state_path, json.dumps(state, indent=4) + "\n")
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
