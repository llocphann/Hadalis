#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
mkdir -p "$STATE_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${INIR_NATIVE_REPORT:-$STATE_DIR/native-cutover-$STAMP.txt}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/inir-native-test.XXXXXX")"
BIN_DIR="$ROOT_DIR/native/target/release"
DISPATCH="$ROOT_DIR/scripts/native-dispatch"
ORIGINAL_BACKEND="${INIR_NATIVE_BACKEND:-}"
ORIGINAL_BIN_DIR="${INIR_NATIVE_BIN_DIR:-}"
ACTIVE_RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir"
ACTIVE_RUNTIME="$(readlink -f "$ACTIVE_RUNTIME" 2>/dev/null || printf '%s' "$ACTIVE_RUNTIME")"

cleanup() {
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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_gate() {
    local label="$1"
    local failure_code="$2"
    shift 2
    local log="$TMP_ROOT/gate-${label//[^A-Za-z0-9_.-]/_}.log"
    if "$@" >"$log" 2>&1; then
        kv "$label" "PASS"
        return 0
    fi
    local rc=$?
    kv "$label" "FAIL exit=$rc"
    echo "--- $label log tail ---"
    tail -n 120 "$log" || true
    exit "$failure_code"
}

run_capture() {
    local output rc
    output="$("$@" 2>&1)"
    rc=$?
    printf '%s' "$output"
    return "$rc"
}

bench() {
    local label="$1"
    shift
    local runs="${BENCH_RUNS:-5}"
    local total_wall=0 total_user=0 total_sys=0 max_rss=0 success=0
    local i stats rc
    if [[ ! -x /usr/bin/time ]]; then
        kv "$label" "SKIP (/usr/bin/time missing)"
        return 0
    fi
    for ((i=1; i<=runs; i++)); do
        stats="$TMP_ROOT/time.$$.txt"
        /usr/bin/time -f '%e %U %S %M' -o "$stats" -- "$@" >/dev/null 2>&1
        rc=$?
        if (( rc != 0 )); then
            kv "$label" "ERROR exit=$rc cmd=$*"
            return 0
        fi
        read -r wall user sys rss < "$stats"
        total_wall="$(awk -v a="$total_wall" -v b="$wall" 'BEGIN{printf "%.6f",a+b}')"
        total_user="$(awk -v a="$total_user" -v b="$user" 'BEGIN{printf "%.6f",a+b}')"
        total_sys="$(awk -v a="$total_sys" -v b="$sys" 'BEGIN{printf "%.6f",a+b}')"
        (( rss > max_rss )) && max_rss="$rss"
        success=$((success+1))
    done
    awk -v label="$label" -v n="$success" -v w="$total_wall" -v u="$total_user" -v s="$total_sys" -v r="$max_rss"         'BEGIN{printf "%-32s avg_wall=%.3fms avg_user=%.3fms avg_sys=%.3fms max_rss=%dKiB runs=%d\n",label,(w/n)*1000,(u/n)*1000,(s/n)*1000,r,n}'
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
        return 0
    fi
    local pss0 rss0 ticks0 pss1 rss1 ticks1 hz
    pss0="$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)"
    rss0="$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo 0)"
    ticks0="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo 0)"
    sleep "$seconds"
    pss1="$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo "$pss0")"
    rss1="$(awk '/^VmRSS:/{print $2; exit}' "/proc/$pid/status" 2>/dev/null || echo "$rss0")"
    ticks1="$(awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null || echo "$ticks0")"
    hz="$(getconf CLK_TCK 2>/dev/null || echo 100)"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    awk -v label="$label" -v p0="$pss0" -v p1="$pss1" -v r0="$rss0" -v r1="$rss1"         -v t0="$ticks0" -v t1="$ticks1" -v hz="$hz" -v sec="$seconds"         'BEGIN{cpu=((t1-t0)/hz)/sec*100; printf "%-32s pss=%d->%dKiB rss=%d->%dKiB cpu_window=%.3f%%\n",label,p0,p1,r0,r1,cpu}'
}

json_diff_count() {
    local left="$1" right="$2"
    if command_exists jq; then
        jq -S . "$left" >"$TMP_ROOT/left.norm" 2>/dev/null || return 1
        jq -S . "$right" >"$TMP_ROOT/right.norm" 2>/dev/null || return 1
        diff -U0 "$TMP_ROOT/left.norm" "$TMP_ROOT/right.norm" 2>/dev/null | grep -Ec '^[+-][[:space:]]*"' || true
    else
        echo "jq-missing"
    fi
}

set_runtime_backend() {
    local mode="$1"
    systemctl --user set-environment         INIR_NATIVE_BACKEND="$mode"         INIR_NATIVE_BIN_DIR="$BIN_DIR"         INIR_NATIVE_STRICT=0
    "$ROOT_DIR/scripts/inir" restart || systemctl --user restart inir.service || true
}

measure_service_mode() {
    local mode="$1"
    local window="${LIVE_WINDOW_SECONDS:-5}"
    set_runtime_backend "$mode"
    sleep 4

    local pid mem tasks cpu0 cpu1 delta
    pid="$(systemctl --user show -p MainPID --value inir.service 2>/dev/null || echo 0)"
    mem="$(systemctl --user show -p MemoryCurrent --value inir.service 2>/dev/null || echo unknown)"
    tasks="$(systemctl --user show -p TasksCurrent --value inir.service 2>/dev/null || echo unknown)"
    cpu0="$(systemctl --user show -p CPUUsageNSec --value inir.service 2>/dev/null || echo 0)"
    sleep "$window"
    cpu1="$(systemctl --user show -p CPUUsageNSec --value inir.service 2>/dev/null || echo 0)"
    if [[ "$cpu0" =~ ^[0-9]+$ && "$cpu1" =~ ^[0-9]+$ ]]; then
        delta=$((cpu1-cpu0))
    else
        delta=0
    fi

    awk -v mode="$mode" -v pid="$pid" -v mem="$mem" -v tasks="$tasks"         -v delta="$delta" -v window="$window"         'BEGIN{
            mib=(mem ~ /^[0-9]+$/) ? mem/1048576 : -1;
            cpu=(window>0) ? delta/(window*1000000000)*100 : 0;
            if (mib >= 0)
                printf "live %-7s pid=%s cgroup_mem=%.2fMiB tasks=%s cpu_window=%.3f%%\n",mode,pid,mib,tasks,cpu;
            else
                printf "live %-7s pid=%s cgroup_mem=%s tasks=%s cpu_window=%.3f%%\n",mode,pid,mem,tasks,cpu;
        }'

    printf 'processes(%s):\n' "$mode"
    ps -eo pid,ppid,rss,etimes,comm,args         | grep -E 'quickshell|inir-inputd|inir-mpdd|inir-native|inir-theme|keyboard_lock_state_daemon|osk_physical_key_daemon|runtime-diagnostics-sampler'         | grep -v grep || true
}

activate_rust() {
    section "LIVE SHELL A/B"
    if [[ ! -x "$ACTIVE_RUNTIME/scripts/native-dispatch" ]]; then
        kv "live A/B" "SKIP (active runtime lacks scripts/native-dispatch)"
        kv "active_runtime" "$ACTIVE_RUNTIME"
        echo "Direct Python/Rust parity and microbenchmarks above are still valid."
        echo "Refresh the active Hadalis runtime from this checkout, then rerun for live A/B."
        return 0
    fi
    echo "Measuring the same inir.service once with Python selected, then with Rust selected."
    measure_service_mode python
    measure_service_mode rust

    section "RUST TEST MODE STATUS"
    systemctl --user --no-pager --full status inir.service 2>&1 | sed -n '1,35p' || true
    printf '\nRecent selector/fallback messages:\n'
    journalctl --user -u inir.service --since '-3 minutes' --no-pager 2>&1         | grep -E 'native-dispatch|inir-inputd|inir-native|inir-mpdd|inir-theme|falling back|Failed|failed|error'         | tail -n 120 || true
}

restore_python() {
    section "RESTORE PYTHON MODE"
    systemctl --user set-environment INIR_NATIVE_BACKEND=python
    systemctl --user unset-environment INIR_NATIVE_BIN_DIR INIR_NATIVE_STRICT || true
    "$ROOT_DIR/scripts/inir" restart || systemctl --user restart inir.service || true
    kv "backend" "python"
}

if [[ "${1:-}" == "--restore" ]]; then
    restore_python
    printf '\nReport: %s\n' "$REPORT"
    exit 0
fi

section "SYSTEM"
kv "date" "$(date --iso-8601=seconds)"
kv "host" "$(hostname)"
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
kv "mpd" "$(mpd --version 2>/dev/null | head -1 || echo unavailable)"
kv "backend_before" "${INIR_NATIVE_BACKEND:-python(default)}"

section "BUILD AND TEST RUST"
if ! command_exists cargo; then
    echo "FATAL: cargo is required for the native test suite."
    echo "Install Rust/cargo, then rerun this script."
    exit 2
fi
run_gate "cargo release build" 3     cargo build --manifest-path native/Cargo.toml --release --workspace
run_gate "cargo unit tests" 4     cargo test --manifest-path native/Cargo.toml --workspace --all-targets
run_gate "cargo clippy" 5     cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets -- -D warnings
"$DISPATCH" backend-info
for binary in inir-inputd inir-mpdd inir-native inir-theme; do
    if [[ -x "$BIN_DIR/$binary" ]]; then
        kv "binary $binary" "$(du -h "$BIN_DIR/$binary" | awk '{print $1}') ($(stat -c %s "$BIN_DIR/$binary") bytes)"
    fi
done

section "CLIPBOARD PARITY + BENCHMARK"
CLIP_INPUT='<meta http-equiv="content-type" content="text/html; charset=utf-8"><div>Hello&nbsp;Hadalis</div><div>Rust</div>'
printf '%s' "$CLIP_INPUT" | python3 scripts/clipboard-store.py --filter >"$TMP_ROOT/clip.py"
printf '%s' "$CLIP_INPUT" | INIR_NATIVE_BACKEND=rust INIR_NATIVE_STRICT=1 "$DISPATCH" clipboard-store --filter >"$TMP_ROOT/clip.rs"
if cmp -s "$TMP_ROOT/clip.py" "$TMP_ROOT/clip.rs"; then
    kv "clipboard parity" "PASS"
else
    kv "clipboard parity" "FAIL"
    diff -u "$TMP_ROOT/clip.py" "$TMP_ROOT/clip.rs" || true
fi
bench "clipboard python" bash -c "printf '%s' '$CLIP_INPUT' | python3 '$ROOT_DIR/scripts/clipboard-store.py' --filter"
bench "clipboard rust" bash -c "printf '%s' '$CLIP_INPUT' | '$BIN_DIR/inir-native' clipboard-filter --filter"

section "NIRI READ-ONLY PARITY + BENCHMARK"
for op in get-hot-corners get-input get-layout get-animations get-window-rules list-cursor-themes validate; do
    py="$TMP_ROOT/niri-$op.py"
    rs="$TMP_ROOT/niri-$op.rs"
    python3 scripts/niri-config.py "$op" >"$py" 2>"$TMP_ROOT/niri-$op.py.err"
    py_rc=$?
    "$BIN_DIR/inir-native" niri "$op" >"$rs" 2>"$TMP_ROOT/niri-$op.rs.err"
    rs_rc=$?
    if (( py_rc == 0 && rs_rc == 0 )); then
        if command_exists jq && jq -e . "$py" >/dev/null 2>&1 && jq -e . "$rs" >/dev/null 2>&1; then
            py_norm="$(jq -S -c . "$py")"
            rs_norm="$(jq -S -c . "$rs")"
            [[ "$py_norm" == "$rs_norm" ]] && parity=PASS || parity="DIFF"
        else
            cmp -s "$py" "$rs" && parity=PASS || parity=DIFF
        fi
    else
        parity="ERROR(py=$py_rc rust=$rs_rc)"
    fi
    kv "niri $op" "$parity"
done
bench "niri hot-corners python" python3 scripts/niri-config.py get-hot-corners
bench "niri hot-corners rust" "$BIN_DIR/inir-native" niri get-hot-corners

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
    if [[ -s "$TMP_ROOT/theme-py/$file" && -s "$TMP_ROOT/theme-rs/$file" ]]; then
        count="$(json_diff_count "$TMP_ROOT/theme-py/$file" "$TMP_ROOT/theme-rs/$file")"
        kv "theme $file differing keys" "$count"
    else
        kv "theme $file" "missing output"
    fi
done
bench "theme python color-only" "${PY_THEME[@]}" "${THEME_ARGS[@]}" --json-output "$TMP_ROOT/bench-py.json"
bench "theme rust color-only" "$BIN_DIR/inir-theme" "${THEME_ARGS[@]}" --json-output "$TMP_ROOT/bench-rs.json"

section "INPUT PROBE + RESIDENT COST"
python3 scripts/daemon/keyboard_lock_state_daemon.py --once >"$TMP_ROOT/input.py" 2>"$TMP_ROOT/input.py.err"
py_input_rc=$?
"$BIN_DIR/inir-inputd" --mode locks --once >"$TMP_ROOT/input.rs" 2>"$TMP_ROOT/input.rs.err"
rs_input_rc=$?
kv "input probe exit" "python=$py_input_rc rust=$rs_input_rc"
kv "input python" "$(tr '\n' ' ' < "$TMP_ROOT/input.py" | head -c 240)"
kv "input rust" "$(tr '\n' ' ' < "$TMP_ROOT/input.rs" | head -c 240)"
proc_metrics "input python resident" python3 -u scripts/daemon/keyboard_lock_state_daemon.py
proc_metrics "input rust resident" "$BIN_DIR/inir-inputd" --mode locks

section "DIAGNOSTICS RESIDENT COST"
target_pid="$(systemctl --user show -p MainPID --value inir.service 2>/dev/null || true)"
[[ "$target_pid" =~ ^[1-9][0-9]*$ ]] || target_pid="$$"
proc_metrics "diagnostics python" python3 scripts/runtime-diagnostics-sampler.py --pid "$target_pid" --interval-ms 1000
proc_metrics "diagnostics rust" "$BIN_DIR/inir-native" diagnostics --pid "$target_pid" --interval-ms 1000

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
    if command_exists jq; then
        py_state="$(jq -c '{connected,status,current,queue,musicRoot}' "$TMP_ROOT/mpd.py" 2>/dev/null || true)"
        rs_state="$(jq -c '{connected,status,current,queue,musicRoot}' "$TMP_ROOT/mpd.rs" 2>/dev/null || true)"
        [[ "$py_state" == "$rs_state" ]] && kv "mpd status parity" PASS || kv "mpd status parity" DIFF
    fi
    bench "mpd status python" python3 scripts/local_music_mpd.py status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
    bench "mpd status rust" "$BIN_DIR/inir-mpdd" --compat status "$MPD_HOST_TEST" "$MPD_PORT_TEST" "$MUSIC_ROOT_TEST"
else
    kv "mpd status parity" "SKIP/ERROR"
    kv "mpd python error" "$(tr '\n' ' ' < "$TMP_ROOT/mpd.py.err" | head -c 300)"
    kv "mpd rust error" "$(tr '\n' ' ' < "$TMP_ROOT/mpd.rs.err" | head -c 300)"
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

section "SUMMARY"
kv "report_file" "$REPORT"
kv "native_bin_dir" "$BIN_DIR"
if [[ "${1:-}" == "--no-activate" ]]; then
    kv "runtime_mode" "unchanged"
else
    kv "runtime_mode" "rust test mode left active"
    echo "Rollback command:"
    echo "  $ROOT_DIR/scripts/test-native-cutover.sh --restore"
fi
echo
echo "=== SEND THIS REPORT BACK TO CHATGPT ==="
cat <<EOF
Report path: $REPORT
Git HEAD: $(git rev-parse HEAD 2>/dev/null || echo unknown)
Rust test mode: $([[ "${1:-}" == "--no-activate" ]] && echo no || echo active)
EOF
echo "=== END ==="
