#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root/scripts/equalizer-control.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/hadalis-eq-active.XXXXXX")"
server_pid=""

cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf -- "$tmp"
}
trap cleanup EXIT

export HOME="$tmp/home"
export XDG_DATA_HOME="$tmp/data"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"
export XDG_RUNTIME_DIR="$tmp/runtime"

mkdir -p "$HOME" "$XDG_DATA_HOME/easyeffects/output" \
    "$XDG_CONFIG_HOME/easyeffects/output" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"

preset_file="$XDG_DATA_HOME/easyeffects/output/Music.json"
cat >"$preset_file" <<'JSON'
{
    "output": {
        "blocklist": ["keep-me"],
        "compressor#0": {
            "bypass": false,
            "threshold": -18.0
        },
        "equalizer#0": {
            "balance": 0.25,
            "bypass": false,
            "input-gain": -1.5,
            "left": {
                "band0": {
                    "frequency": 100.0,
                    "gain": 1.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 2.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 2.0
                }
            },
            "mode": "IIR",
            "num-bands": 1,
            "output-gain": 2.0,
            "right": {
                "band0": {
                    "frequency": 100.0,
                    "gain": 1.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 2.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 2.0
                }
            },
            "split-channels": false
        },
        "plugins_order": [
            "compressor#0",
            "equalizer#0"
        ]
    }
}
JSON

server_log="$tmp/server.log"
python3 - "$XDG_RUNTIME_DIR/EasyEffectsServer" "$server_log" <<'PY' &
import pathlib
import socket
import sys

socket_path = pathlib.Path(sys.argv[1])
log_path = pathlib.Path(sys.argv[2])

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(str(socket_path))
server.listen(1)
conn, _ = server.accept()
with conn:
    first = b""
    while not first.endswith(b"\n"):
        chunk = conn.recv(4096)
        if not chunk:
            break
        first += chunk
    if first != b"get_last_loaded_preset:output\n":
        raise SystemExit(f"unexpected first command: {first!r}")
    conn.sendall(b"Music\n")

    second = b""
    while not second.endswith(b"\n"):
        chunk = conn.recv(4096)
        if not chunk:
            break
        second += chunk
    if second != b"load_preset:output:Music\n":
        raise SystemExit(f"unexpected second command: {second!r}")

log_path.write_text(
    first.decode("utf-8") + second.decode("utf-8"),
    encoding="utf-8",
)
server.close()
PY
server_pid=$!

for _ in $(seq 1 100); do
    [[ -S "$XDG_RUNTIME_DIR/EasyEffectsServer" ]] && break
    sleep 0.01
done
[[ -S "$XDG_RUNTIME_DIR/EasyEffectsServer" ]] || {
    printf 'FAIL: fake EasyEffects server did not start\n' >&2
    exit 1
}

"$helper" apply native Bass 5 7 5 2 1 0 0 0 1 2
wait "$server_pid"
server_pid=""

python3 - "$preset_file" "$XDG_STATE_HOME/hadalis/equalizer_state.json" "$server_log" <<'PY'
import json
import pathlib
import sys

preset_path = pathlib.Path(sys.argv[1])
state_path = pathlib.Path(sys.argv[2])
log_path = pathlib.Path(sys.argv[3])

preset = json.loads(preset_path.read_text(encoding="utf-8"))
output = preset["output"]
if output["plugins_order"] != ["compressor#0", "equalizer#0"]:
    raise SystemExit("FAIL: existing plugin order changed")
if output["blocklist"] != ["keep-me"]:
    raise SystemExit("FAIL: output blocklist was replaced")
if output["compressor#0"] != {"bypass": False, "threshold": -18.0}:
    raise SystemExit("FAIL: non-equalizer effect was modified")

eq = output["equalizer#0"]
if eq["balance"] != 0.25 or eq["input-gain"] != -1.5 or eq["output-gain"] != 2.0:
    raise SystemExit("FAIL: unrelated equalizer settings were replaced")
if eq["num-bands"] != 32 or eq["split-channels"] is not False:
    raise SystemExit("FAIL: Hadalis 32-band equalizer shape was not applied")

expected = {0: 5.0, 3: 7.0, 6: 5.0, 9: 2.0, 12: 1.0,
            15: 0.0, 18: 0.0, 21: 0.0, 24: 1.0, 27: 2.0}
for index in range(32):
    left = eq["left"][f"band{index}"]
    right = eq["right"][f"band{index}"]
    target = expected.get(index, 0.0)
    if left["gain"] != target or right["gain"] != target:
        raise SystemExit(f"FAIL: band{index} gain mismatch")
    if left["frequency"] != right["frequency"]:
        raise SystemExit(f"FAIL: band{index} channel frequencies diverged")

state = json.loads(state_path.read_text(encoding="utf-8"))
if state["preset"] != "Bass" or state["gains"] != [5.0, 7.0, 5.0, 2.0, 1.0, 0.0, 0.0, 0.0, 1.0, 2.0]:
    raise SystemExit("FAIL: Hadalis DSP state did not commit after reload")

commands = log_path.read_text(encoding="utf-8")
if commands != "get_last_loaded_preset:output\nload_preset:output:Music\n":
    raise SystemExit("FAIL: active preset was not queried and reloaded in place")

if any(p.name == "hadalis_live_eq.json" for p in preset_path.parent.iterdir()):
    raise SystemExit("FAIL: retired Hadalis scratch preset was recreated")
PY

printf 'PASS: EQ DSP patches and reloads the active EasyEffects preset without creating a new preset\n'
