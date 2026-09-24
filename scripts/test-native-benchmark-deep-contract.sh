#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
wrapper="$repo_root/scripts/benchmark-python-vs-rust.sh"
harness="$repo_root/scripts/native-cutover-benchmark.sh"

fail() {
    printf 'FAIL: native deep benchmark contract: %s\n' "$1" >&2
    exit 1
}

bash -n "$wrapper" || fail "benchmark wrapper has invalid shell syntax"
bash -n "$harness" || fail "native cutover harness has invalid shell syntax"

grep -Fq -- '--deep) DEEP=1' "$wrapper"     || fail "wrapper no longer exposes --deep"
grep -Fq -- 'INIR_BENCH_MPD_SNAPSHOT=1' "$wrapper"     || fail "wrapper no longer enables isolated MPD snapshot mode"
grep -Fq -- 'Deep MPD snapshot:' "$wrapper"     || fail "full report no longer records whether deep mode ran"

grep -Fq -- 'MPD FULL SNAPSHOT DEEP BENCHMARK' "$harness"     || fail "harness no longer contains the full snapshot benchmark"
grep -Fq -- 'keys = ["connected", "musicRoot", "tracks", "playlists", "folders"]' "$harness"     || fail "snapshot parity must stay limited to stable library fields"
grep -Fq -- 'snapshot_parity_cache="$TMP_ROOT/mpd-snapshot-parity-cache"' "$harness"     || fail "snapshot parity must remain isolated from the user cache"
grep -Fq -- 'snapshot_python_cache="$TMP_ROOT/mpd-snapshot-python-cache"' "$harness"     || fail "Python snapshot benchmark must keep its own isolated cache"
grep -Fq -- 'snapshot_rust_cache="$TMP_ROOT/mpd-snapshot-rust-cache"' "$harness"     || fail "Rust snapshot benchmark must keep its own isolated cache"
grep -Fq -- 'XDG_CACHE_HOME="$snapshot_parity_cache"' "$harness"     || fail "snapshot parity command no longer uses the isolated cache"
grep -Fq -- 'XDG_CACHE_HOME="$snapshot_python_cache"' "$harness"     || fail "Python snapshot benchmark no longer uses its isolated cache"
grep -Fq -- 'XDG_CACHE_HOME="$snapshot_rust_cache"' "$harness"     || fail "Rust snapshot benchmark no longer uses its isolated cache"
grep -Fq -- 'MPD_SNAPSHOT_RUNS:-1' "$harness"     || fail "deep snapshot default must remain one run"
grep -Fq -- 'SKIP (use benchmark wrapper --deep)' "$harness"     || fail "full snapshot benchmark must remain opt-in by default"

printf '%s\n' 'PASS: native deep benchmark stays opt-in and cache-isolated'
