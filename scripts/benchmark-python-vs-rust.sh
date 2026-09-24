#!/usr/bin/env bash
# One-command, reversible Python/Rust benchmark and validation report.
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/inir"
BACKEND_STATE_FILE="$STATE_DIR/native-backend"
HARNESS="$ROOT_DIR/scripts/native-cutover-benchmark.sh"
READ_ONLY=0
RESTORE_ARMED=0
RESTORE_RC=0

case "${1:-}" in
    "") ;;
    --read-only|--no-activate) READ_ONLY=1 ;;
    --help|-h)
        echo "Usage: bash scripts/benchmark-python-vs-rust.sh [--read-only]"
        echo "Builds and benchmarks both backends, validates the repo, and writes one report."
        echo "A live A/B runs only after the harness safety checks and is restored to Python."
        exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
esac
if (($# > 1)); then
    echo "Usage: bash scripts/benchmark-python-vs-rust.sh [--read-only]" >&2
    exit 64
fi
mkdir -p "$STATE_DIR" || exit 1
REPORT="$(mktemp "$STATE_DIR/native-full-benchmark-$(date +%Y%m%d-%H%M%S)-XXXXXX.txt")" || exit 1
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/inir-full-benchmark.XXXXXX")" || exit 1

backend_state() {
    if [[ -r "$BACKEND_STATE_FILE" ]]; then
        head -n 1 "$BACKEND_STATE_FILE"
    else
        printf 'python\n'
    fi
}

restore_if_needed() {
    local selected_env
    selected_env="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^INIR_NATIVE_BACKEND=//p' | head -n 1)"
    if [[ "$(backend_state)" == rust || "$selected_env" == rust || "$selected_env" == auto ]]; then
        echo "Returning the live service to Python..."
        INIR_NATIVE_REPORT="$TMP_ROOT/restore-internal.txt" \
            bash "$HARNESS" --restore >"$TMP_ROOT/restore-output.txt" 2>&1
        RESTORE_RC=$?
        cat "$TMP_ROOT/restore-output.txt"
    fi
}

cleanup() {
    if ((RESTORE_ARMED)); then
        restore_if_needed
        if [[ -f "$TMP_ROOT/restore-output.txt" ]]; then
            {
                printf '\n===== EMERGENCY RESTORE =====\n'
                cat "$TMP_ROOT/restore-output.txt"
            } >> "$REPORT"
        fi
    fi
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "Checking the current dev HEAD..."
git fetch origin dev >"$TMP_ROOT/fetch.log" 2>&1
FETCH_RC=$?
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
REMOTE_SHA="$(git rev-parse origin/dev 2>/dev/null || echo unknown)"
BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
RUN_MODE="live-if-safe"
if ((READ_ONLY)); then
    RUN_MODE="read-only requested"
elif ((FETCH_RC != 0)) || [[ "$BRANCH" != dev || "$HEAD_SHA" != "$REMOTE_SHA" ]]; then
    RUN_MODE="read-only: dev HEAD could not be verified"
elif ! git diff --quiet || ! git diff --cached --quiet; then
    RUN_MODE="read-only: tracked checkout changes present"
elif [[ "$(backend_state)" != python ]]; then
    RUN_MODE="read-only: existing backend trial is active"
else
    ENV_MODE="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^INIR_NATIVE_BACKEND=//p' | head -n 1)"
    if [[ "$ENV_MODE" == rust || "$ENV_MODE" == auto ]]; then
        RUN_MODE="read-only: existing backend trial is active"
    fi
fi

echo "Benchmark mode: $RUN_MODE"
echo "Building native release and measuring Python/Rust paths..."
if [[ "$RUN_MODE" == live-if-safe ]]; then
    RESTORE_ARMED=1
    INIR_NATIVE_REPORT="$TMP_ROOT/native-internal.txt" bash "$HARNESS" \
        2>&1 | tee "$TMP_ROOT/native-output.txt"
else
    INIR_NATIVE_REPORT="$TMP_ROOT/native-internal.txt" bash "$HARNESS" --no-activate \
        2>&1 | tee "$TMP_ROOT/native-output.txt"
fi
NATIVE_RC=${PIPESTATUS[0]}

if ((RESTORE_ARMED)); then
    restore_if_needed
    if ((RESTORE_RC == 0)); then RESTORE_ARMED=0; fi
fi

echo "Running the canonical repository validator..."
bash scripts/validate-maintainer-local.sh --current-repo >"$TMP_ROOT/validator.log" 2>&1
VALIDATOR_RC=$?
VALIDATOR_SUMMARY="$(tail -n 7 "$TMP_ROOT/validator.log")"
VALIDATOR_FULL_LOG="$(sed -n 's/^FINAL LOG: //p' "$TMP_ROOT/validator.log" | tail -n 1)"
printf '%s\n' "$VALIDATOR_SUMMARY"

{
    printf 'Hadalis Python/Rust full benchmark\n'
    printf 'Date: %s\n' "$(date --iso-8601=seconds)"
    printf 'Repo: %s\n' "$ROOT_DIR"
    printf 'HEAD: %s\n' "$HEAD_SHA"
    printf 'origin/dev: %s\n' "$REMOTE_SHA"
    printf 'Branch: %s\n' "$BRANCH"
    printf 'Fetch exit: %s\n' "$FETCH_RC"
    printf 'Mode: %s\n' "$RUN_MODE"
    printf 'Native benchmark exit: %s\n' "$NATIVE_RC"
    printf 'Restore exit: %s\n' "$RESTORE_RC"
    printf 'Validator exit: %s\n' "$VALIDATOR_RC"
    printf 'Backend after run: %s\n' "$(backend_state)"
    printf '\n===== NATIVE PARITY, BENCHMARK, AND RUNTIME LOG =====\n'
    awk '/^=== SEND THIS REPORT BACK TO CHATGPT ===$/ { skip=1; next }
         /^=== END ===$/ && skip { skip=0; next }
         !skip && !/^report_file[[:space:]]/ { print }' "$TMP_ROOT/native-output.txt"
    if [[ -f "$TMP_ROOT/restore-output.txt" ]]; then
        printf '\n===== LIVE BACKEND RESTORE =====\n'
        cat "$TMP_ROOT/restore-output.txt"
    fi
    printf '\n===== CANONICAL VALIDATOR SUMMARY =====\n'
    cat "$TMP_ROOT/validator.log"
    if [[ -n "$VALIDATOR_FULL_LOG" && -r "$VALIDATOR_FULL_LOG" ]]; then
        printf '\n===== CANONICAL VALIDATOR DETAILED LOG =====\n'
        cat "$VALIDATOR_FULL_LOG"
    else
        printf '\nValidator detailed log unavailable.\n'
    fi
    printf '\n===== SEND THIS FILE =====\n%s\n' "$REPORT"
} > "$REPORT"

printf '\nFull report: %s\n' "$REPORT"
printf 'Send this one text file for analysis.\n'
if ((RESTORE_RC != 0)); then exit 9; fi
if ((NATIVE_RC != 0)); then exit "$NATIVE_RC"; fi
if ((VALIDATOR_RC != 0)); then exit 1; fi
