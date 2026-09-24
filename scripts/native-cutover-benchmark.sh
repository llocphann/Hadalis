#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
mkdir -p "$STATE_DIR"
BACKEND_STATE_FILE="$STATE_DIR/native-backend"
BIN_STATE_FILE="$STATE_DIR/native-bin-dir"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${INIR_NATIVE_REPORT:-$STATE_DIR/native-cutover-$STAMP.txt}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/inir-native-test.XXXXXX")"
BIN_DIR="$ROOT_DIR/native/target/release"
DISPATCH="$ROOT_DIR/scripts/native-dispatch"
ACTIVE_RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
ACTIVE_RUNTIME="$(readlink -f "$ACTIVE_RUNTIME" 2>/dev/null || printf '%s' "$ACTIVE_RUNTIME")"
ACTIVATION_BLOCKERS=()
RUNTIME_MODE="unchanged"
MPD_DAEMON_PID=""

case "${1:-}" in
    ""|--no-activate|--restore) ;;
    *) echo "usage: $0 [--no-activate|--restore]" >&2; exit 64 ;;
esac

cleanup() {
    if [[ -n "$MPD_DAEMON_PID" ]]; then
        kill "$MPD_DAEMON_PID" 2>/dev/null || true
        wait "$MPD_DAEMON_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

exec > >(tee "$REPORT") 2>&1

section() {
    printf '\n===== %s =====\n' "$1"
}

kv() {
    printf '%-32s %s\n' "$1" "$2"
}

block_activation() {
    ACTIVATION_BLOCKERS+=("$1")
    kv "activation blocker" "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_gate() {
    local label="$1"
    local failure_code="$2"
    shift 2
    local log="$TMP_ROOT/gate-${label//[^A-Za-z0-9_.-]/_}.log"
    local rc
    if "$@" >"$log" 2>&1; then
        kv "$label" "PASS"
        return 0
    else
        rc=$?
    fi
    kv "$label" "FAIL exit=$rc"
    echo "--- $label log tail ---"
    tail -n 120 "$log" || true
    exit "$failure_code"
}

bench() {
    local label="$1"
    shift
    if ! python3 - "$label" "${BENCH_RUNS:-5}" "$@" <<'PY'
import os
import resource
import statistics
import subprocess
import sys
import time

label, runs_text, *command = sys.argv[1:]
runs = int(runs_text)
if runs < 1:
    raise ValueError("BENCH_RUNS must be positive")
samples = []
for _ in range(runs):
    input_path = os.environ.get("INIR_BENCH_STDIN")
    with open(input_path, "rb") if input_path else open(os.devnull, "rb") as input_file:
        started = time.perf_counter_ns()
        process = subprocess.Popen(command, stdin=input_file,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        wall_ms = (time.perf_counter_ns() - started) / 1_000_000
    if process.returncode:
        print(f"{label:<32} ERROR exit={process.returncode}")
        sys.exit(1)
    samples.append((wall_ms, usage.ru_utime * 1000, usage.ru_stime * 1000,
                    usage.ru_maxrss))
walls = sorted(row[0] for row in samples)
def percentile(values, fraction):
    if len(values) == 1:
        return values[0]
    position = (len(values) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(values) - 1)
    weight = position - lower
    return values[lower] * (1.0 - weight) + values[upper] * weight

print(f"{label:<32} avg_wall={statistics.mean(walls):.3f}ms "
      f"p50={statistics.median(walls):.3f}ms "
      f"p95={percentile(walls, 0.95):.3f}ms "
      f"min={walls[0]:.3f}ms max={walls[-1]:.3f}ms "
      f"stdev={(statistics.stdev(walls) if len(walls) > 1 else 0.0):.3f}ms "
      f"avg_user={statistics.mean(row[1] for row in samples):.3f}ms "
      f"avg_sys={statistics.mean(row[2] for row in samples):.3f}ms "
      f"max_rss={max(row[3] for row in samples)}KiB runs={runs}")
PY
    then
        block_activation "benchmark failed: $label"
    fi
}

proc_metrics() {
    local label="$1"
    shift
    local seconds="${SAMPLE_SECONDS:-3}"
    local out="$TMP_ROOT/$label.out"
    "$@" >"$out" 2>"$TMP_ROOT/$label.err" &
    local pid=$!
    sleep 0.4
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" || true
        kv "$label" "ERROR exited early: $(tr '\n' ' ' < "$TMP_ROOT/$label.err" | head -c 300)"
        return 1
    fi
    local pss0 rss0 ticks0 pss1 rss1 ticks1 hz
    pss0="$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)"
    rss0="$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo 0)"
    ticks0="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo 0)"
    sleep "$seconds"
    if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" || true
        kv "$label" "ERROR exited during sampling"
        return 1
    fi
    pss1="$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo "$pss0")"
    rss1="$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo "$rss0")"
    ticks1="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo "$ticks0")"
    hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    awk -v label="$label" -v p0="$pss0" -v p1="$pss1" -v r0="$rss0" -v r1="$rss1"         -v t0="$ticks0" -v t1="$ticks1" -v hz="$hz" -v sec="$seconds"         'BEGIN{cpu=((t1-t0)/hz)/sec*100; printf "%-32s pss=%d->%dKiB rss=%d->%dKiB cpu_window=%.3f%%\n",label,p0,p1,r0,r1,cpu}'
}

json_compare() {
    python3 - "$@" <<'PY'
import json
import sys

left_path, right_path, *keys = sys.argv[1:]
try:
    with open(left_path) as handle:
        left = json.load(handle)
    with open(right_path) as handle:
        right = json.load(handle)
    if keys == ["--mpd-status"]:
        keys = ["connected", "status", "current", "queue", "musicRoot"]
        for value in (left, right):
            if isinstance(value.get("status"), dict):
                for volatile in ("elapsed", "time", "bitrate"):
                    value["status"].pop(volatile, None)
    if keys == ["--mpd-snapshot"]:
        # Full snapshots include live playback state. Deep parity focuses on the
        # stable library model and shares an isolated cache so file:// cover URLs
        # remain directly comparable without touching the user's real cache.
        keys = ["connected", "musicRoot", "tracks", "playlists", "folders"]
    if keys == ["--theme-meta"]:
        keys = []
        left.pop("generated_by", None)
        right.pop("generated_by", None)
    if keys:
        left = {key: left[key] for key in keys}
        right = {key: right[key] for key in keys}
except (OSError, ValueError, KeyError) as error:
    print(f"ERROR invalid JSON or missing key: {error}")
    sys.exit(1)

differences = []
def compare(a, b, path="root"):
    if isinstance(a, dict) and isinstance(b, dict):
        for key in sorted(a.keys() | b.keys()):
            if key not in a or key not in b:
                differences.append(f"{path}.{key}")
            else:
                compare(a[key], b[key], f"{path}.{key}")
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            differences.append(f"{path}.length")
        for index, (item_a, item_b) in enumerate(zip(a, b)):
            compare(item_a, item_b, f"{path}[{index}]")
    elif a != b:
        differences.append(path)

compare(left, right)
if differences:
    print(f"DIFF count={len(differences)} first={','.join(differences[:6])}")
    sys.exit(1)
print("PASS")
PY
}

set_runtime_backend() {
    local mode="$1"
    printf '%s\n' "$mode" > "$BACKEND_STATE_FILE"
    printf '%s\n' "$BIN_DIR" > "$BIN_STATE_FILE"
    systemctl --user set-environment \
        INIR_NATIVE_BACKEND="$mode" INIR_NATIVE_BIN_DIR="$BIN_DIR" INIR_NATIVE_STRICT=0 || return 1
    "$ROOT_DIR/scripts/inir" restart || systemctl --user restart inir.service || return 1
    systemctl --user is-active --quiet inir.service
}

measure_service_mode() {
    local mode="$1"
    local window="${LIVE_WINDOW_SECONDS:-5}"
    set_runtime_backend "$mode" || return 1
    sleep 4

    local pid mem tasks cpu0 cpu1 delta shell_pss shell_rss
    pid="$(systemctl --user show -p MainPID --value inir.service 2>/dev/null || echo 0)"
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    mem="$(systemctl --user show -p MemoryCurrent --value inir.service 2>/dev/null || echo unknown)"
    tasks="$(systemctl --user show -p TasksCurrent --value inir.service 2>/dev/null || echo unknown)"
    cpu0="$(systemctl --user show -p CPUUsageNSec --value inir.service 2>/dev/null || echo 0)"
    shell_pss="$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)"
    shell_rss="$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo 0)"
    sleep "$window"
    cpu1="$(systemctl --user show -p CPUUsageNSec --value inir.service 2>/dev/null || echo 0)"
    if [[ "$cpu0" =~ ^[0-9]+$ && "$cpu1" =~ ^[0-9]+$ ]]; then
        delta=$((cpu1-cpu0))
    else
        delta=0
    fi

    awk -v mode="$mode" -v pid="$pid" -v mem="$mem" -v tasks="$tasks"         -v delta="$delta" -v window="$window" -v cpu0="$cpu0" -v pss="$shell_pss" -v rss="$shell_rss"         'BEGIN{
            mib=(mem ~ /^[0-9]+$/) ? mem/1048576 : -1;
            cpu=(window>0) ? delta/(window*1000000000)*100 : 0;
            startup=(cpu0 ~ /^[0-9]+$/) ? cpu0/1000000 : -1;
            if (mib >= 0)
                printf "live %-7s pid=%s cgroup_mem=%.2fMiB shell_pss=%dKiB shell_rss=%dKiB tasks=%s startup_cpu=%.1fms cpu_window=%.3f%%\n",mode,pid,mib,pss,rss,tasks,startup,cpu;
            else
                printf "live %-7s pid=%s cgroup_mem=%s shell_pss=%dKiB shell_rss=%dKiB tasks=%s startup_cpu=%.1fms cpu_window=%.3f%%\n",mode,pid,mem,pss,rss,tasks,startup,cpu;
        }'

    printf 'processes(%s):\n' "$mode"
    ps -eo pid,ppid,rss,etimes,comm,args         | grep -E 'quickshell|inir-inputd|inir-mpdd|inir-native|inir-theme|keyboard_lock_state_daemon|osk_physical_key_daemon|runtime-diagnostics-sampler'         | grep -v grep || true
}

activate_rust() {
    section "LIVE SHELL A/B"
    local relative
    for relative in \
        scripts/native-dispatch scripts/inir scripts/colors/switchwall.sh \
        services/KeyboardIndicators.qml services/RuntimeDiagnostics.qml \
        services/NiriService.qml services/LocalMusic.qml services/IconThemeService.qml \
        services/Wallpapers.qml services/deferred/Cliphist.qml \
        services/deferred/NiriKeybinds.qml \
        modules/onScreenKeyboard/PhysicalKeyboardFeedback.qml \
        modules/settings/NiriConfig.qml modules/settings/MonitorVisibilityConfig.qml; do
        if ! cmp -s "$ROOT_DIR/$relative" "$ACTIVE_RUNTIME/$relative"; then
            block_activation "installed runtime differs from tested $relative"
        fi
    done
    if ((${#ACTIVATION_BLOCKERS[@]})); then
        kv "live A/B" "SKIP (${#ACTIVATION_BLOCKERS[@]} blocker(s))"
        return 1
    fi
    if ! systemctl --user is-active --quiet inir.service; then
        block_activation "inir.service is not active"
        kv "live A/B" "SKIP (no active service)"
        return 1
    fi
    echo "Measuring the same inir.service once with Python selected, then with Rust selected."
    if ! measure_service_mode python; then
        block_activation "Python baseline service restart failed"
        if ! restore_python; then
            block_activation "automatic Python rollback failed"
            RUNTIME_MODE="unknown after rollback failure"
        fi
        return 1
    fi
    RUNTIME_MODE="python baseline active"
    if ! measure_service_mode rust; then
        block_activation "Rust-selected service restart failed"
        if ! restore_python; then
            block_activation "automatic Python rollback failed"
            RUNTIME_MODE="unknown after rollback failure"
        fi
        return 1
    fi
    local active_info
    active_info="$(env -u INIR_NATIVE_BACKEND -u INIR_NATIVE_BIN_DIR \
        "$ACTIVE_RUNTIME/scripts/native-dispatch" backend-info 2>&1)"
    if [[ "$active_info" != *$'mode=rust\n'* || "$active_info" != *"bin_dir=$BIN_DIR"* ]]; then
        block_activation "installed selector did not retain Rust mode and binary path"
        if ! restore_python; then
            block_activation "automatic Python rollback failed"
            RUNTIME_MODE="unknown after rollback failure"
        fi
        return 1
    fi
    RUNTIME_MODE="rust test mode active"

    section "PERSISTENT SELECTOR CHECK"
    echo "The following call intentionally removes selector env vars; it must still report rust"
    echo "from the state files so Niri-spawned clipboard helpers can participate."
    printf '%s\n' "$active_info"
    printf '\nCurrent text clipboard watcher(s):\n'
    pgrep -af 'wl-paste.*--type text.*--watch' 2>/dev/null || echo "none detected"
    if pgrep -af 'wl-paste.*--type text.*--watch.*clipboard-store\.py' >/dev/null 2>&1; then
        echo "NOTE: current Niri session still has the pre-selector clipboard watcher."
        echo "The migration updates its config for the next Niri session; direct clipboard A/B above is valid now."
    fi

    section "RUST TEST MODE STATUS"
    systemctl --user --no-pager --full status inir.service 2>&1 | sed -n '1,35p' || true
    printf '\nRecent selector/fallback messages:\n'
    journalctl --user -u inir.service --since '-3 minutes' --no-pager 2>&1         | grep -E 'native-dispatch|inir-inputd|inir-native|inir-mpdd|inir-theme|falling back|Failed|failed|error'         | tail -n 120 || true
}

verify_python_restore() {
    local selector="$DISPATCH"
    local state info manager_env

    if [[ -x "$ACTIVE_RUNTIME/scripts/native-dispatch" ]]; then
        selector="$ACTIVE_RUNTIME/scripts/native-dispatch"
    fi

    state="$(head -n 1 "$BACKEND_STATE_FILE" 2>/dev/null || true)"
    if [[ "$state" != python ]]; then
        kv "restore state" "FAIL (native-backend=$state)"
        return 1
    fi

    info="$(env -u INIR_NATIVE_BACKEND -u INIR_NATIVE_BIN_DIR -u INIR_NATIVE_STRICT \
        "$selector" backend-info 2>&1)" || {
        kv "restore selector" "FAIL (backend-info unavailable)"
        return 1
    }
    if ! grep -Fxq 'mode=python' <<<"$info"; then
        kv "restore selector" "FAIL (selector did not report mode=python)"
        printf '%s\n' "$info"
        return 1
    fi

    manager_env="$(systemctl --user show-environment 2>/dev/null)" || {
        kv "restore manager env" "FAIL (show-environment unavailable)"
        return 1
    }
    if ! grep -Fxq 'INIR_NATIVE_BACKEND=python' <<<"$manager_env"; then
        kv "restore manager env" "FAIL (backend is not python)"
        return 1
    fi
    if grep -Eq '^INIR_NATIVE_(BIN_DIR|STRICT)=' <<<"$manager_env"; then
        kv "restore manager env" "FAIL (Rust selector variables remain)"
        return 1
    fi
    if ! systemctl --user is-active --quiet inir.service; then
        kv "restore service" "FAIL (inir.service inactive)"
        return 1
    fi

    kv "restore selector" "mode=python"
    kv "restore service" "active"
    return 0
}

restore_python() {
    section "RESTORE PYTHON MODE"
    printf '%s\n' python > "$BACKEND_STATE_FILE"
    rm -f "$BIN_STATE_FILE"
    systemctl --user set-environment INIR_NATIVE_BACKEND=python || return 1
    systemctl --user unset-environment INIR_NATIVE_BIN_DIR INIR_NATIVE_STRICT || true
    "$ROOT_DIR/scripts/inir" restart || systemctl --user restart inir.service || return 1
    verify_python_restore || return 1
    RUNTIME_MODE="python restored"
    kv "backend" "python"
}

if [[ "${1:-}" == "--restore" ]]; then
    restore_python || { kv "backend" "RESTORE FAILED (inspect inir.service)"; exit 1; }
    printf '\nReport: %s\n' "$REPORT"
    exit 0
fi

section "SYSTEM"
kv "date" "$(date --iso-8601=seconds)"
kv "host" "$(uname -n)"
kv "kernel" "$(uname -srmo)"
kv "repo" "$ROOT_DIR"
kv "git_head" "$(git rev-parse HEAD 2>/dev/null || echo unknown)"
kv "active_runtime" "$ACTIVE_RUNTIME"
if [[ -x "$ACTIVE_RUNTIME/scripts/native-dispatch" ]]; then
    kv "active_runtime_selector" "ready"
else
    kv "active_runtime_selector" "missing"
fi
kv "niri" "$(niri --version 2>/dev/null || echo unavailable)"
kv "quickshell" "$(qs --version 2>/dev/null || echo unavailable)"
kv "rustc" "$(rustc --version 2>/dev/null || echo unavailable)"
kv "cargo" "$(cargo --version 2>/dev/null || echo unavailable)"
kv "python" "$(python3 --version 2>&1 || echo unavailable)"
kv "mpd" "$(mpd --version 2>/dev/null | sed -n '1p' || echo unavailable)"
kv "backend_before" "${INIR_NATIVE_BACKEND:-python(default)}"
kv "backend_state_file" "$BACKEND_STATE_FILE ($(cat "$BACKEND_STATE_FILE" 2>/dev/null || echo unset))"
kv "native_bin_state_file" "$BIN_STATE_FILE ($(cat "$BIN_STATE_FILE" 2>/dev/null || echo unset))"

section "BUILD AND TEST RUST"
if ! command_exists cargo; then
    echo "FATAL: cargo is required for the native test suite."
    echo "Install Rust/cargo, then rerun this script."
    exit 2
fi
run_gate "cargo rustfmt" 3     cargo fmt --manifest-path native/Cargo.toml --all -- --check
run_gate "cargo release build" 4     cargo build --locked --manifest-path native/Cargo.toml --release --workspace
run_gate "cargo unit tests" 5     cargo test --locked --manifest-path native/Cargo.toml --workspace --all-targets
run_gate "cargo clippy" 6     cargo clippy --locked --manifest-path native/Cargo.toml --workspace --all-targets -- -D warnings
run_gate "native boundary guard" 6 python3 native/scripts/assert-dormant.py
run_gate "native selector contract" 7 bash scripts/test-native-selector-contract.sh
run_gate "native selector behavior" 7 bash scripts/test-native-selector-behavior.sh
run_gate "Niri parser regression" 8 python3 scripts/test-niri-config-structural-read.py
run_gate "Niri customization fixture parity" 8 python3 native/scripts/check-niri-customizations.py "$BIN_DIR/inir-native"
run_gate "Niri isolated write parity" 8 python3 native/scripts/check-niri-write-parity.py "$BIN_DIR/inir-native"
run_gate "MPD isolated mutation parity" 8 python3 native/scripts/check-mpd-mutation-parity.py "$BIN_DIR/inir-mpdd"
run_gate "Clipboard corpus parity" 8 python3 native/scripts/check-clipboard-parity.py "$BIN_DIR/inir-native"
run_gate "Diagnostics isolated value/lifecycle parity" 20 python3 native/scripts/check-diagnostics-parity.py "$BIN_DIR/inir-native"
run_gate "Theme image/template + consumer parity" 25 python3 native/scripts/check-theme-parity.py "$BIN_DIR/inir-theme"
"$DISPATCH" backend-info
for binary in inir-inputd inir-mpdd inir-native inir-theme; do
    if [[ -x "$BIN_DIR/$binary" ]]; then
        kv "binary $binary" "$(du -h "$BIN_DIR/$binary" | awk '{print $1}') ($(stat -c %s "$BIN_DIR/$binary") bytes)"
    fi
done

section "CLIPBOARD PARITY + BENCHMARK"
CLIP_INPUT='<meta http-equiv="content-type" content="text/html; charset=utf-8"><div>Hello&nbsp;Hadalis</div><div>Rust</div>'
printf '%s' "$CLIP_INPUT" >"$TMP_ROOT/clip.in"
printf '%s' "$CLIP_INPUT" | python3 scripts/clipboard-store.py --filter >"$TMP_ROOT/clip.py"
py_clip_rc=$?
printf '%s' "$CLIP_INPUT" | INIR_NATIVE_BACKEND=rust INIR_NATIVE_STRICT=1 "$DISPATCH" clipboard-store --filter >"$TMP_ROOT/clip.rs"
rs_clip_rc=$?
if (( py_clip_rc == 0 && rs_clip_rc == 0 )) && cmp -s "$TMP_ROOT/clip.py" "$TMP_ROOT/clip.rs"; then
    kv "clipboard parity" "PASS"
else
    kv "clipboard parity" "FAIL (python=$py_clip_rc rust=$rs_clip_rc)"
    diff -u "$TMP_ROOT/clip.py" "$TMP_ROOT/clip.rs" || true
    block_activation "clipboard filter parity failed"
fi
INIR_BENCH_STDIN="$TMP_ROOT/clip.in" bench "clipboard python" python3 scripts/clipboard-store.py --filter
INIR_BENCH_STDIN="$TMP_ROOT/clip.in" bench "clipboard rust" "$BIN_DIR/inir-native" clipboard-filter --filter
INIR_BENCH_STDIN="$TMP_ROOT/clip.in" INIR_NATIVE_BACKEND=rust INIR_NATIVE_BIN_DIR="$BIN_DIR"     bench "clipboard rust dispatch" "$ROOT_DIR/scripts/native-dispatch" clipboard-store --filter

section "NIRI READ-ONLY PARITY + BENCHMARK"
for op in outputs get-hot-corners get-input get-layout get-animations get-window-rules get-binds list-cursor-themes validate detect-customizations; do
    py="$TMP_ROOT/niri-$op.py"
    rs="$TMP_ROOT/niri-$op.rs"
    python3 scripts/niri-config.py "$op" >"$py" 2>"$TMP_ROOT/niri-$op.py.err"
    py_rc=$?
    "$BIN_DIR/inir-native" niri "$op" >"$rs" 2>"$TMP_ROOT/niri-$op.rs.err"
    rs_rc=$?
    if (( py_rc == 0 && rs_rc == 0 )); then
        parity="$(json_compare "$py" "$rs")"
    else
        parity="ERROR(py=$py_rc rust=$rs_rc)"
    fi
    kv "niri $op" "$parity"
    [[ "$parity" == PASS ]] || block_activation "Niri $op parity failed"
    if (( py_rc == 0 && rs_rc == 0 )); then
        bench "niri $op python" python3 scripts/niri-config.py "$op"
        bench "niri $op rust" "$BIN_DIR/inir-native" niri "$op"
        INIR_NATIVE_BACKEND=rust INIR_NATIVE_BIN_DIR="$BIN_DIR"             bench "niri $op rust dispatch" "$ROOT_DIR/scripts/native-dispatch" niri "$op"
    fi
done

section "DESKTOP CONFIG PARITY (ISOLATED TEMP HOME)"
if python3 - "$ROOT_DIR/services/IconThemeService.qml" "$BIN_DIR/inir-native" "$TMP_ROOT/desktop" <<'PY'
import configparser
import os
import shlex
from pathlib import Path
import subprocess
import sys

qml_path, rust_binary, temporary = sys.argv[1:]
source = Path(qml_path).read_text()
root = Path(temporary)
files = {
    "kdeglobals": ("Icons", "Theme"),
    "qt5ct/qt5ct.conf": ("Appearance", "icon_theme"),
    "qt6ct/qt6ct.conf": ("Appearance", "icon_theme"),
    "gtk-3.0/settings.ini": ("Settings", "gtk-icon-theme-name"),
    "gtk-4.0/settings.ini": ("Settings", "gtk-icon-theme-name"),
}
theme = "INIR-Native-Trial"
runner_commands = []
for backend in ("python", "rust"):
    for relative, (section, _) in files.items():
        path = root / backend / ".config" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"[{section}]\nOther=keep\n\n[Unrelated]\nX=1\n")

for process_id in ("kdeGlobalsUpdateProc", "qt5ctProc", "qt6ctProc", "gtkSettingsProc"):
    try:
        start = source.index("id: " + process_id)
        opening = source.index("`", start)
        closing = source.index("`", opening + 1)
    except ValueError:
        print(f"desktop Python source missing: {process_id}")
        sys.exit(1)
    script = source[opening + 1:closing]
    script = script.replace("${" + process_id + ".themeName}", theme)
    script = script.replace("\\\\", "\\")  # QML template literal escaping
    script_path = root / f"{process_id}.py"
    script_path.write_text(script)
    runner_commands.append(f"python3 {shlex.quote(str(script_path))} & pids+=(\"$!\")")
    result = subprocess.run(["python3", "-c", script],
                            env={**os.environ, "HOME": str(root / "python")},
                            capture_output=True, text=True)
    if result.returncode:
        print(f"desktop Python {process_id}: ERROR exit={result.returncode} "
              f"{result.stderr[:200].strip()}")
        sys.exit(1)

(root / "run-python.sh").write_text(
    "#!/usr/bin/env bash\nset -uo pipefail\npids=()\n"
    + "\n".join(runner_commands)
    + "\nrc=0\nfor pid in \"${pids[@]}\"; do wait \"$pid\" || rc=1; done\nexit \"$rc\"\n"
)

result = subprocess.run([rust_binary, "desktop", "sync-icon-theme", theme],
                        env={**os.environ,
                             "XDG_CONFIG_HOME": str(root / "rust" / ".config")},
                        capture_output=True, text=True)
if result.returncode:
    print(f"desktop Rust: ERROR exit={result.returncode} {result.stderr[:200].strip()}")
    sys.exit(1)

failed = False
for relative, (section, key) in files.items():
    configs = []
    for backend in ("python", "rust"):
        config = configparser.ConfigParser(interpolation=None)
        config.optionxform = str
        with (root / backend / ".config" / relative).open() as handle:
            config.read_file(handle)
        configs.append({part: dict(config[part]) for part in config.sections()})
    equal = configs[0] == configs[1]
    valid = configs[1].get(section, {}).get(key) == theme
    print(f"desktop {relative:<24} {'PASS' if equal and valid else 'DIFF'}")
    failed |= not (equal and valid)
sys.exit(1 if failed else 0)
PY
then
    kv "desktop config parity" "PASS"
    HOME="$TMP_ROOT/desktop/python" bench "desktop python combined" bash "$TMP_ROOT/desktop/run-python.sh"
    XDG_CONFIG_HOME="$TMP_ROOT/desktop/rust/.config" bench "desktop rust combined" \
        "$BIN_DIR/inir-native" desktop sync-icon-theme INIR-Native-Trial
else
    block_activation "desktop config parity failed"
fi

section "THEME PARITY + BENCHMARK"
mkdir -p "$TMP_ROOT/theme-py" "$TMP_ROOT/theme-rs"
THEME_ARGS=(--color '#4181EE' --mode dark --scheme scheme-tonal-spot --termscheme "$ROOT_DIR/scripts/colors/terminal/scheme-base.json")
PY_THEME=(python3 scripts/colors/generate_colors_material.py)
if [[ -x "$HOME/.local/state/quickshell/.venv/bin/python3" ]]; then
    PY_THEME=("$HOME/.local/state/quickshell/.venv/bin/python3" scripts/colors/generate_colors_material.py)
elif [[ -n "${INIR_VENV:-}" && -x "${INIR_VENV/#\~/$HOME}/bin/python3" ]]; then
    PY_THEME=("${INIR_VENV/#\~/$HOME}/bin/python3" scripts/colors/generate_colors_material.py)
fi
"${PY_THEME[@]}" "${THEME_ARGS[@]}"     --json-output "$TMP_ROOT/theme-py/colors.json"     --palette-output "$TMP_ROOT/theme-py/palette.json"     --app-palette-output "$TMP_ROOT/theme-py/app.json"     --terminal-output "$TMP_ROOT/theme-py/terminal.json"     --meta-output "$TMP_ROOT/theme-py/meta.json"     --scss-output "$TMP_ROOT/theme-py/colors.scss" >/dev/null
py_theme_rc=$?
"$BIN_DIR/inir-theme" "${THEME_ARGS[@]}"     --json-output "$TMP_ROOT/theme-rs/colors.json"     --palette-output "$TMP_ROOT/theme-rs/palette.json"     --app-palette-output "$TMP_ROOT/theme-rs/app.json"     --terminal-output "$TMP_ROOT/theme-rs/terminal.json"     --meta-output "$TMP_ROOT/theme-rs/meta.json"     --scss-output "$TMP_ROOT/theme-rs/colors.scss" >/dev/null
rs_theme_rc=$?
kv "theme exit" "python=$py_theme_rc rust=$rs_theme_rc"
for file in palette.json app.json terminal.json colors.json; do
    if (( py_theme_rc == 0 && rs_theme_rc == 0 )); then
        parity="$(json_compare "$TMP_ROOT/theme-py/$file" "$TMP_ROOT/theme-rs/$file")"
        kv "theme $file" "$parity"
        [[ "$parity" == PASS ]] || block_activation "theme $file parity failed"
    else
        kv "theme $file" "ERROR (generator failed)"
        block_activation "theme generator failed"
    fi
done
if (( py_theme_rc == 0 && rs_theme_rc == 0 )); then
    parity="$(json_compare "$TMP_ROOT/theme-py/meta.json" "$TMP_ROOT/theme-rs/meta.json" --theme-meta)"
    kv "theme meta.json (identity excluded)" "$parity"
    [[ "$parity" == PASS ]] || block_activation "theme metadata parity failed"
    scss_parity="$(python3 - "$TMP_ROOT/theme-py/colors.scss" "$TMP_ROOT/theme-rs/colors.scss" <<'PY'
from pathlib import Path
import sys

def declarations(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        key, value = line.split(":", 1)
        result[key.strip()] = value.strip()
    return result

try:
    left, right = map(declarations, sys.argv[1:])
except (OSError, ValueError) as error:
    print(f"ERROR {error}")
    sys.exit(1)
if left == right:
    print(f"PASS ({len(left)} declarations)")
else:
    changed = sorted(key for key in left.keys() | right.keys()
                     if left.get(key) != right.get(key))
    print(f"DIFF count={len(changed)} first={','.join(changed[:6])}")
    sys.exit(1)
PY
)"
    kv "theme SCSS values" "$scss_parity"
    [[ "$scss_parity" == PASS* ]] || block_activation "theme SCSS parity failed"
fi
bench "theme python color-only" "${PY_THEME[@]}" "${THEME_ARGS[@]}" --json-output "$TMP_ROOT/bench-py.json"
bench "theme rust color-only" "$BIN_DIR/inir-theme" "${THEME_ARGS[@]}" --json-output "$TMP_ROOT/bench-rs.json"
INIR_NATIVE_BACKEND=rust INIR_NATIVE_BIN_DIR="$BIN_DIR"     bench "theme rust dispatch" "$ROOT_DIR/scripts/native-dispatch" theme     "${THEME_ARGS[@]}" --json-output "$TMP_ROOT/bench-rs-dispatch.json"
mkdir -p "$TMP_ROOT/theme-bench-py" "$TMP_ROOT/theme-bench-rs"
for backend in py rs; do
    if [[ "$backend" == py ]]; then
        label="theme python full"
        command=("${PY_THEME[@]}")
    else
        label="theme rust full"
        command=("$BIN_DIR/inir-theme")
    fi
    output_dir="$TMP_ROOT/theme-bench-$backend"
    bench "$label" "${command[@]}" "${THEME_ARGS[@]}" \
        --json-output "$output_dir/colors.json" \
        --palette-output "$output_dir/palette.json" \
        --app-palette-output "$output_dir/app.json" \
        --terminal-output "$output_dir/terminal.json" \
        --meta-output "$output_dir/meta.json" \
        --scss-output "$output_dir/colors.scss"
done

section "INPUT PROBE + RESIDENT COST"
python3 scripts/daemon/keyboard_lock_state_daemon.py --once >"$TMP_ROOT/input.py" 2>"$TMP_ROOT/input.py.err"
py_input_rc=$?
"$BIN_DIR/inir-inputd" --mode locks --once >"$TMP_ROOT/input.rs" 2>"$TMP_ROOT/input.rs.err"
rs_input_rc=$?
kv "input probe exit" "python=$py_input_rc rust=$rs_input_rc"
kv "input python" "$(tr '\n' ' ' < "$TMP_ROOT/input.py" | head -c 240)"
kv "input rust" "$(tr '\n' ' ' < "$TMP_ROOT/input.rs" | head -c 240)"
if (( py_input_rc == 0 && rs_input_rc == 0 )); then
    input_parity="$(json_compare "$TMP_ROOT/input.py" "$TMP_ROOT/input.rs" type caps num devices)"
else
    input_parity="ERROR (probe failed)"
fi
kv "input state parity" "$input_parity"
[[ "$input_parity" == PASS ]] || block_activation "input state parity failed"
bench "input probe python" python3 scripts/daemon/keyboard_lock_state_daemon.py --once
bench "input probe rust" "$BIN_DIR/inir-inputd" --mode locks --once
INIR_NATIVE_BACKEND=rust INIR_NATIVE_BIN_DIR="$BIN_DIR"     bench "input probe rust dispatch" "$ROOT_DIR/scripts/native-dispatch" input-lock --once
proc_metrics "input python resident" python3 -u scripts/daemon/keyboard_lock_state_daemon.py || block_activation "Python input daemon exited early"
proc_metrics "input rust resident" "$BIN_DIR/inir-inputd" --mode locks || block_activation "Rust input daemon exited early"
proc_metrics "osk keys python resident" python3 -u scripts/daemon/osk_physical_key_daemon.py || block_activation "Python OSK key listener exited early"
proc_metrics "osk keys rust resident" "$BIN_DIR/inir-inputd" --mode keys || block_activation "Rust OSK key listener exited early"

section "DIAGNOSTICS SCHEMA + RESIDENT COST"
target_pid="$(systemctl --user show -p MainPID --value inir.service 2>/dev/null || true)"
[[ "$target_pid" =~ ^[1-9][0-9]*$ ]] || target_pid="$$"
timeout 2s python3 scripts/runtime-diagnostics-sampler.py --pid "$target_pid" --interval-ms 1000 >"$TMP_ROOT/diag.py" 2>"$TMP_ROOT/diag.py.err" || true
timeout 2s "$BIN_DIR/inir-native" diagnostics --pid "$target_pid" --interval-ms 1000 >"$TMP_ROOT/diag.rs" 2>"$TMP_ROOT/diag.rs.err" || true
head -n 1 "$TMP_ROOT/diag.py" >"$TMP_ROOT/diag.py.one" || true
head -n 1 "$TMP_ROOT/diag.rs" >"$TMP_ROOT/diag.rs.one" || true
if command_exists jq && jq -e . "$TMP_ROOT/diag.py.one" >/dev/null 2>&1 && jq -e . "$TMP_ROOT/diag.rs.one" >/dev/null 2>&1; then
    # Child processes may enter or leave between the two samples. Compare the
    # schema of child entries without treating their transient indices as fields.
    jq -S '[paths | map(if type == "number" then "[]" else tostring end) | join(".")] | unique' "$TMP_ROOT/diag.py.one" >"$TMP_ROOT/diag.py.paths"
    jq -S '[paths | map(if type == "number" then "[]" else tostring end) | join(".")] | unique' "$TMP_ROOT/diag.rs.one" >"$TMP_ROOT/diag.rs.paths"
    if cmp -s "$TMP_ROOT/diag.py.paths" "$TMP_ROOT/diag.rs.paths"; then
        kv "diagnostics schema parity" "PASS"
    else
        kv "diagnostics schema parity" "DIFF (dynamic/optional fields may differ; report retains path sets)"
        diff -U0 "$TMP_ROOT/diag.py.paths" "$TMP_ROOT/diag.rs.paths" | head -n 80 || true
        block_activation "diagnostics schema parity failed"
    fi
else
    kv "diagnostics schema parity" "ERROR (missing/invalid first sample)"
    block_activation "diagnostics sample unavailable"
fi
proc_metrics "diagnostics python" python3 scripts/runtime-diagnostics-sampler.py --pid "$target_pid" --interval-ms 1000 || block_activation "Python diagnostics sampler exited early"
proc_metrics "diagnostics rust" "$BIN_DIR/inir-native" diagnostics --pid "$target_pid" --interval-ms 1000 || block_activation "Rust diagnostics sampler exited early"

section "MPD READ-ONLY PARITY + BENCHMARK"
MPD_HOST_TEST="${MPD_HOST:-127.0.0.1}"
MPD_PORT_TEST="${MPD_PORT:-6600}"
MUSIC_ROOT_TEST="${INIR_MUSIC_ROOT:-}"
python3 scripts/local_music_mpd.py status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST" >"$TMP_ROOT/mpd.py" 2>"$TMP_ROOT/mpd.py.err"
py_mpd_rc=$?
"$BIN_DIR/inir-mpdd" --compat status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST" >"$TMP_ROOT/mpd.rs" 2>"$TMP_ROOT/mpd.rs.err"
rs_mpd_rc=$?
kv "mpd status exit" "python=$py_mpd_rc rust=$rs_mpd_rc"
if (( py_mpd_rc == 0 && rs_mpd_rc == 0 )); then
    if python3 - "$TMP_ROOT/mpd.py" <<'PY'
import json
import sys
with open(sys.argv[1]) as handle:
    sys.exit(0 if json.load(handle).get("connected") else 1)
PY
    then
        mpd_parity="$(json_compare "$TMP_ROOT/mpd.py" "$TMP_ROOT/mpd.rs" --mpd-status)"
        kv "mpd status parity" "$mpd_parity"
        [[ "$mpd_parity" == PASS ]] || block_activation "MPD status parity failed"
        bench "mpd status python" python3 scripts/local_music_mpd.py status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
        bench "mpd status rust" "$BIN_DIR/inir-mpdd" --compat status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"

        if [[ "${INIR_BENCH_MPD_SNAPSHOT:-0}" == 1 ]]; then
            section "MPD FULL SNAPSHOT DEEP BENCHMARK"
            snapshot_parity_cache="$TMP_ROOT/mpd-snapshot-parity-cache"
            snapshot_python_cache="$TMP_ROOT/mpd-snapshot-python-cache"
            snapshot_rust_cache="$TMP_ROOT/mpd-snapshot-rust-cache"
            mkdir -p "$snapshot_parity_cache" "$snapshot_python_cache" "$snapshot_rust_cache"

            env XDG_CACHE_HOME="$snapshot_parity_cache" \
                python3 scripts/local_music_mpd.py snapshot \
                "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST" \
                >"$TMP_ROOT/mpd.snapshot.py" 2>"$TMP_ROOT/mpd.snapshot.py.err"
            py_snapshot_rc=$?
            env XDG_CACHE_HOME="$snapshot_parity_cache" \
                "$BIN_DIR/inir-mpdd" --compat snapshot \
                "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST" \
                >"$TMP_ROOT/mpd.snapshot.rs" 2>"$TMP_ROOT/mpd.snapshot.rs.err"
            rs_snapshot_rc=$?
            kv "mpd snapshot exit" "python=$py_snapshot_rc rust=$rs_snapshot_rc"

            if (( py_snapshot_rc == 0 && rs_snapshot_rc == 0 )); then
                snapshot_parity="$(json_compare \
                    "$TMP_ROOT/mpd.snapshot.py" "$TMP_ROOT/mpd.snapshot.rs" \
                    --mpd-snapshot)"
                kv "mpd snapshot stable parity" "$snapshot_parity"
                [[ "$snapshot_parity" == PASS ]] \
                    || block_activation "MPD full snapshot parity failed"

                snapshot_runs="${MPD_SNAPSHOT_RUNS:-1}"
                if [[ ! "$snapshot_runs" =~ ^[1-9][0-9]*$ ]]; then
                    snapshot_runs=1
                fi
                rm -rf -- "$snapshot_python_cache" "$snapshot_rust_cache"
                mkdir -p "$snapshot_python_cache" "$snapshot_rust_cache"
                BENCH_RUNS="$snapshot_runs" bench "mpd snapshot python" \
                    env XDG_CACHE_HOME="$snapshot_python_cache" \
                    python3 scripts/local_music_mpd.py snapshot \
                    "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
                BENCH_RUNS="$snapshot_runs" bench "mpd snapshot rust" \
                    env XDG_CACHE_HOME="$snapshot_rust_cache" \
                    "$BIN_DIR/inir-mpdd" --compat snapshot \
                    "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
            else
                kv "mpd snapshot stable parity" "ERROR (snapshot failed)"
                kv "mpd snapshot python error" \
                    "$(tr '\n' ' ' < "$TMP_ROOT/mpd.snapshot.py.err" | head -c 300)"
                kv "mpd snapshot rust error" \
                    "$(tr '\n' ' ' < "$TMP_ROOT/mpd.snapshot.rs.err" | head -c 300)"
                block_activation "MPD full snapshot smoke failed"
            fi
        else
            kv "mpd full snapshot benchmark" "SKIP (use benchmark wrapper --deep)"
        fi

        mpd_socket="$TMP_ROOT/mpd-daemon.sock"
        mpd_daemon_command=(
            "$BIN_DIR/inir-mpdd"
            --host "$MPD_HOST_TEST"
            --port "$MPD_PORT_TEST"
            --socket "$mpd_socket"
        )
        if [[ -n "$MUSIC_ROOT_TEST" ]]; then
            mpd_daemon_command+=(--music-root "$MUSIC_ROOT_TEST")
        fi
        "${mpd_daemon_command[@]}" >"$TMP_ROOT/mpd-daemon.out" 2>"$TMP_ROOT/mpd-daemon.err" &
        MPD_DAEMON_PID=$!

        for _ in {1..50}; do
            [[ -S "$mpd_socket" ]] && break
            kill -0 "$MPD_DAEMON_PID" 2>/dev/null || break
            sleep 0.05
        done

        if [[ -S "$mpd_socket" ]]; then
            "$BIN_DIR/inir-mpdd" --client-compat --socket "$mpd_socket"                 status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"                 >"$TMP_ROOT/mpd.daemon.rs" 2>"$TMP_ROOT/mpd.daemon.rs.err"
            daemon_mpd_rc=$?
            if (( daemon_mpd_rc == 0 )); then
                daemon_mpd_parity="$(json_compare "$TMP_ROOT/mpd.rs" "$TMP_ROOT/mpd.daemon.rs" --mpd-status)"
                kv "mpd daemon parity" "$daemon_mpd_parity"
                [[ "$daemon_mpd_parity" == PASS ]] || block_activation "MPD daemon parity failed"
                bench "mpd status rust daemon" "$BIN_DIR/inir-mpdd"                     --client-compat --socket "$mpd_socket"                     status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
                INIR_NATIVE_BACKEND=rust INIR_NATIVE_BIN_DIR="$BIN_DIR" INIR_MPD_SOCKET="$mpd_socket"                     bench "mpd status rust dispatch" "$ROOT_DIR/scripts/native-dispatch"                     mpd status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
            else
                kv "mpd daemon parity" "ERROR exit=$daemon_mpd_rc"
                block_activation "MPD daemon client smoke failed"
            fi
        else
            kv "mpd daemon benchmark" "ERROR (socket did not become ready)"
            block_activation "MPD persistent daemon failed to start"
            tail -n 40 "$TMP_ROOT/mpd-daemon.err" || true
        fi

        kill "$MPD_DAEMON_PID" 2>/dev/null || true
        wait "$MPD_DAEMON_PID" 2>/dev/null || true
        MPD_DAEMON_PID=""
    else
        kv "mpd status parity" "SKIP (MPD service unavailable)"
    fi
else
    kv "mpd status parity" "SKIP/ERROR"
    kv "mpd python error" "$(tr '\n' ' ' < "$TMP_ROOT/mpd.py.err" | head -c 300)"
    kv "mpd rust error" "$(tr '\n' ' ' < "$TMP_ROOT/mpd.rs.err" | head -c 300)"
    block_activation "MPD status smoke failed"
fi

section "OPTIONAL PERF COUNTERS"
if command_exists perf; then
    perf stat -e task-clock,context-switches,cpu-migrations,page-faults         "$BIN_DIR/inir-native" niri get-hot-corners >/dev/null 2>"$TMP_ROOT/perf-rust.txt" || true
    perf stat -e task-clock,context-switches,cpu-migrations,page-faults         python3 scripts/niri-config.py get-hot-corners >/dev/null 2>"$TMP_ROOT/perf-python.txt" || true
    echo "--- Rust perf ---"
    cat "$TMP_ROOT/perf-rust.txt"
    echo "--- Python perf ---"
    cat "$TMP_ROOT/perf-python.txt"
else
    echo "perf unavailable"
fi

if [[ "${1:-}" != "--no-activate" ]]; then
    activate_rust
fi

section "SYSTEMD STATUS + RECENT LOGS"
systemctl --user show inir.service \
    -p ActiveState -p SubState -p MainPID -p MemoryCurrent -p CPUUsageNSec \
    -p FragmentPath 2>&1 || true
journalctl --user -u inir.service --since '-10 minutes' -n 60 --no-pager 2>&1 \
    | awk '!seen[$0]++' | tail -n 25 || true

section "SUMMARY"
kv "report_file" "$REPORT"
kv "native_bin_dir" "$BIN_DIR"
kv "runtime_mode" "$RUNTIME_MODE"
kv "activation_blockers" "${#ACTIVATION_BLOCKERS[@]}"
if ((${#ACTIVATION_BLOCKERS[@]})); then
    kv "result" "HOLD (see activation blockers above)"
else
    kv "result" "PASS"
fi
if [[ "$RUNTIME_MODE" == "rust test mode active" ]]; then
    echo "Rollback command:"
    echo "  bash $ROOT_DIR/scripts/benchmark-python-vs-rust.sh --restore"
fi
echo
echo "=== SEND THIS REPORT BACK TO CHATGPT ==="
cat <<EOF
Report path: $REPORT
Git HEAD: $(git rev-parse HEAD 2>/dev/null || echo unknown)
Rust test mode: $([[ "$RUNTIME_MODE" == "rust test mode active" ]] && echo active || echo no)
EOF
echo "=== END ==="
if ((${#ACTIVATION_BLOCKERS[@]})); then
    exit 6
fi
