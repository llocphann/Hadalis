# Hadalis native backend trial cutover

This directory contains the Rust migration and its reversible runtime trial.

## Runtime policy

Rust is now wired only through `scripts/native-dispatch`.

- `INIR_NATIVE_BACKEND=python` keeps the existing Python implementation active.
- `INIR_NATIVE_BACKEND=rust` selects the Rust implementation and keeps Python
  as a fail-soft fallback unless `INIR_NATIVE_STRICT=1` is set.
- `INIR_NATIVE_BACKEND=auto` prefers available Rust binaries and falls back to
  Python.
- Existing Python helpers remain in the repository during the trial.
- The benchmark harness also writes `$XDG_STATE_HOME/inir/native-backend` and
  `native-bin-dir`. This lets helpers launched by Niri (not just
  `inir.service`) observe the same trial selection. Explicit environment
  variables still take precedence.
- Migration 049 routes already-installed clipboard text watchers through the
  selector; a watcher that was spawned before the migration remains Python
  until the next Niri session, while the direct clipboard A/B test is still
  valid immediately.
- No Rust systemd service is installed or enabled yet.
- Packaging still does not require the Rust binaries.

The trial is intentionally reversible. Run
`scripts/native-cutover-benchmark.sh --restore` to return the user service to the
Python backend.

## Native crates

- `inir-protocol`: versioned native message contracts shared by daemon-style
  crates.
- `inir-inputd`: evdev input aggregation and native input-state reporting.
- `inir-mpdd`: persistent MPD backend plus a compatibility mode matching the
  current `local_music_mpd.py` command contract.
- `inir-native`: clipboard filtering, desktop configuration writers, runtime
  diagnostics sampling, and Niri configuration/query helpers.
- `inir-theme`: Material 2025 color generation, Celebi/Score image seed
  extraction, Hadalis app/terminal palette contracts, compatibility template
  rendering, and the ii-pixel SDDM sync hook.

## Validation and benchmarking

The `Native Rust staging` workflow verifies that runtime/package files do not
bind directly to native binaries, then runs clippy with warnings denied and the
native unit-test workspace.

For machine-level comparison, run:

```bash
./scripts/native-cutover-benchmark.sh
```

The harness builds release binaries, runs Rust tests/clippy, compares Python and
Rust output for read-only/safe paths, measures startup/resident memory and CPU,
then measures the same `inir.service` once with Python selected and once with
Rust selected. It leaves Rust trial mode active so the shell can be tested
interactively.

The report is written under `$XDG_STATE_HOME/inir/` (or
`~/.local/state/inir/`). Send that report back for analysis.

A permanent removal of Python call sites and dependencies is still a separate
maintainer-approved step.
